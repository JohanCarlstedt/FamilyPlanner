//! Family chat over MLS, through the public API: crypto doc §7.2.

use family_crypto::DeviceIdentity;
use family_crypto::mls::{Incoming, MlsPeer, MlsState};

const GROUP: &[u8] = b"family:fam-1";

struct Phone {
    id: String,
    identity: DeviceIdentity,
    mls: MlsState,
}

impl Phone {
    fn new(id: &str) -> Self {
        Phone {
            id: id.into(),
            identity: DeviceIdentity::generate(),
            mls: MlsState::new(),
        }
    }

    fn peer(&self) -> MlsPeer {
        MlsPeer {
            device_id: self.id.clone(),
            signing_key: self.identity.public_keys().signing,
        }
    }

    fn key_package(&mut self) -> Vec<u8> {
        self.mls
            .key_packages(&self.identity, &self.id, 1)
            .unwrap()
            .remove(0)
    }

    fn say(&mut self, text: &str) -> Vec<u8> {
        self.mls
            .encrypt(&self.identity, GROUP, text.as_bytes())
            .unwrap()
    }
}

fn heard(phone: &mut Phone, message: &[u8], trusted: &[MlsPeer]) -> (String, String) {
    match phone.mls.process(GROUP, message, trusted).unwrap() {
        Incoming::Application { sender, content } => (sender, String::from_utf8(content).unwrap()),
        other => panic!("expected a message, got {other:?}"),
    }
}

#[test]
fn a_family_talks_and_a_new_device_joins() {
    let mut anna = Phone::new("anna-phone");
    let mut erik = Phone::new("erik-phone");
    let mut tablet = Phone::new("maja-tablet");
    let everyone = [anna.peer(), erik.peer(), tablet.peer()];

    anna.mls
        .create_group(&anna.identity, &anna.id, GROUP)
        .unwrap();
    let erik_kp = erik.key_package();
    let pending = anna
        .mls
        .add_members(&anna.identity, GROUP, &[erik_kp], &everyone)
        .unwrap();
    assert_eq!(anna.mls.merge_pending(GROUP).unwrap(), 1);
    erik.mls.join(&pending.welcome.unwrap(), &everyone).unwrap();

    let hello = anna.say("Middag 18");
    assert_eq!(
        heard(&mut erik, &hello, &everyone),
        ("anna-phone".into(), "Middag 18".into())
    );

    // Erik adds Maja's tablet; Anna follows the commit.
    let tablet_kp = tablet.key_package();
    let pending = erik
        .mls
        .add_members(&erik.identity, GROUP, &[tablet_kp], &everyone)
        .unwrap();
    erik.mls.merge_pending(GROUP).unwrap();
    assert_eq!(
        anna.mls.process(GROUP, &pending.commit, &everyone).unwrap(),
        Incoming::Commit { epoch: 2 }
    );
    tablet
        .mls
        .join(&pending.welcome.unwrap(), &everyone)
        .unwrap();

    let reply = tablet.say("OK!");
    assert_eq!(heard(&mut anna, &reply, &everyone).1, "OK!");
    assert_eq!(heard(&mut erik, &reply, &everyone).1, "OK!");

    let mut members = anna.mls.members(GROUP).unwrap();
    members.sort();
    assert_eq!(members, ["anna-phone", "erik-phone", "maja-tablet"]);
}

#[test]
fn state_survives_export_and_restore() {
    let mut anna = Phone::new("anna-phone");
    let mut erik = Phone::new("erik-phone");
    let everyone = [anna.peer(), erik.peer()];
    anna.mls
        .create_group(&anna.identity, &anna.id, GROUP)
        .unwrap();
    let pending = anna
        .mls
        .add_members(&anna.identity, GROUP, &[erik.key_package()], &everyone)
        .unwrap();
    anna.mls.merge_pending(GROUP).unwrap();
    erik.mls.join(&pending.welcome.unwrap(), &everyone).unwrap();

    // Erik's phone restarts.
    let saved = erik.mls.export().unwrap();
    assert_eq!(saved, erik.mls.export().unwrap(), "deterministic");
    erik.mls = MlsState::restore(&saved).unwrap();

    let hello = anna.say("still there?");
    assert_eq!(heard(&mut erik, &hello, &everyone).1, "still there?");
    assert!(MlsState::restore(b"not a state").is_err());
}

#[test]
fn a_key_package_from_a_stranger_is_refused() {
    let mut anna = Phone::new("anna-phone");
    let mut mallory = Phone::new("erik-phone"); // claims Erik's id, own key
    let erik = Phone::new("erik-phone");
    let trusted = [anna.peer(), erik.peer()];
    anna.mls
        .create_group(&anna.identity, &anna.id, GROUP)
        .unwrap();

    let forged = mallory.key_package();
    assert!(
        anna.mls
            .add_members(&anna.identity, GROUP, &[forged], &trusted)
            .is_err()
    );
}

#[test]
fn a_welcome_into_a_group_with_a_stranger_is_refused() {
    let mut mallory = Phone::new("mallory");
    let mut erik = Phone::new("erik-phone");
    mallory
        .mls
        .create_group(&mallory.identity, &mallory.id, GROUP)
        .unwrap();
    let kp = erik.key_package();
    let pending = mallory
        .mls
        .add_members(
            &mallory.identity,
            GROUP,
            &[kp],
            &[mallory.peer(), erik.peer()],
        )
        .unwrap();
    // Erik trusts only his own family, which doesn't include mallory.
    assert!(
        erik.mls
            .join(&pending.welcome.unwrap(), &[erik.peer()])
            .is_err()
    );
}

#[test]
fn a_removed_device_reads_nothing_after() {
    let mut anna = Phone::new("anna-phone");
    let mut erik = Phone::new("erik-phone");
    let mut tablet = Phone::new("maja-tablet");
    let everyone = [anna.peer(), erik.peer(), tablet.peer()];
    anna.mls
        .create_group(&anna.identity, &anna.id, GROUP)
        .unwrap();
    let kps = [erik.key_package(), tablet.key_package()];
    let pending = anna
        .mls
        .add_members(&anna.identity, GROUP, &kps, &everyone)
        .unwrap();
    anna.mls.merge_pending(GROUP).unwrap();
    let welcome = pending.welcome.unwrap();
    erik.mls.join(&welcome, &everyone).unwrap();
    tablet.mls.join(&welcome, &everyone).unwrap();

    let removal = anna
        .mls
        .remove_members(&anna.identity, GROUP, &["maja-tablet".into()])
        .unwrap();
    anna.mls.merge_pending(GROUP).unwrap();
    erik.mls.process(GROUP, &removal.commit, &everyone).unwrap();

    let secret = anna.say("present ideas");
    assert_eq!(heard(&mut erik, &secret, &everyone).1, "present ideas");
    // The tablet processes its own removal, then can't read what follows.
    let _ = tablet.mls.process(GROUP, &removal.commit, &everyone);
    assert!(tablet.mls.process(GROUP, &secret, &everyone).is_err());
}

#[test]
fn a_losing_commit_is_discarded_and_the_winner_followed() {
    let mut anna = Phone::new("anna-phone");
    let mut erik = Phone::new("erik-phone");
    let mut tablet = Phone::new("maja-tablet");
    let mut other = Phone::new("maja-phone");
    let everyone = [anna.peer(), erik.peer(), tablet.peer(), other.peer()];
    anna.mls
        .create_group(&anna.identity, &anna.id, GROUP)
        .unwrap();
    let pending = anna
        .mls
        .add_members(&anna.identity, GROUP, &[erik.key_package()], &everyone)
        .unwrap();
    anna.mls.merge_pending(GROUP).unwrap();
    erik.mls.join(&pending.welcome.unwrap(), &everyone).unwrap();

    // Both commit at once; the delivery service takes Erik's.
    let _anna_try = anna
        .mls
        .add_members(&anna.identity, GROUP, &[tablet.key_package()], &everyone)
        .unwrap();
    let erik_wins = erik
        .mls
        .add_members(&erik.identity, GROUP, &[other.key_package()], &everyone)
        .unwrap();
    erik.mls.merge_pending(GROUP).unwrap();

    anna.mls.discard_pending(GROUP).unwrap();
    assert_eq!(
        anna.mls
            .process(GROUP, &erik_wins.commit, &everyone)
            .unwrap(),
        Incoming::Commit { epoch: 2 }
    );
    let hello = erik.say("hej");
    assert_eq!(heard(&mut anna, &hello, &everyone).1, "hej");
}

#[test]
fn a_group_that_lost_the_race_can_be_forgotten_and_rejoined() {
    let mut anna = Phone::new("anna-phone");
    let mut erik = Phone::new("erik-phone");
    let everyone = [anna.peer(), erik.peer()];
    // Both parents start the family thread; Anna's reaches the server first.
    anna.mls
        .create_group(&anna.identity, &anna.id, GROUP)
        .unwrap();
    erik.mls
        .create_group(&erik.identity, &erik.id, GROUP)
        .unwrap();
    erik.mls.forget_group(GROUP).unwrap();
    assert!(!erik.mls.has_group(GROUP));

    let pending = anna
        .mls
        .add_members(&anna.identity, GROUP, &[erik.key_package()], &everyone)
        .unwrap();
    anna.mls.merge_pending(GROUP).unwrap();
    erik.mls.join(&pending.welcome.unwrap(), &everyone).unwrap();
    let hello = anna.say("one thread");
    assert_eq!(heard(&mut erik, &hello, &everyone).1, "one thread");
}
