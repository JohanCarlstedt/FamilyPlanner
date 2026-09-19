# Roadmap

What's next, in rough order. Done work lives in git history and
`.claude/CLAUDE.md`; this is what isn't built yet.

## Integrations, per member (requested 2026-09-19)

Families link outside services to a member, through modules that can fetch
data in and, later, send it out. **Fetching events into the calendar comes
first.**

- **Calendar feeds (iCal) — built.** More > Linked calendars: a parent
  links a laget.se team page, `webcal://` or `https://….ics` to a member,
  optionally with who usually takes them. Parents' phones fetch it every
  three hours (and on Fetch now); events update in place under a stable id
  per feed UID, keep what the family added, and future ones that leave the
  feed are cancelled. The meeting time (laget.se "Samlingstid") moves
  departure and prep earlier. The server never sees the link.
  Feed events that ended over a week ago aren't brought in, and a deleted
  one is purged only after that, so a deletion sticks.
- More modules: school platforms (SchoolSoft, InfoMentor — spec open
  question 15), Google/Apple calendars read-only, and exporting a member's
  calendar out (a read-only share link, spec §8 "Deliberate plaintext").

## Other open items

- iPhone on a real device: plug it in once so the free team can register it.
- iOS push (APNs) needs a paid Apple developer account.
- Chat after total loss: nobody is left in the thread to welcome the
  recovered phone (crypto doc §7.3).
- Seeded first week in onboarding (spec §9 step 3).
- Per-member data export and deletion (spec §9, GDPR).
- Custody across households (spec §3, crypto doc `custody:{child_id}`).
- iOS dev/prod flavours (Xcode schemes).
- v2 per spec §12: shopping lists, meals, actions, homework, wishlists,
  celebrations, DMs and groups, quick capture, weekly review.
