//! Deterministic CBOR (RFC 8949 §4.2.1), the only encoding the envelope writes.
//!
//! ciborium already emits definite lengths and shortest-form integers; the one
//! thing left to us is map key order, which must be the bytewise order of each
//! key's own encoding. Readers accept any well-formed encoding: nothing is ever
//! authenticated over received bytes, only over values re-encoded here.

use ciborium::Value;

/// Encodes [value] deterministically, sorting map keys at every depth.
pub fn encode(value: &Value) -> Vec<u8> {
    let mut out = Vec::new();
    ciborium::into_writer(&canonical(value), &mut out).expect("writing CBOR to a Vec cannot fail");
    out
}

pub fn decode(bytes: &[u8]) -> Result<Value, String> {
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
