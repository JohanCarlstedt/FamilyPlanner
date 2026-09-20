# Roadmap

What's next, in rough order. Done work lives in git history and
`.claude/CLAUDE.md`; this is what isn't built yet.

## Built (2026-09-20)

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
- **Kitchen display:** a wall tablet's own pairing, with the family key
  and no chat keys; the day, tonight's dinner and the shopping list in big
  type, and the screen kept awake.
- **Chat:** the family thread, direct messages and named groups, each an
  MLS group; children's messages supervised up to a tier the family sets,
  with the readers always shown in the thread; encrypted photos.
- **Family map:** latest position only, no trail, shared while the app is
  open; exact, about a kilometre, or place only, cut on the sharer's phone;
  visible pauses; "at school since 08:12"; a parent's floor for supervised
  children; "I'm here" and "Come get me"; Google Maps, everyone at once or
  one person followed.
- **Emoji** in chat, and reactions on a message.
- **Saved passwords:** the family's, or a member's own, each sealed to
  the people it's for; Face ID or the passcode before any reveal.
- **Weather on the week**, for where the phone is, from MET Norway.
- **Home-screen widget** and **share-sheet import** of a recipe or
  calendar link, on Android and iOS (iOS extensions need a paid Apple
  account to run on a real device).

## Next, when decided

- **Location in the background** (spec §7 `always`, geofenced arrival
  notifications): needs the OS's most gated permission and a rationale for
  App Store review.
- **Travel estimates** (spec §3): a routing provider whose licence allows
  caching.
- **External share links** (spec §3, open question 21): expiry by default.

## Next, no decision needed

- ICA through its MCP server when it's available: recipes, and perhaps the
  ICA shopping list, without scraping.
- **Skola24** timetables (the children's school system): no official API
  or feed for guardians, so the phone would call web.skola24.se's
  timetable endpoints itself, as it does laget.se. Needs the school's
  Skola24 host and either the class or the child's "ID för Schemavisare",
  and only works if the school leaves its schedule viewer open without a
  login. Undocumented, so it can break without notice.
- More integration modules: other school platforms (SchoolSoft,
  InfoMentor, spec open question 15), Google/Apple calendars read-only,
  exporting a member's calendar as a feed.
- Routine templates per school term.
- Notifications for "Can I…?" requests and meal polls without the chat.

## Other open items

- A Google Maps key, per platform and gitignored: android/maps.properties
  and ios/Flutter/Maps.xcconfig. Without one the map is a list
  (docs/google-maps.md has the steps and the .example files to copy).
- iPhone on a real device: cable, Trust, Developer Mode
  (docs/ios-devices.md). The app group and push need the paid account.
- iOS push: the app side is done and waits on a Firebase iOS app and an
  APNs key (docs/ios-devices.md).
- iOS dev/prod flavours (Xcode schemes).
