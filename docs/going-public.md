# Going public

Turning a household's app into a product other households pay for. This
is the plan, the parts of it that are decisions rather than work, and an
honest account of what charging money changes.

## Where we actually stand

Better than it looks. The server has been multi-tenant since the first
week — `POST /v1/families` creates one, devices pair into it, and nothing
in the schema assumes there is only one. The app has its own create-a-
family onboarding. Per-family quota is enforced (2 GB of blobs). Rate
limits are live. There is a privacy policy on a real TLS endpoint.

Three things stand in the way, and only one of them is code:

1. **The server's address is compiled into the app** and is currently
   `2.29.40.14.sslip.io` — an IP wearing a hostname. Every build points
   at it forever. This must become a domain you own before a single
   stranger installs anything, because after that you can never move.
2. **Nothing charges anyone.** There is no notion of a subscription
   anywhere in the schema, the API or the app.
3. **Nobody has ever set this up without me in the room.** Every family
   on it is this one, installed by cable.

## The decisions, before any code

### A legal entity, or your own name

An Apple Developer Program account is either **Individual** or
**Organization**. An Individual account lists *your legal name* as the
seller on every App Store listing, receipt and refund. For an app that
holds children's locations, publishing your personal name and being the
named data controller as a private person is worth a moment's thought.

Organization needs a registered company and a D-U-N-S number. It also
matters on the other store: Google's rule that a new **personal**
developer account must run a closed test with 12 testers for 14 days
before production does not apply to organisation accounts. If this is
ever going to production on Play, a company is the short road.

A Swedish enskild firma is cheap and quick and gets you an org number;
an AB is the real answer if this becomes anything. Either way, Apple and
Google act as merchant of record — they collect and remit VAT across every
market — so the tax side of selling into the EU is genuinely handled.
You declare income, not VAT on each sale.

**Decided: a personal name for now.** Two consequences to hold on to.
Your legal name is public on both listings and on every receipt. And
**the two platforms stop being symmetrical**: iOS can reach the public
through the App Store, while Android cannot reach Play *production*
until the 12-tester closed test is served. Until then Android goes out
through closed or open testing, which is a smaller door. If the app
finds an audience, a company is the thing that opens it — and moving an
app between developer accounts afterwards is painful enough that it is
worth deciding before there are customers, not after.

### A name

"Family Planner" cannot be a store listing. It is generic, unregistrable,
and there are a dozen of them already. Before anything is submitted the
app needs a name that is distinct enough to be searched for and, ideally,
checked against PRV and EUIPO. This one blocks the store listing, the
domain, the bundle identifier and the icon wordmark, so it is first.

Bundle identifiers cannot be changed after publication. Getting the name
late means either living with an identifier that does not match, or
starting over.

### What it costs, and what free means

**Decided: free tier, with premium on top.**

| | |
|---|---|
| **One subscription per family**, not per person | Nobody wants to explain to a nine-year-old why they need their own plan. The entitlement lives on the family, so whichever adult buys it covers the household across both platforms. |
| **49 SEK / month, or 399 SEK / year** | About €4.50 and €36. Cozi Gold is ~$39/yr, FamilyWall ~$45 — this sits with them, and the yearly plan pays for two months less than the monthly. |
| **14 days of premium free** | The stores handle the trial. The app is worthless until a family has put a week into it, so a trial shorter than a school week tests nothing. |
| **Self-hosting stays free, all of it** | Anyone running their own server pays nothing. This costs nothing to allow, is the honest position for an end-to-end encrypted app, and roughly nobody will do it. Keep it on the website, not on the paywall screen: the stores treat in-app steering toward not paying as a violation. |

#### The line between them

Sync is not the line. A free tier that cannot sync is a demo, and the
whole point of this app is that two phones agree. So the family's
**shared week works free, on every device, for everyone in the house.**

*Free — the household in one place:*
calendar and recurrence, reminders, Today and the week, shopping lists
and staples, to-dos and chores, "Can I…?", chat, and 200 MB of photos.

*Premium — the work done for you:*

- **Integrations**: school week plans, calendar feeds, the phone's own
  calendars, homework read off a letter or the whiteboard. These are the
  features that save an hour a week, and they are what someone pays for.
- **The family map** and location sharing.
- **Food**: recipes, the weekly menu, dinner polls, dietary conflicts.
- **Saved passwords.**
- **The kitchen display.**
- **Two homes and helpers**: the co-parent's account, custody schedules,
  a babysitter's temporary access.
- **The full 2 GB** of photos, the only thing that actually costs money
  to hold.

Three things are **never** behind the wall, whatever else moves:
**export, erasure, and anything protecting the family** — removing a
device, rotating keys, the recovery kit. Charging for the ability to
leave, or for safety, is not a business model.

**When premium lapses, the family drops to free.** Nothing is deleted,
nothing goes read-only, and the shared week carries on. What stops is
the fetching: school plans and calendar feeds stop refreshing, the map
stops sharing, and photos above the free quota become read-only until
the family removes some or resubscribes. This is the freemium tier's
real advantage over a hard paywall — there is no cliff to be angry at,
and a lapsed family is still a family you can win back.

### Discounts for particular families

Yes, and at three levels — the strongest of which you already own.

1. **A server-side grant.** The entitlement is a row in your own
   database, so you can set any family to premium for any period, free,
   with no store involved and no cut taken. RevenueCat calls this a
   *promotional entitlement* and grants it from the dashboard or its API.
   This is the answer for friends, early families, press, and apologies.
2. **Redeemable codes.** Apple offer codes and Play promo codes — "three
   months free", handed out, redeemed in the store.
3. **Targeted offers.** Apple's promotional offers give a specific
   lapsed subscriber a discounted rate, signed by your server.

**What you cannot do is charge a different price per account.** Both
stores sell at fixed price points per storefront. Free time, trials and
introductory discounts: yes. "This family pays 29": no. Giving premium
away is explicitly allowed; taking money outside the store is not.

### Margin

The store takes 15%, not 30%, on both: Apple's Small Business Program
under $1M/year, and Google's rate for subscriptions. So 49 SEK becomes
about 41 SEK.

Infrastructure is almost free at this shape. Envelopes are small; blobs
are the only thing that grows, they are capped at 2 GB per family, and
Hetzner storage is about €0.04/GB/month. A €8/month box and a volume
carries several hundred families. Push costs nothing on either platform.
Call it under two kronor per family per month at any scale worth having.

**Infrastructure is not the cost. You are.** The cost is support, review
submissions, store policy changes, and the mornings the server is down
while you are at work.

## Billing, and how it meets end-to-end encryption

This part is genuinely interesting, and it works out cleanly: a
subscription is *metadata*, not content. The server already knows which
families exist and when their devices sync. Knowing whether a family has
paid adds nothing it could not already see, so entitlement can live in
plaintext next to `FamilyGroup` without touching the crypto design at
all.

The shape:

- A new `Subscription` row per family: status, product, expiry, the store
  it came from, and the opaque store transaction id.
- The app buys through the store. Apple takes an `appAccountToken`
  (a UUID) on purchase; Google takes an `obfuscatedAccountId`. **Put the
  family id there** — that is the whole link between a purchase and a
  family, and it is the piece people forget until renewals start arriving
  unattributable.
- The stores notify the server directly — App Store Server Notifications
  V2, and Play's real-time developer notifications over Pub/Sub — for
  renewals, cancellations, billing retries, grace periods and refunds.
  A client must never be the source of truth for whether it has paid.
- Devices ask the server, and cache the answer with a grace window, so a
  plane or a dead server does not lock a family out of its own calendar.

**Decided: RevenueCat, rather than by hand.** Hand-rolling means
the App Store Server API, the Play Developer API, two notification
formats, JWS verification, and every edge of grace periods, upgrades,
refunds and restores — several weeks, and the bugs are the kind that
silently cost money. RevenueCat does both stores, is free under roughly
$2.5k monthly revenue, and gives one cross-platform entitlement, which is
exactly the family-not-device model above.

The honest cost: a third party learns that an anonymous id subscribed.
It sees no content, no names, and nothing the app syncs — but it is a
processor, and it goes in the privacy policy and the data safety form.
Given the alternative is a hand-written billing stack maintained by one
person in evenings, I would take the trade.

## Apple

- **Subscriptions must be In-App Purchase.** Non-negotiable for digital
  services consumed in the app. Court rulings in 2025 loosened external
  link-outs in the US storefront and the DMA did so in the EU; both are
  still moving. Do not build on them.
- **Restore purchases** must exist as a visible control.
- **In-app account deletion** is required of any app that creates an
  account (5.1.1(v)). Per-member erasure exists; deleting the *family*
  and its server side needs building.
- **Age rating and the Kids Category.** Do not enter the Kids Category —
  it forbids third-party analytics, demands parental gates on every
  outbound link, and this app is bought and configured by a parent. Rate
  it honestly instead, and expect scrutiny.
- **Children do not have accounts here, and that is the strongest card
  we hold.** A parent creates a child profile and pairs a device; there
  is no child sign-up, no email, no discovery, no stranger contact. Say
  this plainly in the review notes.
- **The two things review will focus on** are location sharing involving
  minors and user-to-user messaging. Both are real, both are closed
  within one invited family, and both need the reviewer to understand
  that before they form an opinion.
- **App Review must be able to use the app.** A reviewer who installs it
  sees an empty create-a-family screen and no way to experience anything.
  This is a classic rejection. Ship a demo path — a seeded family behind
  a review credential, reusing `lib/src/data/sample_family.dart` — and
  document it in App Review notes with screenshots.
- Privacy nutrition labels, a support URL, a marketing URL, and a privacy
  policy URL. All public, all permanent.

## Google

- **Play Billing** for the same reason, same 15%.
- **Production needs the 12-tester/14-day closed test** on a personal
  account. An organisation account is exempt. This is the second reason
  to decide the company question first.
- **Data safety form** — the existing answers in `docs/play-store.md` are
  honest and mostly stand, but they change on going public: purchases
  become a collected category, and RevenueCat becomes a third party the
  data is shared with.
- **Account deletion needs a *web* URL**, not only an in-app control.
  Google requires an externally reachable deletion request page. That is
  a new page next to `/privacy`.
- **Target audience and Families policy.** Declaring an audience that
  includes under-13s pulls in Designed for Families: ad restrictions
  (none here), an approved SDK list, and a stricter content review. Since
  the *purchaser and account holder is always an adult*, the defensible
  declaration is an adult audience with children as supervised users —
  but this is the single answer most likely to cause an argument, and
  worth getting right rather than fast.

## The law, once money changes hands

Taking payment makes this a service and makes you a data controller for
other people's children. What that needs:

- **Terms of service**, which do not exist yet. Apple's standard EULA
  covers the app; the *service* needs its own — what you promise, what
  you do not, what happens to data when someone stops paying.
- **A privacy policy that describes reality**, not the placeholder. Sub-
  processors (Hetzner, the store, RevenueCat, MET Norway, the map tiles),
  retention, the legal basis, and where the data physically is (Helsinki).
- **GDPR subject requests.** Export and erasure already work per member,
  in-app, which is most of the answer and better than most apps manage.
- **Children's data.** GDPR's Article 8 age of consent is 13 in Sweden,
  16 in several other member states. The answer here is that the parent
  consents and the parent controls — which is true — but it must be
  written down, and it constrains which markets to launch in.
- **A support address a human answers**, published. Both stores require
  it and both will test it.

## What end-to-end encryption costs you as a business

This deserves its own section because it is the risk nobody prices in.

**You cannot help anyone.** You cannot reset a password, recover a
family's data, look at their calendar to work out why an event is
missing, or reproduce their bug. A paying customer who loses every device
at once has lost everything, permanently, and it will be your fault in
their telling of it.

What follows from that:

- **The recovery kit must be forced during onboarding**, not offered.
  Today it is a thing you can do. It becomes a thing you cannot skip.
- **Diagnostics have to be client-side** — a "send a report" that the
  user reads first and chooses to send, carrying logs and no content.
- **Crash reporting is now mandatory.** Going public without it is flying
  blind. Sentry with aggressive PII scrubbing, declared on both forms.
- **The refund policy will be exercised**, and the stores grant refunds
  without asking you.

None of this is a reason not to do it. It is a reason to write the
onboarding as if the user will lose their phone tomorrow.

## Order of work

**Phase 0 — decisions.** Three are made: a personal Apple account for
now, a free tier with premium at 49/399 SEK, and RevenueCat. **The name
is the one still open**, and it blocks the domain, the listing and the
bundle identifier — so it blocks phase 1.

**Phase 1 — the foundation.** A real domain and a certificate on it. A
staging server, because "deploy straight to the machine strangers use" is
over. The server address out of the compile line and into configuration,
with a self-hoster's override. Offsite backups. Monitoring that reaches a
phone rather than an inbox — the app already has push and could be its
own alarm.

**Phase 2 — billing.** The `Subscription` entity, the store webhooks
through RevenueCat, the entitlement check with its grace window, the
paywall, restore, and the drop-to-free behaviour above. A gate the
premium features read, in one place, so the line between free and paid
is a list and not a hundred scattered conditions. Test against both
stores' sandboxes, including a renewal, a cancellation, a refund, an
expiry, and a promotional grant.

**Phase 3 — compliance.** Family deletion in-app and the web deletion
page. Terms. The real privacy policy. Data safety and nutrition labels.
The age-rating questionnaires. Crash reporting. The App Review demo path.

**Phase 4 — strangers.** Onboarding that works with nobody helping:
forced recovery kit, empty states that teach, the pairing QR flow tested
by someone who has never seen it. Swedish and English both finished.

**Phase 5 — launch.** TestFlight external and Play closed testing with
real households who are not this one. Sweden first, one language, one
market, and a phased rollout. Then widen. On a personal account that
means **iOS goes public first and Android follows** once twelve testers
have sat through a fortnight — so the closed test is worth starting
early, in parallel with everything else, rather than at the end.

Phases 1 and 2 are the engineering. Phase 3 is tedious and unskippable.
Phase 4 is the one that decides whether anybody stays.

## What I would cut

The roadmap's open items — background location, travel estimates,
Skola24, external share links — all get *harder* under review and none of
them sell a subscription. None should block launch, and background
location in particular is the permission most likely to cost you a
rejection while you are learning how review works.
