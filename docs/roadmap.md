# Roadmap

What's next, in rough order. Done work lives in git history and
`.claude/CLAUDE.md`; this is what isn't built yet.

## Built (2026-09-21)

- **The server is on the internet.** A rented machine in Helsinki, TLS
  from Let's Encrypt, Postgres, a nightly dump, and a deploy script that
  cannot send the server's secrets (docs/hosting.md). The family's data
  moved across with every device keeping its identity; nobody re-paired.
  Rate limits on what one address may ask for, and a health check running
  from GitHub every fifteen minutes.
- **Homework that repeats**: glosor every Friday, a reading log every
  Monday. A template plans one piece a week, each ticked off on its own.
- **The school's week plan**: fetched from its own link (SharePoint
  serves it to a browser user agent), shared out of Word or Teams, pasted,
  or photographed off the whiteboard. Read as the table it is — weekday
  columns, a row per class. Set up once per child under More → School week
  plans, it then fetches itself every six hours like a calendar feed; the
  one-off routes still confirm before saving (docs/calendars.md).
- **Calendars the phone already syncs** — Google, Outlook, iCloud, work —
  per calendar, busy-only or in full, with no OAuth anywhere
  (docs/calendars.md).
- **A child can ask out loud**: the microphone in "Can I…?", for the ones
  who cannot yet type a sentence.
- **A map with no key needed**: OpenStreetMap when no Google key is
  configured, Google's tiles when one is.
- **An icon of its own**, drawn from one source into all twenty-one sizes,
  and store screenshots taken from the real screens with an invented
  family.
- **The week shows trips** it was silently hiding, and can start an event
  on the week you are looking at. **A child can be responsible** for
  something that is only theirs.

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
  children; "I'm here" and "Come get me"; everyone at once or one person
  followed.
- **Emoji** in chat, and reactions on a message.
- **Saved passwords:** the family's, or a member's own, each sealed to
  the people it's for; Face ID or the passcode before any reveal.
- **Weather on the week**, for where the phone is, from MET Norway.
- **Home-screen widget** and **share-sheet import** of a recipe or
  calendar link, on Android and iOS (iOS extensions need a paid Apple
  account to run on a real device).

## Built (2026-09-21, later)

- **The family is on build 10**, every device: Johan's Galaxy and Anna's
  iPhone over wifi, Junie's iPhone and Tuva's iPad by cable, the rest
  through TestFlight. Only Oliver's iPhone is behind, on 8.
- **Swedish survives the homework import.** word/document.xml was read a
  byte at a time, so "Läxa till måndag" arrived as "LÃ¤xa till mÃ¥ndag"
  and the reader matched no weekday and no subject.
- **A recurring chore can be changed**, and stays deleted when deleted.
- **Chat: the key packages stopped draining.** The bug that made a
  message never arrive, and the thread screen that hid messages it
  already had. The chat tab carries an unread count.
- **Billing exists but gates nothing**: subscription, entitlement,
  paywall, RevenueCat (docs/billing.md).
- **An install is pinned to the server it paired with**, so a shipped
  default can never re-home a phone.
- **Two people outside the household** are on TestFlight, and both hit
  the same wall: a fresh install offers "start a family" or "join one",
  and a stranger can do neither alone. That is Phase 4 of going public,
  and it is now evidence rather than a guess.

## Going public

Selling this to other households is planned in `docs/going-public.md`:
a subscription per family, entitlement in plaintext beside the family
row (it is metadata, not content), and the two stores' demands. Three
decisions come before any code — a legal entity or your own name, a name
that is not "Family Planner", and Apple Individual or Organization —
and one blocker: the server's address is compiled in and is still an IP
wearing a hostname.

## Next, when decided

- **Location in the background** (spec §7 `always`, geofenced arrival
  notifications): needs the OS's most gated permission and a rationale for
  App Store review.
- **Travel estimates** (spec §3): a routing provider whose licence allows
  caching.
- **External share links** (spec §3, open question 21): expiry by default.

## Next, no decision needed

- **ICA's shopping list**, if ICA ever publishes an API or an MCP server
  of their own. The unofficial route exists but wants a personnummer and
  password, refuses non-Swedish addresses, and is undocumented
  (docs/ica.md). The list can be *sent* to any shop's app today.
- **Skola24** timetables (the children's school system): no official API
  or feed for guardians, so the phone would call web.skola24.se's
  timetable endpoints itself, as it does laget.se. Needs the school's
  Skola24 host and either the class or the child's "ID för Schemavisare",
  and only works if the school leaves its schedule viewer open without a
  login. Undocumented, so it can break without notice.
- More integration modules: other school platforms (SchoolSoft,
  InfoMentor, spec open question 15), exporting a member's calendar as a
  feed. Google, Outlook and iCloud now come in through the phone's own
  calendars (docs/calendars.md).
- Routine templates per school term.

## Waiting on someone else

- **Google Play**: the account exists, verification has not come through.
  Then internal testing, not production — a personal account needs 12
  testers for 14 days before production, which a household cannot
  honestly produce (docs/play-store.md).
- **A real hostname.** *Decided 2026-09-22: keep the IP for now, fix it
  later.* The server answers on `2.29.40.14.sslip.io`, which embeds its
  address and breaks if it ever moves. Changing `DOMAIN` in the server's
  `.env` and redeploying is the whole job on the server's side.
  Installs are now pinned to the address they paired with, so a new
  default reaches new installs only: every existing phone has to be
  unbound and paired again, or the old address has to keep answering.
  Only a hostname we own avoids that, and it is worth doing before there
  are phones we cannot reach.

  **The deadline for this is the first Google Play upload, not the first
  move of the server.** A Play install updates itself, which is the whole
  reason to be on Play — but the address is compiled into the bundle and
  cannot update with it. Ship to Play on an IP-derived name and that name
  has to keep answering for as long as any phone has the app, or every
  one of them needs a new upload *and* a re-pair. TestFlight has the same
  compiled-in address, but the audience is people we can reach by asking.
  A domain costs a few pounds a year; this is the last cheap moment to
  buy one.
- **The monitoring workflow cannot be pushed** by this credential:
  `gh auth refresh -h github.com -s workflow` first. The file is written
  and sits untracked until then.

## Other open items

- A Google Maps key, per platform and gitignored: android/maps.properties
  and ios/Flutter/Maps.xcconfig. Optional: without one the map draws
  OpenStreetMap's tiles instead (docs/google-maps.md).
- iPhone on a real device: cable, Trust, Developer Mode
  (docs/ios-devices.md). The app group and push need the paid account.
- iOS push: the app side is done and waits on a Firebase iOS app and an
  APNs key (docs/ios-devices.md). Android push works now the server holds
  the Firebase key — though nobody has yet watched a phone buzz to prove
  it end to end.
- iOS dev/prod flavours (Xcode schemes).
- **Getting builds to the children's phones.** Under-13 accounts cannot
  use TestFlight, and Family Link accounts cannot use Play's internal
  testing, so their devices are installed by hand from the Mac and their
  builds expire after a year (docs/ios-devices.md). Worth a reminder
  before that happens, at least.
- **Monitoring reaching a phone.** The health check now runs from GitHub
  every fifteen minutes and emails on failure (docs/hosting.md). Email is
  a weak alarm for something the family depends on; the app already has
  push, and could be the loud one.
- **SSH to the server is unreliable from home.** Measured 2026-09-20 from
  the Mac: port 22 answered 6 of 15 attempts, port 443 answered 15 of 15,
  same minute and same host. Port-specific, so not packet loss — most
  likely an ISP or middlebox interfering with SSH. Moving sshd to another
  port (2222, plus a firewall rule) is the usual fix; deploys work
  meanwhile, but every one of them needs retries.
