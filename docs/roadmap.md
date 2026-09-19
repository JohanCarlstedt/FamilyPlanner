# Roadmap

What's next, in rough order. Done work lives in git history and
`.claude/CLAUDE.md`; this is what isn't built yet.

## Built (2026-09-19)

- **Integrations:** calendar feeds (laget.se, webcal, .ics) linked to a
  member, fetched on parents' phones so the server never sees the link;
  meeting times ("Samlingstid") move departures; a deleted feed event
  stays deleted.
- **Food:** shopping lists by aisle, staples, family recipes imported from
  ICA, Arla and other schema.org sites (checked before they're kept), the
  weekly menu with children's dinner picks, suggestions and approval-vote
  polls, dietary notes that flag recipes and keep strict conflicts out of
  polls, "cook this again", dinner tonight on Today.
- **Actions:** to-dos with a family pool, claiming, delegation that can be
  declined back, parent approval and a visible history; recurring chores
  with turns; prep on events, cancelled with their occurrence.
- **People:** celebrations with gift reminders to the adults; wishlists
  whose claims the owner never sees, carried forward on purpose.
- **Homework** with subjects, free-slot suggestions and sessions as
  calendar events; a strip on a child's Today.
- **Away mode and school breaks** that pause what they cover, reminders
  included; **kit lists** on events; **quick capture** in Swedish and
  English; **search**; **"Can I…?"** requests; the **weekly review**;
  per-member **export and erasure**; **setup** that seeds a usual week.
- **Two homes:** a co-parent's limited account for the children they
  share, custody schedules with changeovers, reminders that know where a
  child sleeps. This family's parents add and remove the co-parent.
- **Chat:** the family thread, direct messages and named groups, each an
  MLS group; children's messages supervised up to a tier the family sets,
  with the readers always shown in the thread; encrypted photos.

## Next, when decided

- **Location** (spec §7, open questions 9–12): map, geofenced arrivals,
  check-in; which provider, and whether any trail is kept.
- **Travel estimates** (spec §3): a routing provider whose licence allows
  caching.
- **External share links** (spec §3, open question 21): expiry by default.

## Next, no decision needed

- ICA through its MCP server when it's available: recipes, and perhaps the
  ICA shopping list, without scraping.
- More integration modules: school platforms (SchoolSoft, InfoMentor, spec
  open question 15), Google/Apple calendars read-only, exporting a
  member's calendar as a feed.
- Home-screen widgets (Glance on Android, WidgetKit on iOS).
- Share-sheet import of a recipe or event link.
- Routine templates per school term.
- Notifications for "Can I…?" requests and meal polls without the chat.

## Other open items

- iPhone on a real device: plug it in, unlock it and tap Trust once, so
  the free team can register it.
- iOS push (APNs) needs a paid Apple developer account.
- iOS dev/prod flavours (Xcode schemes).
