# Roadmap

What's next, in rough order. Done work lives in git history and
`.claude/CLAUDE.md`; this is what isn't built yet.

## Integrations, per member (requested 2026-09-19)

Families link outside services to a member, through modules that can fetch
data in and, later, send it out. **Fetching events into the calendar comes
first.**

- **Calendar feeds (iCal) — building now.** A parent links a feed to a
  member (e.g. a child's team). First target: laget.se, whose team pages
  publish `webcal://cal.laget.se/<team>.ics` — e.g. the page
  https://www.laget.se/LIF2003_F15/Event/Month. Accept the page link, a
  `webcal://` or an `https://….ics` URL. Imported events belong to that
  member, update in place on each fetch (stable id per feed UID), keep
  what the family added (who drives, reminders), and are marked with their
  source. Fetched by a parent's device, so the server never learns which
  team a child is in.
- Use the feed's meeting time ("Samlingstid") for departure reminders.
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
