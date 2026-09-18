//! Deterministic CBOR (RFC 8949 §4.2.1), the only encoding the envelope writes.
//!
//! ciborium already emits definite lengths and shortest-form integers; the one
//! thing left to us is map key order, which must be the bytewise order of each
//! key's own encoding. Readers accept any well-formed encoding: nothing is ever
//! authenticated over received bytes, only over values re-encoded here.

use ciborium::Value;

use crate::envelope::CryptoError;

type Result<T> = std::result::Result<T, CryptoError>;

/// Encodes [value] deterministically, sorting map keys at every depth.
pub fn encode(value: &Value) -> Vec<u8> {
    let mut out = Vec::new();
    ciborium::into_writer(&canonical(value), &mut out).expect("writing CBOR to a Vec cannot fail");
    out
}

pub fn decode(bytes: &[u8]) -> std::result::Result<Value, String> {
    let mut reader = bytes;
    let value: Value = ciborium::from_reader(&mut reader).map_err(|e| e.to_string())?;
    if !reader.is_empty() {
        return Err("trailing bytes after CBOR item".into());
    }
    Ok(value)
}

fn canonical(value: &Value) -> Value {
    match value {
        Value::Array(items) => Value::Array(items.iter().map(canonical).collect()),
        Value::Map(entries) => {
            let mut sorted: Vec<(Vec<u8>, Value, Value)> = entries
                .iter()
                .map(|(k, v)| {
                    let key = canonical(k);
                    let mut encoded = Vec::new();
                    ciborium::into_writer(&key, &mut encoded)
                        .expect("writing CBOR to a Vec cannot fail");
                    (encoded, key, canonical(v))
                })
                .collect();
            sorted.sort_by(|a, b| a.0.cmp(&b.0));
            Value::Map(sorted.into_iter().map(|(_, k, v)| (k, v)).collect())
        }
        other => other.clone(),
    }
}

pub(crate) fn malformed(why: &str) -> CryptoError {
    CryptoError::Malformed(why.into())
}

/// Typed, strict access to a CBOR map with text keys.
pub(crate) struct Fields<'a> {
    what: &'static str,
    entries: &'a [(Value, Value)],
}

impl<'a> Fields<'a> {
    pub(crate) fn of(value: &'a Value, what: &'static str) -> Result<Self> {
        match value {
            Value::Map(entries) => Ok(Fields { what, entries }),
            _ => Err(CryptoError::Malformed(format!("{what} must be a map"))),
        }
    }

    pub(crate) fn get(&self, key: &str) -> Result<&'a Value> {
        let mut found = self
            .entries
            .iter()
            .filter(|(k, _)| k.as_text() == Some(key));
        let (_, value) = found
            .next()
            .ok_or_else(|| CryptoError::Malformed(format!("{} is missing {key}", self.what)))?;
        if found.next().is_some() {
            return Err(CryptoError::Malformed(format!(
                "{} repeats {key}",
                self.what
            )));
        }
        Ok(value)
    }

    /// Rejects keys outside [allowed]. v1 has no extension points; new fields
    /// mean a new version.
    pub(crate) fn only(&self, allowed: &[&str]) -> Result<()> {
        for (k, _) in self.entries {
            match k.as_text() {
                Some(name) if allowed.contains(&name) => {}
                _ => {
                    return Err(CryptoError::Malformed(format!(
                        "{} has an unexpected key",
                        self.what
                    )));
                }
            }
        }
        Ok(())
    }

    pub(crate) fn uint(&self, key: &str) -> Result<u64> {
        match self.get(key)? {
            Value::Integer(i) => u64::try_from(*i)
                .map_err(|_| CryptoError::Malformed(format!("{key} must be unsigned"))),
            _ => Err(CryptoError::Malformed(format!("{key} must be an integer"))),
        }
    }

    pub(crate) fn text(&self, key: &str) -> Result<String> {
        match self.get(key)? {
            Value::Text(s) => Ok(s.clone()),
            _ => Err(CryptoError::Malformed(format!("{key} must be text"))),
        }
    }

    pub(crate) fn bytes(&self, key: &str, len: Option<usize>) -> Result<Vec<u8>> {
        match self.get(key)? {
            Value::Bytes(b) if len.is_none_or(|l| b.len() == l) => Ok(b.clone()),
            Value::Bytes(_) => Err(CryptoError::Malformed(format!(
                "{key} has the wrong length"
            ))),
            _ => Err(CryptoError::Malformed(format!("{key} must be bytes"))),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn map_keys_sort_by_encoded_bytes_so_shorter_keys_come_first() {
        let value = Value::Map(vec![
            (Value::Text("dek".into()), Value::Integer(1.into())),
            (Value::Text("v".into()), Value::Integer(1.into())),
            (Value::Text("ct".into()), Value::Integer(1.into())),
            (Value::Text("n".into()), Value::Integer(1.into())),
        ]);
        let Value::Map(sorted) = canonical(&value) else {
            unreachable!()
        };
        let keys: Vec<_> = sorted.iter().map(|(k, _)| k.as_text().unwrap()).collect();
        assert_eq!(keys, ["n", "v", "ct", "dek"]);
    }

    #[test]
    fn integers_use_the_shortest_form() {
        assert_eq!(encode(&Value::Integer(23.into())), [0x17]);
        assert_eq!(encode(&Value::Integer(24.into())), [0x18, 0x18]);
        assert_eq!(encode(&Value::Integer(256.into())), [0x19, 0x01, 0x00]);
    }

    #[test]
    fn rejects_trailing_bytes() {
        assert!(decode(&[0x01, 0x02]).is_err());
    }
}
