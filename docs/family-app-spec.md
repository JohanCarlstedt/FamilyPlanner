# Family Operations App — Spec & Data Model

Mobile-first (iOS + Android). Single household unit. Two perspectives: parent and child, with age-aware capability inside the child perspective.

---

## 1. Design decisions worth agreeing on first

These shape everything below. Each is a choice, not a law.

**1. Age tiers, not a binary child role.**
With mixed ages, one "child" role fails immediately: a 6-year-old needs pictures and a next-thing-now view, a 16-year-old needs to add their own events and message friends' parents. Role stays `parent | child`, but each child member carries a `maturity_tier` that parents can raise. Permissions resolve from tier, not from birthdate, so a parent can promote an early-mature 11-year-old without lying about their age.

**2. One event table, not three calendars.**
Appointments, weekly activities, birthdays and routine blocks all answer the same question: *what is happening, when, and who is responsible*. Keeping them in one `event` table with a `kind` discriminator means one query powers the week view. Three parallel tables means three sync paths and three bugs.

**3. Every event involving a child has someone responsible.**
The real friction in a family is not "when is football" — it is "who is driving to football." `responsible_member_id` is what answers it, and an event involving a child without one is flagged until it has one. This single field is most of the app's value.

Originally "a responsible *adult*". Relaxed in use: a teen can take a younger sibling (§2 already said so), and a child of any tier can be responsible for an event that is only theirs. Maja walking herself to football is an answer to "who is taking Maja", and the honest one — refusing to record it left the event flagged as nobody's forever, which taught people to ignore the flag. What a young child still cannot be is the answer for a sibling.

**4. Recurrence is stored as a rule, never as generated rows.**
Master event + RFC 5545 RRULE + exception rows. Occurrences are materialized at read time. Generating 500 rows for "every Tuesday" makes editing the series a migration.

Dates that don't exist follow RFC 5545 by default: a monthly rule on the 31st has no instance in a 30-day month, and a yearly rule on 29 February occurs only in leap years. That keeps imported club and school feeds expanding the way every other calendar expands them. Celebrations are the exception — see the note on birthdays in section 3.

**5. Chat is one model with three shapes.**
Family-wide, ad-hoc group, and 1:1 are all `conversation` rows differing only in participant count and a `scope` flag. No separate DM subsystem.

**6. Relationships describe the family; they do not grant access.**
The graph of who is whose grandparent is genuinely useful — for suggesting who to share a wishlist with, labelling celebrations, and building invitation lists. It is not an access-control system. Permissions stay with role, tier and explicit shares, so nobody gains sight of a child's wishlist or schedule because someone added a relationship row.

---

## 2. Roles and permissions

### Member roles

| Role | Meaning |
|---|---|
| `parent` | Full household authority. At least one required. Can be a parent, step-parent, grandparent, au pair. |
| `child` | Capability determined by `maturity_tier`. |

### Maturity tiers (children only)

| Tier | Typical age | Calendar | Chat | Notes |
|---|---|---|---|---|
| `little` | under ~8 | Read-only, today + tomorrow, icon-led | Family thread + 1:1 with parents only | No free-text search, no history scroll past 7 days |
| `kid` | ~8–12 | Read own + family week, can request events | Family + parent DMs + sibling DMs | Requests go to a parent approval queue |
| `teen` | ~13+ | Can create own events, edit own, see full family calendar | All internal threads freely | Can be made responsible for younger siblings' events |

Tier is set per member by a parent and is independent of stored birthdate.

### `helper` — the third role

Parent and child don't cover the grandparent who does Tuesday pickups, the au pair, or Saturday's babysitter. Without a third role you make them a parent, which hands over the entire household.

| Field | Type | Notes |
|---|---|---|
| `member.role` | enum | now `parent \| child \| helper` |
| `helper_scope` | enum | `all_children \| specific` |
| `helper_child_ids` | uuid[] | |
| `access_from` / `access_until` | timestamptz | Time-boxed access, null for open-ended |
| `granted_capabilities` | enum[] | `calendar \| be_responsible \| chat \| actions \| equipment \| care_info` |

A helper sees the calendar for the children they cover, can be the responsible member, can be messaged, and can tick actions and equipment. They never see chat history from before they joined, locations, wishlist claims, homework, care information unless explicitly granted, or family settings.

Time-boxing matters: a babysitter granted access for Saturday evening should lose it on Sunday without anyone remembering to revoke it. Expired helpers stay as rows so their past messages and assignments remain coherent.

### Permission matrix

| Action | Parent | Teen | Kid | Little |
|---|---|---|---|---|
| *(helpers: calendar and be-responsible by default; everything else off unless granted)* | | | | |
| View family week | ✅ | ✅ | ✅ | Today/tomorrow only |
| Create event for self | ✅ | ✅ | Request | ❌ |
| Create event for others | ✅ | ❌ | ❌ | ❌ |
| Edit/delete any event | ✅ | Own only | ❌ | ❌ |
| Approve child requests | ✅ | ❌ | ❌ | ❌ |
| Be responsible adult | ✅ | Optional flag | ❌ | ❌ |
| Create activity (season) | ✅ | ❌ | ❌ | ❌ |
| Edit equipment lists | ✅ | Own activities | ❌ | ❌ |
| Tick equipment items | ✅ | ✅ | ✅ | ✅ |
| Attach an image | ✅ | ✅ | ✅ | To own chat only |
| Delete someone else's image | ✅ | ❌ | ❌ | ❌ |
| Add to own wishlist | ✅ | ✅ | ✅ | With a parent |
| See who claimed an item | Not on own list | Not on own list | Not on own list | ❌ |
| Create an external share link | ✅ | Own list only | ❌ | ❌ |
| Add or edit relationships | ✅ | ❌ | ❌ | ❌ |
| Revoke a share link | ✅ | Own links | ❌ | ❌ |
| Add/edit celebrations | ✅ | ✅ | ❌ | ❌ |
| Create group chat | ✅ | ✅ | ❌ | ❌ |
| DM another member | ✅ | ✅ | ✅ | Parents only |
| Assign an action | ✅ | To self | To self | ❌ |
| Delegate an action | ✅ | ✅ | ❌ | ❌ |
| Claim from the family pool | ✅ | ✅ | ✅ | ❌ |
| Decline a delegation | ✅ | ✅ | ✅ | n/a |
| Add own homework | ✅ | ✅ | ✅ | ❌ |
| Add homework for a child | ✅ | ❌ | ❌ | ❌ |
| See another child's homework | ✅ | ❌ | ❌ | ❌ |
| Schedule own homework sessions | ✅ | ✅ | With a parent | ❌ |
| Plan the week's dinners | ✅ | ❌ | ❌ | ❌ |
| Suggest a meal | ✅ | ✅ | ✅ | By voice/photo |
| Vote in a meal poll | If eligible | If eligible | If eligible | If eligible |
| Create or close a poll | ✅ | ❌ | ❌ | ❌ |
| Set who can vote | ✅ | ❌ | ❌ | ❌ |
| Override a poll result | ✅ (visibly) | ❌ | ❌ | ❌ |
| Use weekly dinner pick | ✅ | ✅ | ✅ | With a parent |
| Add/edit recipes | ✅ | ✅ | ❌ | ❌ |
| Attach a recipe to a meal | ✅ | ✅ | ❌ | ❌ |
| Add items to shopping list | ✅ | ✅ | ✅ | ❌ |
| Generate/merge shopping lists | ✅ | ✅ | ❌ | ❌ |
| Tick items while shopping | ✅ | ✅ | ✅ | ✅ |
| Filter the family calendar | ✅ | ✅ | ✅ | n/a |
| See others on the map | ✅ | Sharers only | Parents only | ❌ |
| Change own sharing settings | ✅ | ✅ (above parent floor) | ❌ | ❌ |
| Set a child's sharing floor | ✅ | ❌ | ❌ | ❌ |
| Pause own sharing (visibly) | ✅ | ✅ | ❌ | ❌ |
| Create places / geofences | ✅ | ❌ | ❌ | ❌ |
| Request a location ping | ✅ | ✅ | ✅ | ❌ |
| Send check-in / SOS | ✅ | ✅ | ✅ | ✅ |
| Set reminders on any event | ✅ | ❌ | ❌ | ❌ |
| Set reminders on own events | ✅ | ✅ | ❌ | ❌ |
| Change own notification rules | ✅ | ✅ | Limited | ❌ |
| Set a child's quiet hours | ✅ | ❌ | ❌ | ❌ |
| Invite new member | ✅ | ❌ | ❌ | ❌ |
| Change another's tier | ✅ | ❌ | ❌ | ❌ |

### The one policy question you must answer

Can a parent read a child's 1:1 messages?

Three defensible answers — pick one and make it visible to the child, because a hidden answer is the one that damages trust:

- **Transparent supervision** — parents can read child DMs; the child sees a persistent "a parent can read this" marker. Reasonable for `little`/`kid`.
- **Private by default, safety-flagged** — parents cannot read, but automated flags (or a child's "tell a parent" button) surface concerns. Common choice for `teen`.
- **Tier-dependent** — supervision below a tier threshold, privacy above it, with the transition explicitly announced to the child.

Model it as a `family_settings.dm_supervision_tier` value so it is configurable rather than hardcoded.

---

## 3. Core domain model

### `family`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `name` | text | "Familjen Andersson" |
| `timezone` | text | IANA, e.g. `Europe/Stockholm` |
| `week_starts_on` | int | 1 = Monday |
| `locale` | text | |
| `created_at` | timestamptz | |

### `member`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | FK |
| `display_name` | text | |
| `role` | enum | `parent \| child` |
| `maturity_tier` | enum | `little \| kid \| teen`, null for parents |
| `birthdate` | date | Drives auto-celebration and age display |
| `color` | text | Per-member calendar colour — critical for glanceability |
| `avatar_url` | text | |
| `can_be_responsible` | bool | Lets a teen be assigned pickup duty |
| `can_vote_on_meals` | bool | Voting eligibility, set per member by a parent |
| `status` | enum | `active \| invited \| suspended` |

### `account` / `device`

Auth identity separated from family membership, because one adult may belong to two households (separated parents) and a young child may have no login at all.

`account`: `id`, `auth_provider`, `email_or_phone`, `created_at`
`member_account`: `member_id`, `account_id` — many-to-many
`device`: `id`, `account_id`, `push_token`, `platform`, `last_seen_at`

A `little` member can exist with zero accounts and appear only on a parent's device or shared tablet.

### `event` — the centre of the app

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | FK |
| `kind` | enum | `appointment \| activity \| celebration \| routine \| action_block \| homework` |
| `title` | text | |
| `description` | text | |
| `place_id` | uuid | FK to `place` — the canonical address |
| `location_note` | text | Room, entrance, pitch number — varies per event at the same place |
| `arrive_before_minutes` | int | Be there 15 min before training starts |
| `equipment_set_id` | uuid | Nullable — what to bring, always optional |
| `starts_at` | timestamptz | For all-day, 00:00 local |
| `ends_at` | timestamptz | |
| `all_day` | bool | |
| `recurrence_rule` | text | RRULE string, null if single |
| `recurrence_until` | date | Season end, e.g. football ends in May |
| `responsible_member_id` | uuid | Who is accountable / driving |
| `created_by_member_id` | uuid | |
| `status` | enum | `confirmed \| tentative \| pending_approval \| cancelled` |
| `visibility` | enum | `family \| participants \| parents_only` |
| `source` | enum | `manual \| imported \| generated` |
| `external_ref` | text | For Google/Apple calendar sync |

`kind` discriminates behaviour without fragmenting storage:

- `appointment` — dentist, parents' evening. One-off or irregular.
- `activity` — recurring commitment with a season: training, piano, scouts.
- `celebration` — birthdays and anniversaries. All-day, yearly RRULE.
- `routine` — the normal week: dinner 18:00, bedtime, homework hour, bin night.
- `action_block` — an action given a slot in the day rather than only a due date.
- `homework` — a scheduled work session for a piece of homework. Note this is the *doing*, not the deadline; see below.

### `event_participant`

| Field | Type | Notes |
|---|---|---|
| `event_id` | uuid | FK |
| `member_id` | uuid | FK |
| `participation` | enum | `attending \| driver \| pickup \| watcher \| declined` |
| `response_at` | timestamptz | |

`watcher` matters: a parent who is not going but wants the reminder. Separating `driver` from `pickup` handles the common case of one parent dropping off and another collecting.

### `place` — addresses as first-class objects

An address belongs to a venue, not to an event. Football trains at the same hall 30 times a season; storing the address on each occurrence means 30 chances to have it slightly wrong and 30 geocoding calls to pay for. One `place` row, referenced everywhere.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `name` | text | "Sportshallen", "Grandma", "Tandläkaren" |
| `address_formatted` | text | Single-line display form |
| `street` / `postal_code` | text | |
| `city` / `country` | text | |
| `geo` | point | Lat/lng |
| `geocode_state` | enum | `unresolved \| resolved \| ambiguous \| manual` |
| `geocode_confidence` | numeric | |
| `provider_ref` | text | Provider place id, for re-resolution |
| `radius_m` | int | Geofence radius, default 150 |
| `icon` / `color` | text | |
| `is_home` | bool | The default origin for departure maths |
| `parking_buffer_minutes` | int | Per-place; the sports hall car park is always full |
| `created_by_member_id` | uuid | |

`parking_buffer_minutes` looks fussy and isn't. Per-venue arrival friction is exactly the knowledge a family accumulates and never writes down, and it is the difference between a reminder that works and one that's five minutes late every week.

**Geocoding rules.** Geocode once, on place creation, not per event. Store `provider_ref` so the record can be refreshed without re-searching. When geocoding is ambiguous or fails, keep `geocode_state = unresolved`, keep the typed text, and let the event work normally with a fixed-lead reminder. Never silently pick the first result — a confidently wrong coordinate produces a confidently wrong departure time, which is worse than no estimate.

Structured fields plus free text together, because Swedish addresses from a club's website arrive as anything from "Idrottsvägen 3, 181 41 Lidingö" to "bakom ishallen".

### `travel_profile`

| Field | Type | Notes |
|---|---|---|
| `member_id` | uuid | PK |
| `default_mode` | enum | `car \| transit \| bike \| walk` |
| `prep_buffer_minutes` | int | Coat, shoes, finding the other shoe |
| `avg_speed_kmh` | numeric | Fallback when no routing data |

The same address produces different leave-by times for a parent driving and a 13-year-old cycling. One profile per member keeps that out of the event.

### `route_estimate` — cached and learned

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `origin_place_id` | uuid | |
| `destination_place_id` | uuid | |
| `mode` | enum | |
| `weekday` / `hour_bucket` | int | Thursday 17:00 traffic differs from Sunday 10:00 |
| `minutes_estimate` | numeric | |
| `source` | enum | `provider \| learned \| manual` |
| `sample_count` | int | |
| `updated_at` | timestamptz | |

**The learned source is the interesting one.** You already capture `place_event` arrivals and departures (section 7). Home-to-hall on a Thursday at 16:50 gets measured every week for a whole season, which beats any routing API's generic estimate for exactly the journeys a family repeats. Seed from a provider, then let observations take over once `sample_count` passes a threshold.

It also caps cost. Routing APIs bill per call; a household makes the same dozen journeys over and over.

### Leave-by computation

```
leave_by = starts_at
         − arrive_before_minutes
         − route_estimate(origin, place, mode, weekday, hour)
         − place.parking_buffer_minutes
         − travel_profile.prep_buffer_minutes
```

`origin` is the responsible member's current position if location sharing is on and recent, otherwise the `is_home` place, otherwise the place of their immediately preceding event. Show which origin was assumed — "leaving from home" — so a wrong assumption is visible rather than mysterious.

Degrade in steps, never to silence: learned estimate → provider estimate → straight-line distance ÷ `avg_speed_kmh` × 1.3 → fixed lead. Label the weaker tiers as approximate in the notification text.

### What addresses make possible at planning time

- **Travel-gap conflicts.** Two events for the same responsible member where `leave_by` for the second falls before the first ends. Detectable the moment both are scheduled, not at 16:45 on the day. This is the strongest argument for structured addresses.
- **Chain feasibility across a season.** Registering a Tuesday activity that collides with an existing pickup should warn during signup, while it's still changeable.
- **Driver suggestion.** When assigning a responsible adult, rank parents by whether they are already going near that place at that time. Note the scope honestly: this is a ranked hint, not route optimisation. Full multi-stop optimisation is a research project and the household only has two or three drivers — a suggestion they can override covers nearly all of the value.
- **Shopping stop-offs.** A `shopping_list.store` pointing at a `place` lets the app note that someone is passing it during a pickup run.
- **`precision: place_only` location sharing** resolves positions against these rows, so every named place improves the map at the same time.

### `event_exception` — recurrence overrides

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `event_id` | uuid | Master series |
| `original_start` | timestamptz | Identifies the occurrence |
| `type` | enum | `cancelled \| moved \| modified` |
| `override_starts_at` | timestamptz | Null unless moved |
| `override_ends_at` | timestamptz | |
| `override_title` | text | |
| `override_responsible_member_id` | uuid | "Dad drives this one week" |

This is what makes "training is cancelled next Thursday" a one-row insert instead of a series rewrite.

### Equipment lists

Optional everywhere. An event with no equipment set is the normal case, nothing prompts for one, and nothing is marked incomplete for lacking one. The moment a kit list becomes something you *must* fill in, people stop creating events in the app and go back to remembering.

The list lives on the **master event**, not the occurrence. It's the same kit every Tuesday for a whole season — entered once, shown thirty times.

### `equipment_set`

`id`, `family_id`, `name`, `icon`, `note`

Reusable and named: "Football kit", "Swimming bag", "Scouts". Two children at the same swimming club share one set, and a fix to it fixes both.

### `equipment_item`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `set_id` | uuid | |
| `name` | text | "Benskydd", "vattenflaska" |
| `photo_url` | text | For members who can't read a list yet |
| `for_member_id` | uuid | Nullable — the child brings boots, the parent brings the folding chair |
| `condition_note` | text | "Only match days", "if raining" |
| `sort_order` | int | |

`for_member_id` is what stops the list being noise. A departure reminder to the driving parent should say what *they* need to bring, not recite the child's kit back at them.

Per-occurrence differences go in `event_exception` as an override note — the away match needing the other shirt is an exception, not a reason to duplicate the set.

### Checking items off — deliberately forgettable

`equipment_check`: `event_id`, `occurrence_start`, `item_id`, `member_id`, `checked_at`

Ticking is available and entirely optional. Two rules about it:

- **State is per-occurrence and expires.** Checks are cleared once the event has passed. There is no history.
- **No scoring, no streaks, no completion rate.** The moment the app can say "Emma forgot her shin guards three times this month", a helpful list has become a compliance record that a parent can produce in an argument. That is a different product, and a worse one.

### Connections worth having

- **Prep reminders carry the list** (section 8) — that's the main payoff, and it means the list does its job even if nobody opens the app.
- **A missing item becomes a shopping item.** "Shin guards are too small" → adds to the shopping list with `source_type: manual` and a note pointing at the event. This is the one moment the family actually notices kit needs replacing, and it's worth catching.

### `person` — everyone the family knows

This replaces the earlier `celebration_subject`. The household's world extends past its members: grandparents, cousins, a child's best friend, a co-parent in another home. Each of them can have a birthday, a relationship, gift notes and a wishlist link, and modelling them only as a name on a birthday row means none of that has anywhere to live.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | The household whose address book this is |
| `member_id` | uuid | Nullable — set when this person is a household member |
| `display_name` | text | |
| `birthdate` | date | Optional |
| `celebration_type` | enum | `birthday \| anniversary \| nameday \| other \| none` |
| `reminder_lead_days` | int[] | e.g. `[14, 3, 0]` — gift-buying lead time |
| `contact_handle` | text | Optional, for sending a wishlist link |
| `notes` | text | Sizes, allergies, gift ideas |
| `primary_attachment_id` | uuid | |

A person with a `member_id` is in the household; one without is outside it. Both participate in relationships, celebrations and wishlist sharing through the same tables, which is the point of unifying them.

Each person with a `birthdate` generates a `celebration` event with a yearly RRULE. Members' birthdays auto-create on member creation.

The generated rule carries `RSCALE=GREGORIAN;SKIP=BACKWARD` (RFC 7529), so a 29 February birthdate falls on 28 February in common years and returns to the 29th in leap years. Strict RFC 5545 would show that child's birthday once every four years, which no family wants. Other rules keep the RFC 5545 default of omitting the missing date.

**Keep non-member records minimal.** These are details about people who never signed up for your app — a name, a date, a relationship, gift notes. Not addresses, not anything you don't need for the one job.

### `relationship`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `from_person_id` | uuid | |
| `to_person_id` | uuid | |
| `type` | enum | `parent_of \| guardian_of \| sibling_of \| partner_of \| grandparent_of \| aunt_uncle_of \| cousin_of \| friend_of \| other` |
| `label` | text | Free text, shown in preference to the enum |
| `is_guardian` | bool | Carries legal weight; see below |
| `since` | date | |

Store the canonical direction once and derive the inverse — `parent_of` implies `child_of`, and symmetric types (`sibling_of`, `cousin_of`, `partner_of`) need only one row. Writing both directions guarantees they drift apart.

**`label` matters more than `type`.** Swedish households routinely include bonusföräldrar and bonussyskon, and a fixed nuclear-family enum will describe a real family wrongly on day one. Let the enum carry the structural meaning the software needs and the label carry what the family actually calls each other — and show the label.

`is_guardian` is the one flag with consequences: it marks the adults who may be responsible for a child, and it is the structure that eventually answers the two-household question in section 12.

### Relationships suggest; they never grant

The tempting move is to derive access from the graph — grandparents can see wishlists, aunts get invited, and so on. Don't.

Permissions in this app come from role, tier and explicit shares. A social graph layered on top produces access nobody deliberately granted, and the failure mode is specific and bad: an ex-partner's new spouse quietly gaining sight of a child's wishlist, party address and schedule because somebody added a relationship row.

So relationships do the useful half:

- **Suggested share recipients.** Creating a wishlist link for a child's birthday offers everyone related to them — one tap each, instead of typing names. The share row is still what grants access, and it is still revocable per person.
- **Context on celebrations.** Grandma's birthday shows as "Farmor" rather than a bare name, with her gift notes and lead times attached.
- **Party invitation lists**, drawn from relationships rather than assembled from memory.
- **Carry-forward between years.** Last year's recipients are re-offered, so Farmor's link is one tap in year two.
- **Reminder targeting**, so gift lead reminders reach the people with a relationship to the celebrant rather than the whole household.

### Wishlists

Not previously in this spec, but implied by celebrations — and the natural home for gift-idea images.

`wishlist`: `id`, `family_id`, `member_id`, `name`, `occasion` (`birthday | christmas | none`), `person_id`, `for_occurrence_start` (date), `carried_from_wishlist_id`, `is_active`

`wishlist_item`: `id`, `wishlist_id`, `title`, `url`, `note`, `size_or_variant`, `priority`, `primary_attachment_id`, `added_by_member_id`, `state` (`open | claimed | received`)

`wishlist_claim`: `item_id`, `claimed_by_member_id`, `claimed_at`, `purchased`, `note`

**The one rule that makes a family wishlist work: claims are visible to everyone except the list's owner.** Without it, two siblings buy the same present, or the birthday child watches their surprises get ticked off in real time. This is a visibility rule in the query layer, not a UI nicety — the owner's fetch must never return claim rows, including through search, notifications, or the change feed.

Wishlists attach to a `person`, so the existing gift lead-time reminders (14 and 3 days out) can surface unclaimed items rather than just the date.

### A recurring celebration, a per-year list

A birthday is already a recurring event: a `person` with a birthdate generates a `celebration` event with a yearly RRULE, so the date recurs on its own and nobody re-enters it.

The wishlist must **not** recur with it. `for_occurrence_start` binds a list to one year's occurrence, because a nine-year-old's list is actively wrong at ten and silently resurfacing it is worse than an empty list. Carrying forward is an explicit action — "copy the unreceived items from last year" — recorded in `carried_from_wishlist_id`, never automatic.

### Sharing outside the app

The people most likely to buy a present are the ones least likely to install a family organiser. Grandparents, godparents, a friend's parent. Requiring an account here means the feature goes unused and people text you instead.

`wishlist_share`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `wishlist_id` | uuid | |
| `token` | text | Long random, unguessable, unique |
| `person_id` | uuid | Who the link was given to — nullable for an ad-hoc recipient |
| `recipient_label` | text | "Farmor", "Sara's mum" — used when no person row exists |
| `scope` | enum | `view \| view_and_claim` |
| `created_by_member_id` | uuid | |
| `expires_at` | timestamptz | Defaults to two weeks after the occasion |
| `revoked_at` | timestamptz | |
| `access_count` / `last_accessed_at` | int / timestamptz | |

**One link per recipient, not one link for everyone.** It costs nothing, and it means you can revoke a single link, see which ones are being used, and attribute claims to a name. A single shared URL forwarded around a family is unrevocable in practice.

### What the external page may show — and what it must not

The link opens a plain web page: no app, no account, no login. That page is effectively public, because links get forwarded. So it shows:

- the celebrant's **first name only**, the occasion, and the items with photos, notes, sizes and links
- a claim button that asks for a name and nothing else

It must not show: the child's full name, their photo, their age or birthdate, the family name, any address, the event's time or place, other family members, or anything from the calendar. Serve it `noindex`, exclude it in `robots.txt`, and never reuse a family-scoped identifier in the URL.

This is worth being strict about. A forwarded link that reveals a child's full name, photo, age and the date and address of their party is a genuine safety problem, and a wishlist is exactly the surface where that leaks by accident.

### External claims

`wishlist_claim` gains `external_share_id` and `external_name`. An outside claimant types "Farmor" and the item shows as taken to everyone in the family — **except the owner**, same as internal claims. The rule holds across every path: internal chat, external page, notifications, export.

### Exports

- **The link is the real export.** It stays current; a claim made an hour later is reflected.
- **PDF or image** for printing or pasting into WhatsApp. Useful, but a snapshot — stamp it with a date and a line pointing back to the live link, because a stale copy is what causes two people to buy the same present, and that happens precisely when items are being claimed.
- **Plain text** for pasting anywhere, same caveat.

### Sharing into the family chat

There's a wrinkle: the celebrant is in the family thread. Posting their wishlist there with claim state visible defeats the purpose.

Use a **celebration planning thread** — a `group` conversation with `linked_event_id` set to the birthday and every family member except the celebrant. The chat model already supports this; it just needs creating automatically when a wishlist is shared internally. Claims, gift discussion and the unclaimed-items reminder all live there, and the celebrant sees nothing.

### Permissions and minors

Sharing a child's wishlist externally is publishing data about a minor, so it is parent-gated: a `teen` can create and edit their own list, but creating an external share link for a `little` or `kid` member is a parent action. Every active share is listed in family settings with its recipient label, access count and a one-tap revoke.


### Homework

**The design point: a due date is not a work session.** Homework due Friday does not get done on Friday — it gets done in a gap on Wednesday. Modelling only the deadline produces a list that a child reads as pressure and cannot act on; modelling only the session loses the deadline. You need both, linked.

This is also why homework is not just an `action`. Actions are things with an owner and a due moment. Homework has a subject, a deadline set by someone outside the family, an effort estimate, and a planning step — enough difference to justify its own table.

### `subject`

`id`, `family_id`, `member_id`, `name`, `color`, `teacher_name`, `school_place_id`

Per child, since siblings are in different years. `color` lets the child's week be readable by subject at a glance.

### `homework`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `member_id` | uuid | Whose homework |
| `subject_id` | uuid | |
| `title` | text | "Maths p. 42–44" |
| `description` | text | |
| `type` | enum | `assignment \| reading \| test \| project \| hand-in` |
| `due_at` | timestamptz | Usually a date; time only when it genuinely has one |
| `assigned_at` | date | |
| `estimated_minutes` | int | Child's or parent's guess — drives scheduling |
| `state` | enum | `not_started \| in_progress \| done \| handed_in` |
| `completed_at` | timestamptz | |
| `created_by_member_id` | uuid | |
| `source` | enum | `child \| parent \| photo \| import` |
| `attachment_url` | text | A photo of the whiteboard is how this actually gets entered |

`source: photo` matters more than it looks. Children do not type homework into apps. A photo of the assignment, with the child setting subject and due date in two taps, is the only entry flow that survives contact with a Tuesday evening.

Overdue is derived (`due_at < now AND state NOT IN (done, handed_in)`), never stored — a stored flag goes stale and produces wrong badges.

### `homework_session`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `homework_id` | uuid | |
| `event_id` | uuid | An event of kind `homework` |
| `planned_minutes` | int | |
| `actual_minutes` | int | Optional |
| `completed` | bool | |

One homework can have several sessions — that is how a project due in three weeks gets broken into pieces instead of becoming a Sunday-night crisis. The link to `event_id` means sessions appear in the calendar, collide-check against activities, and get reminders through the same pipeline as everything else. No parallel scheduling system.

**Scheduling assistance, not automation.** When homework is created, offer free slots before the deadline that avoid existing activities, and let the child pick. Auto-scheduling a child's evening is how the app becomes something done *to* them rather than *for* them, and it gets abandoned.

### What this deliberately does not model

No grades, no marks, no completion scores. Adding them turns a planning tool into a performance record that parents monitor, which changes what the app is and gives the child a reason to stop using it honestly. Due dates and "is it done" is the useful part; the rest belongs between the child and the school.

### `action` — one table for everything that needs doing

This supersedes the earlier `task` entity. The same argument as one event table applies: a chore, a piece of activity preparation, and an errand are the same shape — a thing with an owner, a due moment and a done state. Splitting them produces three lists nobody checks and three notification paths to maintain.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `kind` | enum | `chore \| prep \| errand \| admin` |
| `title` | text | "Wash the kit", "Pay the term fee" |
| `description` | text | |
| `event_id` | uuid | Nullable — the event this prepares for |
| `occurrence_start` | timestamptz | Which occurrence, when the event recurs |
| `assigned_member_id` | uuid | **Nullable — null means the family pool** |
| `scope` | enum | Derived: `family` when unassigned, `member` when assigned |
| `due_at` | timestamptz | Absolute, resolved (see below) |
| `due_offset_minutes` | int | Negative = before the event starts |
| `recurrence_rule` | text | For standalone chores: bins every other Tuesday |
| `is_blocking` | bool | The event can't happen without this |
| `estimated_minutes` | int | |
| `requires_approval` | bool | Parent confirms completion |
| `points` | int | Optional allowance mechanic |
| `state` | enum | `open \| in_progress \| done \| approved \| skipped \| cancelled` |
| `completed_by_member_id` | uuid | Who actually did it, which is not always who it was assigned to |
| `completed_at` | timestamptz | |
| `created_by_member_id` | uuid | |

### Family list or member list — one nullable field

`assigned_member_id` null puts the action in the **family pool**: visible in the `Family` view, claimable by anyone. Set it and the action moves into that member's `Mine` view. That is the whole mechanism — no separate family-tasks and member-tasks tables, and no migration when something moves between them.

Claiming is a single tap that sets `assigned_member_id` to the claimer. Unclaiming returns it to the pool.

### Due dates relative to the event

An action attached to a recurring activity needs a *relative* deadline, not a fixed date. "Wash the kit two days before each match" is one rule; thirty dated tasks is data entry.

```
due_at = occurrence_start + due_offset_minutes     (negative offsets land before)
```

Store `due_at` resolved on each instance so it's directly queryable and sortable, but keep `due_offset_minutes` as the source of truth so moving the event moves the action with it. When an occurrence is cancelled through `event_exception`, its prep actions are cancelled too — the same rule that governs reminders, and forgotten just as easily.

### `action_template` — recurring prep

`id`, `event_id`, `kind`, `title`, `due_offset_minutes`, `default_assigned_member_id`, `is_blocking`, `rotate_among_member_ids[]`

Attached to a master event, instantiated into real `action` rows by the same rolling-window job that materialises notification deliveries. Generate roughly 30 days ahead, never the whole season.

`rotate_among_member_ids` handles the recurring fairness problem directly: kit washing alternates between two parents, snack duty rotates through the team parents. Rotation is deterministic by occurrence index, so everyone can see whose turn is next.

**The overload trap.** A weekly activity with three prep actions generates around 90 rows per season. Generate only inside the window, collapse identical repeating actions in list views ("Wash the kit — weekly"), and let the user disable generation per template. A to-do list that fills itself faster than a family empties it stops being read.

### Delegation

| Field | Type | Notes |
|---|---|---|
| `action_id` | uuid | |
| `delegated_by_member_id` | uuid | |
| `delegated_to_member_id` | uuid | |
| `delegated_at` | timestamptz | |
| `response` | enum | `pending \| accepted \| declined \| renegotiated` |
| `note` | text | |

Assignment and delegation are different acts and the model should say so:

- **A parent assigning** sets `assigned_member_id` directly. It is a decision, not a request.
- **Delegating** asks. The recipient sees it, and can accept or decline with a note. A declined delegation returns the action to the delegator, not to the pool — otherwise it silently becomes nobody's.
- **A teen may delegate to a parent**, and a parent may decline. This is the part most household apps get wrong: delegation that only flows downward is just assignment with softer wording, and children notice.
- **Delegating to a member who can't act** — a `little` member, or one with no device — routes to their responsible adult with the original recipient named ("for Emma").

Every delegation and reassignment is recorded. Not for auditing people, but because "I thought you were doing it" is the single most common failure in a household, and the answer should be visible rather than remembered.

### How actions surface

- **Reminders** run through the existing pipeline: trigger `action_due`, plus an escalation for an unclaimed `is_blocking` action approaching its due time.
- **On the event card**, blocking actions show with their state — the match on Saturday shows the unpaid fee.
- **In the calendar**, an action given a scheduled time becomes an `action_block` event; an action with only a due date stays in the list and out of the timeline. Not everything needs a slot.
- **In `Mine`**, assigned actions; in `Family`, the unclaimed pool plus everyone's blocking items.

### `routine_template`

Lets parents define "our normal week" once and apply it per school term.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `name` | text | "School term 2026", "Summer" |
| `active_from` / `active_to` | date | |
| `is_active` | bool | |

`routine_block`: `id`, `template_id`, `weekday`, `start_time`, `end_time`, `title`, `default_responsible_member_id`, `applies_to_member_ids[]`

Activating a template generates `routine` events. Switching templates at term boundaries is the mechanic that keeps the app usable past week three.

### Custody across two households

Alternating-week custody is ordinary in Sweden, so this is a core case, not an edge one. The model change is small if made now and expensive later: **an event about a child belongs to the child, not only to a household.**

`custody_arrangement`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `child_person_id` | uuid | |
| `household_a_family_id` | uuid | |
| `household_b_family_id` | uuid | Nullable if the other home doesn't use the app |
| `pattern` | enum | `alternating_weeks \| alternating_weekends \| fixed_days \| custom` |
| `changeover_weekday` / `changeover_time` | int / time | Usually Sunday or Friday evening |
| `reference_week` | date | Anchors the alternation |
| `exceptions` | jsonb | Holidays and swaps, same idea as `event_exception` |

A resolver answers "who has this child on this date", and that answer drives the responsible-adult default, reminder routing, meal headcounts and whose `Mine` view the child's events appear in.

**Changeover is itself an event.** It has a time, a place and a driver, and it is the most commonly botched logistics moment in a separated family. Generate it from the arrangement.

**Sharing boundary.** The two households see the child's schedule and the actions attached to it. They do not see each other's private calendars, chats, meals, locations, wishlist claims or members. A `shared_child_scope` on the event decides what crosses: the training session crosses, the dinner plan does not.

Where the other household doesn't use the app, degrade to a read-only shared calendar link rather than requiring adoption.

### `absence` — away mode

Without this, every training reminder and routine block fires through the summer holiday.

`id`, `family_id`, `member_ids[]` (empty = whole family), `starts_on`, `ends_on`, `title`, `suppress_kinds[]` (`activity | routine | action | homework`), `suppress_reminders` (bool)

An absence suspends matching occurrences and their reminders for the range without touching the underlying series. Meal planning drops the absent headcount, shopping generation scales down with it, and the calendar shows the range as a band rather than deleting anything.

### `care_info` — allergies, medication, emergency contacts

The thing a babysitter or a helping grandparent needs, and the thing a family app is the obvious place to look for.

`id`, `person_id`, `type` (`allergy | medication | condition_note | doctor | dentist | insurance | emergency_contact | blood_type`), `value`, `severity`, `instructions`, `updated_at`, `updated_by_member_id`

Treat this as the most sensitive data in the product:

- Visible to parents by default. Visible to a helper only when `care_info` is in their `granted_capabilities`, and only for the children they cover.
- Never in notifications, never in search results, never in exports that leave the household.
- This is health data about minors under GDPR. Carry it deliberately — written retention, written access rules, and a clear answer to what happens to it when a child leaves the family.

Keep it short and operational. A severe allergy and what to do about it is worth having; a medical history is not, and inviting one into the app creates an obligation you don't want.

### External participants

Activities constantly involve people outside the household — samåkning to a match, a snack rota, another parent driving four children to a tournament.

`event_external_participant`: `event_id`, `person_id`, `role` (`driver | attending | contact`), `note`

Plus a **read-only event share link**, the same token mechanism as wishlist shares: expiring, revocable, showing the event and the rota and nothing else about the family. That covers most of the coordination need. Full inter-family federation is a different product; don't start there.

### `family_settings`

Referenced throughout and never defined. One row per family: `dm_supervision_tier`, default quiet hours, `prep_buffer_minutes`, measurement units, week start, locale, `storage_quota_bytes`, `location_trail_retention_hours`, `share_link_default_expiry_days`.

### Attachments — one table, not a column per entity

Images are wanted on events, actions, homework, wishlist items, messages, recipes, places and equipment. Adding an `image_url` to each of those produces eight upload paths, eight authorization checks and eight places to forget EXIF stripping. One polymorphic table instead.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | Scopes every access check |
| `owner_type` | enum | `event \| action \| homework \| wishlist_item \| message \| recipe \| meal_plan_entry \| place \| equipment_item \| member` |
| `owner_id` | uuid | |
| `uploaded_by_member_id` | uuid | |
| `kind` | enum | `image \| document \| voice` |
| `storage_key` | text | Object storage path, never a public URL |
| `mime` / `bytes` | text / int | |
| `width` / `height` | int | Reserve layout space before load |
| `placeholder` | text | Blurhash or thumbhash |
| `caption` | text | |
| `client_id` | uuid | Device-generated, makes retries idempotent |
| `state` | enum | `uploading \| ready \| failed \| quarantined` |
| `created_at` | timestamptz | |

Entities that have exactly one canonical image — a member avatar, a recipe hero shot, an equipment item photo — keep a `primary_attachment_id` pointing into this table rather than their own URL column. The existing `avatar_url`, `image_url` and `photo_url` fields above should be read as shorthand for that.

### Access control is inherited, never copied

An attachment's visibility is the visibility of the thing it hangs off, **computed at fetch time**. A photo on a parents-only event is parents-only; move the event's visibility and the photo follows automatically.

Serve through short-lived signed URLs, scoped to a member who currently passes the owner's check. Never public buckets, never permanent URLs. A guessable or forever-valid link to a family's photos is the failure mode that matters here, and it is the one people ship by accident.

### Strip EXIF on ingest

Phone photos carry GPS coordinates, device identifiers and timestamps. A picture of a child outside their school embeds the school's location, and that data then travels with every copy.

Strip location and device metadata by default on upload, server-side, before the original is stored. Keep orientation so images aren't sideways. Given that half the photos in this app will be of children, this is not an optional hardening step.

### Upload pipeline

- **Downscale on the device before upload.** A modern phone photo is several megabytes; a family on mobile data will not wait, and will stop attaching pictures.
- Generate two or three renditions server-side — thumbnail, list, full — and serve by context.
- Queue uploads offline and render optimistically from the local file, with `client_id` making the retry idempotent. Same pattern as chat messages.
- Virus/content scan lands the row in `quarantined` rather than deleting it silently.

### Quota and retention

Images are the one thing in this app that grows without bound. Set a per-family storage cap, show it, and offer bulk cleanup of attachments on events older than a chosen age. Celebration and wishlist images should be exempt from any automatic expiry — those are the ones people come back for years later.

### `approval_request`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `requested_by_member_id` | uuid | |
| `subject_type` | enum | `event \| action \| chat_invite \| setting` |
| `subject_id` | uuid | |
| `state` | enum | `pending \| approved \| rejected` |
| `decided_by_member_id` | uuid | |
| `decided_at` | timestamptz | |
| `message` | text | |

---

## 4. Dinner planning and shopping

### The decision that makes this work: canonical ingredients

A shopping list assembled from three dinners must turn "2 gul lök", "1 onion" and "150 g lök" into one line. That is only possible if recipe ingredients point at a shared catalogue row rather than storing free text. Free-text ingredients are faster to build and permanently unmergeable.

Two-tier catalogue: a global seed list of common ingredients, plus family-local additions. Match on name and synonyms at entry time, fall back to free text with a "link this" prompt rather than blocking the user.

### `ingredient`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | Null for global catalogue rows |
| `name` | text | Canonical display name |
| `synonyms` | text[] | "lök", "gul lök", "yellow onion" |
| `category` | enum | Aisle: `produce \| dairy \| meat \| frozen \| pantry \| bakery \| household \| other` |
| `base_unit` | enum | `g \| ml \| piece` — the unit everything converts into |
| `unit_conversions` | jsonb | e.g. `{"piece": 110}` for grams per onion |
| `default_display_unit` | text | What the user sees on the list |

`category` drives aisle grouping in the store, which is the difference between a list that gets used and one that doesn't.

### `recipe`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `title` | text | |
| `source_url` | text | Imported or linked from a site |
| `ingredient_parse_state` | enum | `structured \| partial \| unparsed` — honesty about import quality |
| `base_servings` | int | Scaling reference |
| `prep_minutes` / `cook_minutes` | int | Enables "what fits before training at 17:30" |
| `instructions` | text | |
| `image_url` | text | |
| `tags` | text[] | `vegetarian`, `quick`, `kid-favourite`, `freezer` |
| `created_by_member_id` | uuid | |
| `last_cooked_at` | timestamptz | Powers "not this again" rotation |

### `recipe_ingredient`

`id`, `recipe_id`, `ingredient_id`, `quantity`, `unit`, `note` ("finely chopped"), `is_optional`, `sort_order`

### `meal_plan_entry`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `date` | date | |
| `slot` | enum | `breakfast \| lunch \| dinner \| snack` |
| `recipe_id` | — | **Removed.** Recipes attach via `meal_plan_recipe` below |
| `freeform_title` | text | "Leftovers", "Pizza out" — used when no recipe |
| `servings` | int | Scales the recipe on generation |
| `cook_member_id` | uuid | Who is cooking, mirrors `responsible_member_id` on events |
| `chosen_by_member_id` | uuid | Whose pick it was — see below |
| `status` | enum | `planned \| cooked \| skipped \| takeaway` |
| `event_id` | uuid | Optional link to the dinner `routine` event |

`event_id` is the join between the two halves of the app: the 18:00 dinner block on the week view shows tonight's meal and who is cooking, without a separate calendar.

`cook_member_id` deserves the same weight as `responsible_member_id` on events. "What's for dinner" is a smaller argument than "who is making it."

**Child dinner picks.** Give each child a `chosen_by_member_id` slot per week. It costs one nullable FK and removes a recurring negotiation from the household — a `kid` who cannot otherwise create anything gets one real decision.

### `meal_plan_recipe` — recipes attached to a meal

A dinner is rarely one recipe. Chicken plus a salad plus a sauce is three, and forcing them into one record means either cramming everything into a single "Tacos" recipe or losing the side dish from the shopping list. A many-to-many join fixes both.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `meal_plan_entry_id` | uuid | FK |
| `recipe_id` | uuid | FK |
| `role` | enum | `main \| side \| salad \| sauce \| dessert \| drink \| bread` |
| `servings_override` | int | Null inherits the entry's `servings` |
| `sort_order` | int | |
| `added_by_member_id` | uuid | |

`servings_override` handles the ordinary case where you make the main for five but double the sauce to freeze half.

`role` earns its place in two ways: the cook view can order the card as main-then-sides, and "we need a side for Thursday" becomes a query rather than a memory.

**Every attached recipe feeds shopping list generation.** The `meal_plan_entry` source type expands through this join, scales each recipe by its own servings, and writes one provenance row per recipe. Remove the salad from Thursday and only the salad's ingredients come off the list.

### Attaching a recipe

Five entry points, all writing the same join row:

- **From the family's recipe library** — search or filter by tag, the common case once the library has some depth.
- **From a link.** Paste or share a URL into the app. Most recipe sites publish schema.org `Recipe` JSON-LD, which gives title, servings, ingredients and times as structured data. Parse that where present.
- **From a poll result** — closing a meal poll attaches the winning option's recipe automatically.
- **From a previous meal** — "cook this again" copies the attachments from an earlier entry, which is how a real household plans.
- **From a photo** of a cookbook page, transcribed by the user.

**Be honest about link import.** Where JSON-LD is absent, scraping page HTML is fragile and breaks silently whenever a site redesigns. Rather than storing a bad parse, keep `source_url` plus whatever ingredients the user confirms, and mark `ingredient_parse_state` as `unparsed`. A recipe with a working link and three hand-entered ingredients is useful; one with mangled quantities silently corrupts every shopping list it touches.

Also worth deciding early: store the link and the family's own notes rather than copying a site's instruction text into your database. Recipe instructions are the site's copyrighted writing, and a library full of copied text is a problem you'd rather not inherit at scale. Ingredient lists are closer to factual data and less exposed, but the safe pattern is link out for the method.

### Importing from Swedish recipe sites

**Don't start by writing scrapers.** Three tiers, in order, each falling through to the next:

1. **schema.org `Recipe` JSON-LD.** Most commercial Swedish food sites publish it for Google's recipe rich results — they want the SEO. One parser, zero per-site code, and it keeps working through redesigns because the site has its own reason to maintain it.
2. **The `recipe-scrapers` library.** It supports over 740 recipe websites out of the box, with a `wild_mode` option for sites that follow common patterns. Several Swedish domains are already in its supported list: ica.se, koket.se, arla.se, recept.se, alltommat.se, tasteline.com, festligare.se, kiddokitchen.se, drinkoteket.se and hellofresh.se. That covers a large share of where Swedish households actually get recipes, for the cost of a dependency.
3. **Manual or photo entry**, with the URL stored. Always available, never blocked.

Notably absent from that list at time of writing: coop.se, godare.se, zeta.nu, mathem.se, receptfavoriter.se. Check each for JSON-LD before assuming a custom adapter is needed — and if you do write one, contributing it upstream means the library's maintainers keep it alive rather than you.

Before building against any of them, check whether the grocery chains offer an official recipe or partner API. ICA and Coop both tie recipes to their own ordering flows and may prefer a sanctioned integration to being scraped.

### `recipe_import`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` / `requested_by_member_id` | uuid | |
| `url` | text | |
| `domain` | text | For per-domain health monitoring |
| `parser` | enum | `jsonld \| site_adapter \| wild \| manual` |
| `state` | enum | `queued \| parsed \| needs_review \| failed` |
| `confidence` | numeric | |
| `raw_payload` | jsonb | What the parser returned, before mapping |
| `error` | text | |
| `created_recipe_id` | uuid | Null until the user confirms |

**Import always lands in review, never straight into the library.** The user sees parsed title, servings, times and ingredients, fixes what's wrong, then saves. A silent import that quietly got quantities wrong poisons every shopping list generated from it, and nobody traces the bug back to a website they visited three weeks ago.

`domain` plus `state` gives you parser health per site. Sites redesign; a domain whose success rate falls off a cliff should alert you rather than degrade quietly.

### Swedish units are the real work

This is the part that will actually take time, and it has nothing to do with scraping.

Swedish recipes are volumetric where Anglo recipes are not, and the unit set in section 4 doesn't cover them:

| Unit | Means | Metric |
|---|---|---|
| `dl` | deciliter | 100 ml |
| `msk` | matsked | 15 ml |
| `tsk` | tesked | 5 ml |
| `krm` | kryddmått | 1 ml |
| `st` | stycken | count |
| `nypa` | pinch | ~0.5 ml |
| `klyfta` | clove/wedge | count |
| `förp` / `pkt` / `burk` | package, packet, tin | count, size varies |

Add these to the ingredient unit enum as display units. `dl`, `msk`, `tsk` and `krm` convert cleanly to ml and need no per-ingredient data.

The harder case is **volume-to-weight for dry goods**. "2 dl vetemjöl" is roughly 120 g, but the ratio differs per ingredient — flour, sugar, oats and rice are all different. This is exactly what `ingredient.unit_conversions` was for: store grams-per-dl per ingredient, seeded for the common ones. Where no conversion exists, keep the volumetric unit on the shopping list rather than inventing a weight. "2 dl grädde" on a list is perfectly shoppable; "197 g grädde" is a fabrication.

`förp`, `pkt` and `burk` should never be normalised at all. A package is whatever the shop sells, and guessing its size is worse than leaving it as the recipe wrote it.

### Swedish ingredient matching

The canonical `ingredient.synonyms` array does the work, seeded in Swedish: "gul lök / lök / yellow onion", "vispgrädde / grädde", "crème fraiche / creme fraiche", "smör / bregott". Imports match against synonyms, and anything unmatched lands as free text with a "link this to an ingredient" prompt rather than blocking the import.

Recipe sites also state portions as "4 portioner" — map to `base_servings` during parse.

### Fetching: politely, and only when asked

- **User-initiated, single URL, via the share sheet.** Never crawl a site, never pre-fetch a catalogue. One recipe, because a person asked for that recipe.
- Respect `robots.txt`, identify your user agent honestly, rate limit per domain, cache aggressively so the same recipe is fetched once for the whole family.
- Server-side fetching is easier to maintain and cache; on-device fetching keeps your infrastructure off the hook and is what several recipe apps do. Pick deliberately.
- The copyright point from above applies with more force here: store the link, the structured ingredients, and the family's own notes. Copying instruction text from ICA or Köket into your database at scale is a different legal proposition than one household saving a recipe, and worth an actual opinion from a lawyer if this becomes a product rather than a family tool. `recipe-scrapers` publishes its own copyright and usage notice — read it before shipping.

### Recipe edits after a list exists



`shopping_list_item_source.quantity_contributed` is captured at generation time, so editing a recipe afterwards does not silently change a list someone is already shopping from. Surface it instead: "this recipe changed since the list was made" with a re-sync action the user chooses to run.

### `meal_suggestion` — the open pool



Anyone can propose a meal at any time, independently of a poll. Suggestions accumulate into a pool that polls are then built from.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `suggested_by_member_id` | uuid | |
| `recipe_id` | uuid | Nullable |
| `freeform_title` | text | "Tacos", "the chicken thing grandma makes" |
| `target_date` | date | Optional — "sometime" is a valid suggestion |
| `target_slot` | enum | `lunch \| dinner` etc., nullable |
| `note` | text | |
| `voice_url` | text | For pre-literate members |
| `state` | enum | `open \| in_poll \| scheduled \| declined \| expired` |
| `expires_at` | timestamptz | Default 60 days |

Suggestions expire on purpose. An un-expiring pool becomes a graveyard of things nobody wants, and then nobody opens it.

Decline is explicit and carries no reason field. An ignored suggestion teaches a child the feature is decorative; a declined one at least closes the loop.

### `meal_poll`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `title` | text | "Thursday dinner", "Next week" |
| `target_date` | date | Which meal this decides |
| `target_slot` | enum | |
| `method` | enum | `approval \| single_choice \| ranked` |
| `state` | enum | `draft \| open \| closed \| cancelled` |
| `opens_at` / `closes_at` | timestamptz | |
| `eligible_member_ids` | uuid[] | Snapshot at open time from `can_vote_on_meals` |
| `hide_results_until_close` | bool | Default true |
| `is_binding` | bool | Whether the winner auto-schedules |
| `created_by_member_id` | uuid | |
| `result_meal_plan_entry_id` | uuid | Set on close |

Snapshotting `eligible_member_ids` at open time matters: changing who can vote mid-poll invalidates the result and looks like rigging to a nine-year-old, who will notice.

### `meal_poll_option`

`id`, `poll_id`, `recipe_id`, `freeform_title`, `source_suggestion_id`, `added_by_member_id`, `image_url`, `sort_order`

Options carry an image where one exists. For a `little` member, tapping a photo is the entire voting interface.

### `meal_vote`

`id`, `poll_id`, `option_id`, `member_id`, `rank`, `cast_at`

Unique on `(poll_id, option_id, member_id)`. For `approval` a member has many rows; for `single_choice`, one.

### Use approval voting, not first-past-the-post

This is the recommendation I'd argue hardest for. With single-choice voting in a household of five, the winner routinely takes two votes out of five — a meal that most of the family didn't pick. Worse, two siblings who always vote together become a permanent bloc and the outcome stops varying.

**Approval voting** — tick every option you'd be happy to eat — finds the meal with the fewest objections, which is what a family dinner actually optimises for. It is also easier to explain to a child than ranking, and the tally is a simple count.

Keep `single_choice` available for "pick your birthday dinner", where one person's preference should dominate.

### Rules that keep it from causing fights

- **Dietary exclusions beat votes.** An option conflicting with a `strict` entry in `member_dietary_note` cannot win, and should not appear as an option at all. Surface why it was excluded rather than filtering silently.
- **Hide the tally until close.** Visible running results make later voters copy earlier ones and let an older sibling lean on a younger one. Show who *has* voted, not what they voted.
- **Deterministic tie-break**, published in advance: the option whose proposer has won least recently. Explainable and visibly fair beats random, because children audit fairness far more rigorously than adults expect.
- **Parent override is visible, not silent.** A parent can overrule the result, and the override shows in the poll with the outcome. If you expect to override often, don't ship voting at all — a vote that gets quietly reversed is worse than no vote, because it teaches children the participation is theatrical.
- **`is_binding` should usually be true.** The whole value is that the decision is genuinely delegated.

### How it fits what already exists

- **Polls render in the family chat.** `message.type = poll` is already in the message model (section 6), so a poll is a message with a `payload` pointing at the `meal_poll`. No separate inbox, no new surface to check — votes get cast where the family already talks.
- **The weekly child pick still stands.** `chosen_by_member_id` on `meal_plan_entry` guarantees each child one night that is theirs outright. Voting covers the shared nights. Both matter: one is guaranteed agency, the other is negotiated agency, and a child who never wins a vote still gets their night.
- **Closing a poll writes a `meal_plan_entry`**, which flows into the shopping list generation in the normal way. No special-casing downstream.

### `member_dietary_note`



`id`, `member_id`, `type` (`allergy | intolerance | dislike | diet`), `value` (ingredient_id or free text), `severity` (`avoid | strict`), `note`

Strict entries flag recipes at planning time and never silently filter them out — a parent needs to see *why* a suggestion was excluded.

---

### `shopping_list`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `name` | text | "Week 38", "ICA Maxi" |
| `state` | enum | `template \| draft \| active \| completed \| archived` |
| `store` | text | Optional; enables per-store aisle ordering |
| `planned_for_date` | date | |
| `created_by_member_id` | uuid | |

`template` state covers staples — the milk-bread-coffee list that seeds every new list.

### `shopping_list_item`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `list_id` | uuid | |
| `ingredient_id` | uuid | Nullable for free-text items |
| `free_text` | text | "birthday candles" |
| `quantity` | numeric | Summed across sources |
| `unit` | text | Display unit after conversion |
| `category` | enum | Denormalized from ingredient for offline aisle sorting |
| `state` | enum | `needed \| in_cart \| bought \| unavailable` |
| `checked_by_member_id` | uuid | Who grabbed it — matters when two people shop together |
| `checked_at` | timestamptz | |
| `note` | text | |
| `manual_quantity_override` | numeric | Set when a human edits a generated amount |

### `shopping_list_item_source` — the important table

| Field | Type | Notes |
|---|---|---|
| `item_id` | uuid | FK |
| `source_type` | enum | `meal_plan_entry \| recipe \| other_list \| staple_template \| manual` |
| `source_id` | uuid | Polymorphic reference |
| `quantity_contributed` | numeric | In the ingredient's base unit |
| `added_at` | timestamptz | |

This provenance row is what makes the feature you asked for actually behave. Without it, a generated list is a one-way flattening: drop Thursday's curry and you have no idea whether the coconut milk should go, because Tuesday might need it too. With it, removing a source subtracts only that source's contribution, and the item disappears only when its last contributor does.

It also tells the shopper *why* four peppers are on the list, which is the question people ask in the aisle.

### Generation: one mechanism, several entry points

A shopping list is composed from N sources. "From one or more meal plans", "from one or more recipes", and "merge these two lists" are the same operation with different `source_type` values.

```
generate_list(target_list, sources[], options)

sources[]  — any mix of meal_plan_entry ids, recipe ids, list ids, staple template ids
options    — merge_duplicates, scale_to_servings, subtract_pantry,
             include_staples, keep_manual_items
```

Steps:

1. Expand each source into ingredient lines. A `meal_plan_entry` expands through `meal_plan_recipe` into every attached recipe, each scaled by its own `servings_override` or the entry's `servings`, divided by `base_servings`.
2. Convert each line to the ingredient's `base_unit`.
3. Group by `ingredient_id`, sum, and write one `shopping_list_item` plus one `shopping_list_item_source` row per contributor.
4. Convert back to a friendly display unit (1500 g → 1.5 kg).
5. Items with no `ingredient_id` never merge — free text stays as separate lines.

**Where merging must refuse.** Two onions and 300 g onion are not addable without inventing a conversion the user didn't supply. When `unit_conversions` lacks a mapping, keep both lines and group them visually under one heading rather than guessing. A shopping list that quietly halves a quantity is worse than one with two onion lines.

**Regeneration.** Meal plans change after the list exists. Re-running generation must be incremental: recompute source contributions, leave manual items and `manual_quantity_override` alone, and never resurrect an item already marked `bought`.

### `pantry_item` (optional, later)

`ingredient_id`, `quantity`, `unit`, `expires_on` — enables `subtract_pantry`. Genuinely useful and genuinely high-maintenance; families abandon inventory tracking fast. Treat as v3 and make it optional forever.

### Shopping in the store

- Group by `category`, ordered per `store` if known.
- Item state changes need near-realtime sync — two parents splitting a list is a normal case, and duplicate purchases are the failure everyone remembers.
- Must work fully offline. Supermarkets have no signal. Queue state changes, reconcile on exit.
- Large tap targets, `bought` items collapse to a dimmed footer rather than vanishing, so an accidental tap is recoverable.

---

## 5. Calendar views and filtering

### The occurrence projection

Every view reads one materialized read model, computed from master events + RRULE + exceptions:

```
occurrence {
  event_id, original_start, starts_at, ends_at, all_day,
  title, kind, status,
  responsible_member_id,
  participant_member_ids[],
  member_colors[],
  location, is_exception, source_meal_plan_entry_id
}
```

Views never touch recurrence logic. One expansion function, unit-tested once, feeding day, week, month and agenda. Recurrence bugs reproduced in four rendering paths is the most predictable way to lose a month.

### Filtering

`calendar_view_preference`

| Field | Type | Notes |
|---|---|---|
| `member_id` | uuid | Whose preference |
| `device_id` | uuid | Filters are per-device, not synced |
| `default_scope` | enum | `mine \| family` — children default to `mine`, parents to `family` |
| `visible_member_ids` | uuid[] | Empty = everyone |
| `visible_kinds` | enum[] | Lets routine blocks be hidden to declutter |
| `include_responsible_for` | bool | See below |
| `show_declined` | bool | |
| `default_view` | enum | `day \| week \| month \| agenda` |

Behaviour that matters:

- **Filter chips across the top**, one per member, avatar + colour, multi-select. Tap to toggle, long-press for "only this person". Default is everyone.
- **Filters are per-device and sticky.** A parent who habitually looks at one child should reopen to that state. Syncing filters across devices means two parents fighting over one view.
- **`include_responsible_for` is the subtle one.** Filtering to Mum should optionally also show events where Mum is the driver but not a participant — otherwise filtering to yourself hides exactly the commitments you need to see. Default it on.
- **Filter at the data layer, not the render layer.** Conflict badges, counts and the unassigned-responsibility warning must reflect the active filter, or the summary contradicts the list.

### Scope: "mine" before "family"

Scope is a segmented control at the top of the calendar — `Mine` / `Family` — sitting above the member filter chips. It is not the same thing as filtering, and burying it in the chips would be a mistake: a child should never have to deselect four siblings to see their own week.

**Children open on `Mine`. Parents open on `Family`.** That is the correct default for each, because the questions differ. A child asks "what do I have today"; a parent asks "what does this household have today, and who is covering it".

`Mine` resolves to:

- events where the member is in `event_participant`, in any role
- `routine` blocks whose `applies_to_member_ids` includes them — so dinner and bedtime still appear
- their own `homework` sessions, plus a due-date strip above the day
- their own actions, assigned or claimed
- for a teen with `can_be_responsible`, events where they are the responsible member

`Family` is the full household view described above, read-only for children.

Two things that make this work rather than merely exist:

- **`Mine` must not become an empty calendar.** A seven-year-old with two activities a week will open to blank days unless routine blocks and family-wide events are included. Blank is the same as broken.
- **Cross-scope awareness.** When something in the family view directly affects the child — dinner moved, the trip on Saturday — it belongs in `Mine` too. The child shouldn't have to check a second view to find out their evening changed.

For the `little` tier there is no toggle at all. One screen, their own things, and no family view to get lost in.

### Member encoding — colour is not enough



Colour is the primary cue, but colour alone fails for roughly 8% of men and in bright sunlight on a phone. Every occurrence carries a second, redundant encoding: the member's avatar or initials on the block itself. For multi-member events, a stacked avatar cluster.

Pick the default palette for distinguishability under deuteranopia, not for prettiness, and let parents override per member.

### Views on a 380px screen

A true 7-column week grid is unreadable on a phone. The realistic set:

- **Agenda week (default).** Scrolling list grouped by day, each row showing time, title, member avatars, responsible adult. This is the view that actually gets used.
- **Week strip.** Seven compact day columns showing density dots per member, pinned above the agenda as a navigator rather than as the main reading surface.
- **Day.** Hour timeline with member lanes — concurrent events for different people tile side by side by member rather than shrinking into slivers.
- **Month.** Colour dots only, for orientation and jumping.
- **Full grid.** Landscape and tablet only. Don't force it into portrait.

### Swedish calendar realities

These aren't localisation polish; they're how the year is actually organised here.

- **Week numbers, everywhere.** Schools, clubs and workplaces communicate in veckor. A week view without its number, and a month view without a number column, reads as a foreign product. This is a small change with outsized credibility.
- **`school_term`** — `id`, `family_id`, `name`, `starts_on`, `ends_on`, `kommun`, and a child list of `school_break` rows (`sportlov`, `påsklov`, `höstlov`, `jullov`, `studiedag`). These vary by kommun and drive the entire year's logistics. Let a parent enter them once a year, or import where a kommun publishes them. Breaks should auto-suggest an `absence` and pause routine blocks.
- **Röda dagar** seeded, including the moveable ones, and the fact that Swedish life reorganises itself in July.
- **Namnsdagar** ship seeded, since `nameday` is already a celebration type.
- Monday week start, 24-hour time, ISO dates, metric units, and Swedish plus English from day one — including in notification copy and imported recipe units.

### Making "all activities clearly visible" true

Density is the enemy. A household of five with activities, routine blocks and meals produces enough rows to become wallpaper. Countermeasures:

- **Routine blocks render as background bands**, not as event cards. Dinner at 18:00 every day should be a tint behind the timeline, not five identical cards competing with the dentist appointment.
- **Conflict detection.** Two events sharing a `responsible_member_id` at overlapping times get a conflict badge, surfaced at the top of the day. This is the single highest-value thing the calendar can do, and it's cheap once the occurrence projection exists.
- **Unassigned-responsibility strip.** Any upcoming event involving a child with no responsible adult is listed above the calendar until resolved.
- **Travel gaps.** If two events for the same responsible adult are in different `place`s with insufficient time between, flag it.
- **Today marker and "next up"** pinned, so opening the app answers the immediate question without scrolling.

---

## 6. Chat model

### `conversation`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `family_id` | uuid | |
| `scope` | enum | `family \| group \| direct` |
| `title` | text | Null for `direct`; derived from participants |
| `created_by_member_id` | uuid | |
| `is_supervised` | bool | Computed from settings + participant tiers |
| `linked_event_id` | uuid | Optional — a thread attached to an event |

Exactly one `family` conversation per household, created automatically, cannot be left or deleted. Direct conversations are uniquely keyed on the sorted participant pair to avoid duplicates.

`linked_event_id` is a small feature with outsized value: the "who's bringing the cake" conversation lives on the birthday, not scrolled away in the family thread.

### `conversation_participant`

`conversation_id`, `member_id`, `joined_at`, `last_read_message_id`, `muted_until`, `notification_level` (`all | mentions | none`)

### `message`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `conversation_id` | uuid | |
| `sender_member_id` | uuid | |
| `body` | text | |
| `type` | enum | `text \| image \| voice \| event_share \| action_share \| poll \| system` |
| `payload` | jsonb | Structured content for non-text types |
| `reply_to_message_id` | uuid | |
| `sent_at` | timestamptz | |
| `edited_at` | timestamptz | |
| `deleted_at` | timestamptz | Soft delete |

`voice` matters for pre-literate `little` members — it is their only real input method.
`event_share` lets a message carry a tappable event card, closing the loop between the two halves of the app.

`message_reaction`: `message_id`, `member_id`, `emoji`

### Familiar messaging behaviour

The reference point is the chat app everyone in the household already knows, so the affordances should be the ones their hands expect. Worth building:

- **Emoji as plain Unicode in the message body.** No custom sticker system, no proprietary shortcode table. A picker with search and a recently-used row, skin-tone variants, and emoji-only messages rendered large — that last one is a two-line rule and it's the detail people notice missing.
- **Reactions**, already modelled above: long-press a message, tap an emoji, tallied under the message.
- **Reply with quote** — `reply_to_message_id` exists; render the quoted snippet above the reply and scroll to the original on tap.
- **Light formatting**: `*bold*`, `_italic_`, `~strike~`, backticks for monospace. The same syntax people already type by habit.
- **Mentions** — `message_mention`: `message_id`, `member_id`. Drives the `notification_level: mentions` setting so a muted thread still reaches you when you're named.
- **Voice notes**, already in `message.type`. For a member who can't type, this is the whole chat.
- **Search** across a conversation, and a media gallery per thread.
- **Edit and delete.** Edit within a window (`edited_at` set, marked in the UI); delete-for-everyone leaves a tombstone rather than a silent gap, because a vanished message in a family thread generates more suspicion than a "message deleted" marker.

Worth skipping: forwarding between threads (there are only a few threads), status/stories, disappearing messages, calls. The full surface of a commercial messenger is enormous and almost none of it earns its place in a household of five.

### Links

`link_preview`

| Field | Type | Notes |
|---|---|---|
| `url_hash` | text | PK — dedupes across messages |
| `url` | text | |
| `title` / `description` | text | |
| `image_url` | text | |
| `site_name` | text | |
| `state` | enum | `pending \| ok \| failed \| blocked` |
| `fetched_at` | timestamptz | Cache; refetch after a long TTL |

- **Autolink on send**, detecting URLs in the body rather than requiring markup.
- **Unfurl server-side, not on the device.** Client-side fetching leaks a family member's IP address to whatever site was linked, including a child's. Server-side also means one fetch per URL for the whole family and a cache that survives.
- **Internal links render as cards, not URLs.** A link to an event, recipe, shopping list or poll becomes the same rich card as `event_share` — same renderer, different entry point. This is what makes "here's Thursday's dinner" a tappable thing rather than a UUID.
- Failed or blocked previews degrade to a plain tappable link. Never block sending on an unfurl.

### End-to-end encryption

Chat is end-to-end encrypted. That decision resolves several open questions and creates a handful of concrete obligations; both are below.

### Supervision becomes key membership, not server access

The apparent conflict — parents can read a young child's DMs, yet nobody but the participants can — dissolves once supervision is expressed as **who is in the conversation's key group** rather than as server-side reading.

A supervised conversation encrypts to the child's device keys *and* a supervising parent's device keys. The parent is cryptographically a participant. Your servers are not, in any case.

This is strictly better than the server-side version on the terms section 2 already set:

- **Transparency is structural.** The recipient list is the key list. A child can see exactly who can read the thread, because there is no other way for anyone to read it. "No invisible watching" stops being a promise and becomes a property.
- **Supervision cannot be retroactive.** Enabling it rotates the group key, so a parent sees messages from that moment forward and not the history. Under server-side storage, switching supervision on would hand over everything ever sent.
- **Revocation is real.** When a teen crosses the tier threshold and supervision ends, the key rotates and the parent's devices lose access to everything after. Not a flag that could be flipped back.

`conversation.is_supervised` now means "a parent device key is in this group", rendered as a persistent marker in the thread.

### Protocol

Use **MLS (RFC 9420)** rather than rolling anything. This app has many small groups with frequent membership change — helpers joining for a weekend, a planning thread excluding the celebrant, supervision starting and stopping, a teen's new phone — and MLS is built for exactly that, with efficient group key rotation. Signal's protocol with sender keys is the proven alternative but handles churn less gracefully.

Requirements either way:

- **Per-device identity keys**, not per-member. A member with three devices has three keys.
- **Forward secrecy and post-compromise security** through regular key rotation.
- **Backward secrecy on join**: a new member — a helper, a supervising parent, a replacement device — reads nothing from before they joined. Rotate on every membership change.
- **Safety numbers** viewable per conversation, so a suspicious change is inspectable.

### What this forces you to build differently

- **Push notifications carry no message text.** Send a data-only push, decrypt on device, and construct the notification locally — a notification service extension on iOS, a data message on Android. Getting this wrong is how E2E apps leak plaintext to the push provider.
- **Search is local, per device.** Each device indexes what it can decrypt. There is no cross-device server search, and a new phone starts with an empty index until history is restored.
- **Link previews need an unfurl proxy.** The device asks your server to fetch a URL and return the metadata. The server learns the URL but not the conversation, the sender, or the recipients — and the family's IP stays off the target site. That metadata leak is real; state it in the privacy copy rather than implying otherwise.
- **Attachments are encrypted client-side** with a per-attachment key carried in the message. Object storage holds ciphertext, so the signed-URL rules from section 3 still apply but the content is opaque to you.
- **The kitchen display gets no chat keys.** A shared wall tablet holding family message keys is a device anyone in the house — or visiting it — can read everything from. Give that surface calendar, meals and shopping only.
- **A child with no device holds no keys**, which is already how reminders work: their messages route to the responsible adult.

### Device loss is now the hard problem

Without recovery, a lost phone means lost history. This is where E2E products actually hurt users, so decide it deliberately:

- **Encrypted backup** keyed by a recovery code, stored in the user's own cloud. Standard, and most people lose the code.
- **Parent-device re-provisioning**: a new device is admitted to the family's groups by an existing parent device confirming it. Practical for a household, and it means the common case — a teenager's new phone — needs no code at all.

Ship both. Re-provisioning is the path people will use; the recovery code covers the household that loses every device at once.

### Be precise about what is encrypted

Chat is end-to-end encrypted. The calendar, actions, meals, wishlists, places and locations are not — they are server-side, because conflict detection, reminder scheduling, shopping list generation and the map all require the server to read them.

Say exactly that in the product. "Encrypted" stated broadly, when only messaging is, is the kind of claim that is technically defensible and still misleading. The honest line is that messages are private to their participants and the rest of the household data is protected in transit and at rest.

One genuine benefit worth noting: E2E materially reduces your GDPR exposure on the most sensitive content in the app, including messages involving minors.

### Delivery mechanics

Add to `message`: `client_id` (uuid generated on the device, idempotent retries), `client_sent_at`, and `status` (`sending | sent | delivered | read | failed`).

Order by server timestamp, not client clock — a phone with a wrong clock otherwise reorders the thread for everyone. Read state comes from `conversation_participant.last_read_message_id`, which already gives per-thread unread counts and read ticks without a row per recipient per message.

Typing indicators are ephemeral presence over the realtime channel, never stored.

**Store text as UTF-8 end to end** and count lengths in grapheme clusters. Emoji are multi-codepoint, and a naive character truncation splits a family emoji or a flag into fragments. On MySQL this specifically means `utf8mb4`; the legacy `utf8` collation cannot store emoji at all.


---

## 7. Location and the family map

This is the highest-trust, highest-liability feature in the app. It is also the one families ask for first. Build it, but build it transparently — a family map that feels like surveillance gets one child turning it off permanently, and then nobody's map is complete.

### Governing principle: no invisible watching

Anyone who appears on the map can see who can see them. Granting a new viewer notifies the person being viewed. There is no mode in which a member is tracked without knowing it. This is a product decision, not just a legal one: covert tracking of a 15-year-old is discovered eventually, and what it costs is the teenager's participation in the whole app — including the calendar and chat that actually make the household run.

### `location_share_setting`

| Field | Type | Notes |
|---|---|---|
| `member_id` | uuid | PK |
| `mode` | enum | `off \| while_using \| always \| scheduled` |
| `schedule` | jsonb | Windows for `scheduled`, e.g. school run hours only |
| `visible_to` | enum | `parents \| family \| selected` |
| `visible_to_member_ids` | uuid[] | For `selected` |
| `precision` | enum | `exact \| approximate \| place_only` |
| `minimum_mode` | enum | Floor a parent may set for a child |
| `paused_until` | timestamptz | Visible pause — see below |

`precision: place_only` is the setting that makes this workable for teenagers. Parents see "at school" or "at the sports hall"; they do not see a dot on a specific street. It answers the question a parent actually has — is the child where they should be — without the part that feels like being followed.

**Visible pause, not silent off.** A teen can pause sharing, and the pause shows on the map as "paused" with a timestamp. The alternative is worse for everyone: a covert off switch means parents trust a map that is quietly wrong, and teens learn to route around the app rather than use it.

### `member_location`

`member_id`, `lat`, `lng`, `accuracy_m`, `captured_at`, `battery_pct`, `is_moving`, `device_id`

Latest position only, one row per member, overwritten. `battery_pct` earns its place — "phone died" is the answer to most "why can't I see them" panics, and showing it prevents a lot of unnecessary alarm.

### `location_trail` (short retention)

`member_id`, `lat`, `lng`, `captured_at` — rolling 24–48 hours, hard-deleted beyond.

Keep this short deliberately. A long location history of a child is a serious liability with little day-to-day family value; the questions people actually ask are "where are they now" and "did they get there", both of which are answered without a permanent record.

### `place` — geofences

Defined in section 3 as the canonical address entity. The map layer adds only the geofencing use: `radius_m` defines the arrival boundary, and `precision: place_only` resolves a position to the nearest containing place instead of exposing coordinates.

Home, school, training hall, grandma's. Naming places converts raw coordinates into meaning — and because events already reference places for departure reminders, the map gets populated as a side effect of normal calendar use rather than needing separate setup.

### `place_event`

`id`, `member_id`, `place_id`, `type` (`arrived | left`), `at`, `confidence`

**Prefer these to live coordinates for younger children.** "Arrived at school 08:12" answers the real question, generates a useful notification, and leaks far less than a continuously updating dot. For a `little` or `kid` member, arrival events alone may be the entire feature.

### `location_request`

`id`, `requester_member_id`, `target_member_id`, `requested_at`, `state` (`pending | shared | declined`), `responded_at`

A ping the target sees and answers. For teens with sharing off, this is the middle ground between full-time tracking and nothing.

### Practical constraints

- **Battery.** Use significant-location-change and geofence APIs, not continuous high-accuracy GPS polling. Continuous GPS drains a phone in hours and the feature gets uninstalled before it gets evaluated.
- **OS permissions.** Background/"Always" location is the most heavily gated permission on both platforms and needs an in-app rationale plus App Store review justification. Assume a meaningful share of users grant "While Using" only, and degrade to last-known-position with a clear timestamp rather than showing nothing.
- **Accuracy honesty.** Always show `captured_at` next to a position. A 40-minute-old dot presented as current is how the map becomes actively misleading.
- **Retention and GDPR.** Location data on minors is sensitive personal data under GDPR, and you are in Sweden, so this is not theoretical. Document purpose limitation, minimise what you keep, make retention short by default, and build export and delete before launch rather than after. I'm not a lawyer — with minors plus location plus an EU launch, this is worth an actual legal review rather than a best-effort guess.
- **Separated households.** If a child belongs to two families, decide explicitly whether both households see the same map. This is the sharpest edge of open question 1.

### Worth more than tracking

A prominent **check-in / SOS** button — "I'm here", "come get me" — sends position and a message to parents on demand. For most families this covers the genuine safety need better than continuous tracking, and it puts the child in control of the disclosure.

---

## 8. Notifications and pre-activity reminders

The calendar's whole value is realised here. Nobody opens a family app to browse; they open it because it told them something. Equally, over-notifying is the single most common way this category of app gets muted and then uninstalled, so every default below is deliberately conservative.

### The two reminders that matter are different

For any activity there are two distinct moments, and collapsing them into one notification is the usual mistake:

- **Prep reminder** — the night before or hours ahead. "Football tomorrow 17:30, pack the kit bag." Actionable while you can still do something.
- **Departure reminder** — "leave in 10 minutes." Time-critical, aimed at whoever is driving.

They go to different people, at different leads, and need separate rows.

**Equipment appears in both, filtered per recipient.** The prep reminder lists what the recipient personally needs to bring — items whose `for_member_id` is them or is null. The departure reminder gets a short form only, because a push notification that runs past three lines gets collapsed by the OS and read by nobody: name the first two or three items and let the tap open the full list. Items with a `condition_note` show the condition alongside them rather than being silently included or excluded.

An event with no equipment set produces exactly the reminder it produces today. Nothing changes.

### `notification_rule` (member defaults, per event kind)

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `member_id` | uuid | |
| `applies_to_kind` | enum | `activity \| appointment \| celebration \| routine \| action_block \| any` |
| `applies_to_role` | enum | `participant \| responsible \| watcher \| any` |
| `trigger` | enum | `prep \| departure \| event_start \| day_before \| celebration_lead \| action_due \| new_message \| approval_pending \| unassigned_escalation \| event_changed \| event_cancelled \| participant_changed` |
| `lead_minutes` | int | |
| `absolute_time` | time | For day-before rules: 20:00, not "1440 minutes" |
| `travel_aware` | bool | Departure rules only |
| `channel` | enum | `push \| in_app \| digest` |
| `enabled` | bool | |

Splitting on `applies_to_role` is what implements the rule that follows. The driver and the eight-year-old should not get the same message.

### `event_reminder` (per-event override)

`id`, `event_id`, `minutes_before`, `target` (`participants | responsible | specific | all_family`), `target_member_ids[]`, `travel_aware`, `message`

Set on the master event, inherited by every occurrence; overridable per occurrence through `event_exception`. "Remind everyone an hour before the recital" is a one-off, not a settings change.

### `notification_delivery` (the scheduled queue)

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `member_id` | uuid | Recipient |
| `event_id` | uuid | |
| `occurrence_start` | timestamptz | Which occurrence this is for |
| `rule_id` / `reminder_id` | uuid | Origin |
| `scheduled_for` | timestamptz | Computed send time |
| `state` | enum | `scheduled \| sent \| suppressed \| cancelled \| failed` |
| `dedupe_key` | text | Unique index |
| `sent_at` | timestamptz | |

`dedupe_key = hash(member_id, event_id, occurrence_start, trigger, lead_minutes)` with a unique index. Recurring events plus member defaults plus per-event overrides will otherwise double-fire, and a duplicate reminder reads as a bug to the user even when the data is correct.

### Scheduling mechanics — the real implementation risk

Occurrences are computed, not stored, so reminders need a materialisation job:

1. A rolling window job expands occurrences for the next ~30 days.
2. For each occurrence it resolves applicable rules and overrides into `notification_delivery` rows.
3. Any change to the event, its RRULE, its exceptions, its participants, or a member's rules **re-runs the window for that event** and cancels superseded rows.

The case that must not fail: training is cancelled on Thursday, an `event_exception` of type `cancelled` is written, and the 16:45 "leave now" push must not go out. Cancelling deliveries on exception write is easy to forget and immediately destroys trust in every other notification the app sends.

Schedule in the family timezone and recompute across DST boundaries — 17:30 training stays 17:30, which means the UTC instant moves.

### Travel-aware departure reminders

When the event has a `place_id`, the departure reminder fires at the `leave_by` computed in section 3 — route estimate plus parking buffer plus prep buffer, subtracted from the arrival time rather than the start time.

Origin resolution in order: the responsible member's current position if sharing is on and the fix is recent, then the place of their immediately preceding event, then home.

This must degrade gracefully. Location off, no signal, unresolved geocode — fall back down the estimate tiers and say so in the message ("leave around 16:45") rather than implying a precision you don't have. A confidently wrong departure time is worse than a rough one, because people stop checking the ones that are right.

### Default rules worth shipping with

| Event kind | Recipient | Trigger | Default |
|---|---|---|---|
| `activity` | responsible | departure | travel-aware, 10 min buffer |
| `activity` | responsible | prep | day before, 20:00 |
| `activity` | participant (`kid`/`teen`) | prep | 60 min before |
| `appointment` | responsible + participants | day_before | 18:00 |
| `appointment` | responsible | departure | travel-aware |
| `celebration` | parents | celebration_lead | from `reminder_lead_days` |
| `routine` | — | — | **off** |
| `action_block` | assignee | action_due | 2h before |
| blocking action unclaimed | all parents | escalation | 48h before the event |
| meal poll opened | eligible voters | — | once, on open |
| meal poll closing | voters who haven't voted | — | 2h before close |
| meal poll result | family | — | into the family chat, no push |
| `homework` | the child | prep | evening before the due date |
| `homework` | the child | departure | at the scheduled session |
| `homework` (test/project) | the child | prep | 5 days out, once |
| homework overdue | parents | escalation | digest only, not a push |
| any unassigned | all parents | unassigned_escalation | 24h before start |
| event cancelled | participants + responsible | event_cancelled | immediately, always |
| event moved | participants + responsible | event_changed | immediately if within 7 days |
| responsible changed | old and new responsible | event_changed | immediately |
| participant added/removed | that member + responsible | participant_changed | immediately |
| minor edit | — | — | **no notification** |

**Routine blocks default to silent.** Dinner at 18:00 every single day does not need a push. Turning routine notifications on by default is, on its own, enough to get the app muted in week one.

The escalation row is the counterpart to the unassigned-responsibility strip in section 5: an event involving a child that still has no responsible adult 24 hours out pings every parent. That is the notification most worth sending and the one most family apps don't.

**Homework reminders go to the child, not the parent.** A parent push for every assignment turns the app into an automated nag and makes the child's own reminders feel like surveillance rather than help. Overdue items reach parents through the morning digest, which is enough to notice a pattern without generating a confrontation over each item.

### Change notifications

When a plan changes, the people it binds need to hear about it. This is the notification with the highest value in the whole app and the easiest one to turn into spam, so the work is deciding what counts as a change.

### `event_change`

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `event_id` | uuid | |
| `occurrence_start` | timestamptz | Null for series-wide changes |
| `scope` | enum | `instance \| future \| series` |
| `changed_by_member_id` | uuid | |
| `changed_at` | timestamptz | |
| `field` | text | |
| `old_value` / `new_value` | text | |
| `significance` | enum | `material \| minor \| silent` |

Worth keeping beyond the notification itself. "Who moved it, and when" is a question families actually ask, and the honest answer beats four people reconstructing it from memory.

### What is material

| Change | Significance |
|---|---|
| Start or end time | material |
| Date, or moved to another day | material |
| Cancelled | material, highest priority |
| Place | material |
| Responsible member | material — to both the old and the new one |
| Participants added or removed | material, to the affected member |
| A blocking action added | material to the assignee |
| Title | minor |
| Description, notes, equipment list, colour | minor |
| Recomputed travel estimate, shifted leave-by | **silent, always** |

That last row matters. A route estimate refreshing, an arrival time recalculating, a rolling window regenerating an action — these are the system recomputing, not a person changing the plan. Notifying on derived recomputation would produce constant noise about things nobody did, and it's an easy bug to ship because the change-detection layer can't tell the difference without being told.

### Coalesce edits, or you ship a notification storm

Editing an event is rarely one field. Someone moves training, changes the hall, and reassigns the driver in a single sitting — that must arrive as **one** notification, not three.

Batch by `(event_id, occurrence_start, recipient)` over a short window — five to ten minutes — and send once the editor stops. The message names the fields rather than the values: "Training Thursday: time and place changed." Details on tap.

The same window handles the undo case: someone moves an event and moves it back, which nets to no change and should send nothing.

### Who hears about it

- **Participants and the responsible member**, always.
- **Watchers** get it in the digest, not as a push. That's what the watcher role is for.
- **Never the person who made the edit.** Obvious, routinely shipped wrong.
- **On a participant change**, the added or removed member gets a message written for their situation — "you've been added to Saturday" reads very differently from the generic "the event changed".
- **A child with no device** routes to their responsible adult, as with every other reminder.

### State the recurrence scope explicitly

A change to a repeating activity must say which occurrences it touched: this one, this and all future, or the whole series. "Training moved to 18:00" is ambiguous and generates exactly the confusion the app exists to prevent. "Training moved to 18:00 — this Thursday only" does not.

### Proximity rules

- Changes to events **more than seven days out** go in the morning digest rather than a push. There's no urgency, and a push for a rescheduled dentist appointment in three weeks trains people to swipe.
- Changes **within 24 hours** always push, and **cancellations always push regardless of distance** — a cancellation is the one message whose whole value is arriving before someone sets off.
- **Past events never notify.** Correcting last week's record should be silent.
- Cancellation follows the quiet-hours rule above: it may move earlier, never later.

### Post to the event thread too

Where the event has a `linked_event_id` conversation, write the change as a system message into it. The push is the alert; the thread is the record, and it puts "why did this move" in the place where the family will discuss it anyway.

### Quiet hours interaction

`quiet_hours`: `member_id`, `start_time`, `end_time`, `weekdays[]` — enforced server-side.

One rule: **quiet hours may shift a reminder earlier, never later.** A 06:00 departure for an away match needs its 05:30 push even if that sits inside quiet hours; suppressing it until 07:00 makes the notification worthless. So: prep reminders falling in quiet hours move to the preceding evening; departure and event-start reminders are exempt and deliver silently where the platform allows.

Children's devices otherwise stay silent overnight.

### Routing when the child has no device

A `little` member may have no account and no phone at all. Any reminder targeted at a member with no active device falls through to their responsible adult, relabelled ("Emma has swimming at 16:00"). Without this fallback, reminders for the youngest children — the ones needing the most logistics — silently go nowhere.

### Acknowledgement closes the loop

A departure reminder carries an "on my way" action. Tapping it posts a system message into the event's linked conversation (`linked_event_id`, section 6). The other parent then knows pickup is handled without anyone typing. This is a small feature that removes a genuinely repetitive daily exchange.

### Anti-fatigue measures

- **Morning digest** — one push around 07:00 with today's schedule, the primary channel for anything not time-critical. Prefer moving rules to `channel: digest` over adding more pushes.
- **Batching** — several reminders within a 10-minute window collapse into one notification.
- **Per-member, per-kind mute**, reachable in two taps from any notification.
- Track sent-to-opened ratio per rule type. If a rule type drops below roughly 20% engagement, it is training people to swipe everything away, including the ones that matter.

---

## 9. Onboarding, invitation and leaving

The spec has so far described a working family and never how one comes to exist. This is the highest-drop-off surface in any multiplayer app: the first person in sees an empty calendar, and nothing works until someone else joins.

### Getting to a useful first week

1. Create the family — name, timezone, week start.
2. **Add children before inviting adults.** Children are the reason the app exists, and adding them makes every later screen make sense.
3. Seed a first week: school hours, a dinner block, one activity. A blank calendar reads as broken.
4. Invite the second parent by link or QR, with role and tier chosen at invite time.
5. Ask for push permission **after** the first reminder is set up, with a rationale screen explaining what will and won't be sent.
6. **Explain the encryption once, plainly.** Everything is encrypted on the family's devices — there is no setting and nothing to choose. One screen states what that means and what it costs:

> Your family's calendar, messages, lists and photos are encrypted on your devices. Only people in your family can read them — we can't, and neither can anyone else.
>
> That also means we can't recover your data if every family device is lost. Keep your recovery code somewhere safe.

7. **Generate and confirm the recovery kit**, and don't let onboarding complete until it's acknowledged.
8. **Require a second trusted device** before finishing — a second parent's phone or a tablet. A family whose only keys live on one phone is one dropped phone from losing everything, and this is the only moment they'll willingly do something about it.

One consequence to surface in the product rather than bury: revocation is forward-only. Rotating keys stops future access; it cannot un-read what a device already holds. Say so when granting a helper access, and when a teen's supervision ends.

That last point is worth its own line. On iOS a family app whose user denied notifications is close to valueless, and firing the system prompt at launch loses a meaningful share of users permanently with no second chance.

### `invitation`

`id`, `family_id`, `invited_by_member_id`, `token`, `intended_role`, `intended_tier`, `intended_member_id` (claiming a placeholder member), `expires_at`, `accepted_at`, `revoked_at`

Invitations claim an existing member row rather than creating a new one, so a child entered on day one keeps their events and colour when they later get a device.

### Children without devices

A `little` member with no account is normal and must stay a first-class case: they appear on the calendar, are participants in events, have reminders routed to their responsible adult, and can later claim an invitation without any data migration.

### Leaving and removal

Nothing so far covers a member departing — a teen turning 18, a parent leaving after a separation, a helper's window closing.

`membership_end`: `member_id`, `ended_at`, `reason` (`left | removed | expired | aged_out`), `decided_by_member_id`

What happens to their data, decided deliberately:

- **Messages stay**, attributed to a former member. Deleting them makes every thread they appear in incoherent.
- **Events they created stay**; events where they were the responsible member are flagged as unassigned and escalated.
- **Assigned actions return to the family pool.**
- **Location history and care info are deleted**, not archived.
- **Photos they uploaded stay**, since they're usually of the family rather than of them.

Plus **per-member export and deletion**, which GDPR requires and which is expensive to retrofit once everything is family-scoped. Build it while the schema is young.

---

## 10. Screen inventory (phone)

### Parent perspective

1. **Today** — timeline with each member's colour, plus an unassigned-responsibility warning strip.
2. **Week** — 7-column compressed grid, member filter chips, drag to reschedule.
3. **Event detail** — participants, responsible adult, linked chat, recurrence controls (this occurrence / this and future / whole series).
4. **Planner** — activity seasons, routine templates, term switching.
5. **Celebrations** — upcoming birthdays with lead-time reminders and gift notes.
6. **Chat** — thread list; family pinned at top.
7. **Meals** — week of dinner slots, drag a recipe onto a day, cook assignment, child picks marked, the suggestion pool, poll creation and results, "generate list from selected days" action.
8. **Shopping** — active list grouped by aisle, source chips on each item, multi-source composer, staple templates.
9. **Actions** — family pool, per-member lists, delegation inbox, approval queue.
10. **Map** — family positions, place labels, share-state per member, check-in button.
11. **Family settings** — members, tiers, supervision policy, sharing policy, quiet hours.

### Child perspective

- **`little`**: one screen, no scope toggle. Big cards: "Now", "Next", "Today". Photo of the responsible adult on each card. A single tap-to-talk button into the family chat. Homework appears only as a picture card if a parent entered one.
- **`kid`**: opens on `Mine` — own day, homework due strip, my actions, with a `Family` tab alongside. Chat, and a "Can I…?" request button that creates an `approval_request`. Homework entry by photo, two taps to set subject and due date.
- **`teen`**: opens on `Mine` — own week, homework with sessions they schedule themselves, own event creation, full chat, own action list including anything delegated to them. `Family` tab gives the near-parent calendar UI minus editing others.

Homework is a strip above the day rather than a separate tab for `kid` and `little`. A child will not navigate to a homework section; it has to be where they already look.

The perspective is not a theme switch — it is a different information density and a different set of verbs. Build the child views as separate screens rendering the same data, not as the parent view with buttons hidden.

---

### Surfaces beyond the app

A family calendar is mostly read without opening anything.

- **Home-screen and lock-screen widgets** — today's events, who's driving, next action due. Cheap to build and disproportionate to how often the app gets consulted.
- **Kitchen display mode** — a wall-mounted tablet showing the week, today's meal and the shopping list. Large touch targets, no login per interaction, a shared-device session rather than a member login. This is the surface that makes the app part of the household rather than another icon on a phone.
- **Watch complication** for the departure reminder, which is the one notification you want on your wrist while finding your keys.

### Quick capture

Every entry flow described so far is a form, and entry friction is what kills family calendars — the parent goes back to remembering because remembering is faster.

- **Natural language**: "football tuesdays 17:30 at sportshallen until may" parsed into a recurring event with a place.
- **Share sheet** capture from any app — a club's web page, an email, a message.
- **Voice** capture, which doubles as the `little` tier's input method.
- **Photo of a paper schedule.** This is how activity schedules actually arrive from schools and clubs, and it is worth real effort: one photo becoming a season of events is the single most valuable import in the product.

### The weekly review

A Sunday-evening screen the family opens together: next week's conflicts, events with no responsible adult, empty meal slots, unclaimed actions, shopping list status, and anything due.

It is built entirely from data the model already holds, and it is the strongest retention mechanic available — it turns the app from a reference you consult into a routine you keep. Ship it with a gentle weekly nudge, not a nag.

### Accessibility

- Dynamic type throughout; nothing below 11pt, and layouts that survive the largest accessibility sizes.
- Full screen-reader labelling, including the calendar grid, which is where these apps usually fail.
- The colour-blind-safe palette from section 5, with avatar or initials as the redundant cue.
- A genuinely pre-literate interface for the `little` tier — photos, icons and voice, specified as a design constraint rather than left to a photo field.
- Motor accessibility: large targets in the shopping and kitchen display modes especially, where people are one-handed or standing back from a screen.

---

## 11. Sync and offline

Phone apps get used in car parks with one bar. Assume it.

- Local store is the source of truth for reads; server reconciles.
- Per-entity `updated_at` + `version` for last-write-wins on simple fields.
- Events are the conflict-prone entity. Field-level merge beats row-level: two parents editing different fields of the same event should both succeed.
- Messages are append-only — use a client-generated uuid so retries are idempotent.
- Queue mutations locally with a stable ordering; replay on reconnect.

---

### Search, undo and conflict visibility

- **Global search** across events, actions, homework, recipes, people, places and messages, scoped by what the searcher may see. Only chat search was specified before.
- **Undo, especially for a deleted recurring series.** Deleting a season is two taps with no recovery path today. Soft-delete with a 30-day restore window costs almost nothing and prevents the worst support case you will have.
- **A conflict surface.** Field-level merge is specified at the data layer, but nothing tells a user when their change lost. Show it, quietly, with the option to restore their version.
- **A DST and leap-day test matrix** for recurrence. Events at 02:30 on a changeover night, weekly series crossing October and March, 29 February birthdays, and a family travelling across timezones. This is where every calendar system breaks, and it breaks in production rather than in review.
- **Instrumentation for reminders**: sent, delivered, opened, actioned, per rule type. Section 8 asks you to retire rules below roughly 20% engagement, which requires actually collecting the number.
- **Rate limiting and abuse handling on the external wishlist page**, the one unauthenticated surface in the product.

---

## 12. Sequencing

**v1 (the app is useless without these)** — onboarding with invitations and a seeded first week, members and roles including `helper`, `family_settings`, one event table with recurrence, places with addresses, the occurrence projection, agenda-week view with mine/family scope, member filtering and week numbers, responsible adult, conflict detection, end-to-end encrypted family chat with device provisioning and recovery, soft-delete with undo, and the reminder pipeline: prep and departure reminders, the scheduled delivery queue with cancellation on exception, change notifications, quiet hours, morning digest.

**v1 also carries the two structural decisions that are expensive later**: the custody model (an event about a child belongs to the child, not only to a household) and per-member data export and deletion. Neither needs full UI in v1, but the schema must allow both.

**v2** — custody schedules with changeover events and cross-household visibility, home-screen widgets, quick capture (natural language, share sheet, voice, photo of a paper schedule), the weekly review, school terms and lov, away mode, global search, DMs and groups, rich chat (reactions, replies, mentions, proxied link previews, encrypted voice notes and attachments, local search), celebrations with lead reminders, people and relationships, wishlists with hidden claims, per-year lists and external share links, image attachments across entities, actions with delegation and event-relative due dates, homework with due dates and sessions, optional equipment lists on activities, approval flow, routine templates, dinner planning with recipes, meal suggestions and polls, JSON-LD recipe import with Swedish units, shopping lists with multi-source generation, geofenced arrival notifications, check-in/SOS, provider-based travel estimates and travel-gap conflict warnings.

**v3** — kitchen display mode, watch complications, care and emergency information, external event share links and carpool rotas, live family map with full sharing controls, learned route estimates from observed arrivals, driver suggestion, external calendar sync (Google/Apple/school), pantry and `subtract_pantry`, per-site recipe adapters beyond JSON-LD, points/allowance.

Places belong in v1 even though travel estimates don't. Capturing the address from day one costs one form field; retrofitting addresses onto a season of already-entered events is data entry nobody will do.

Deliberate ordering note: named places and arrival events land before the live map. They cover most of the real need, cost far less battery, carry far less data risk, and let you learn how your household actually uses location before shipping continuous position sharing on children.

Resist starting at v3. External calendar sync in particular is a swamp — two-way sync with recurrence exceptions is harder than everything else in this document combined.

Two items sit higher than their apparent size. **Quick capture** belongs early because entry friction, not feature count, is what kills family calendars — a photo of a club's paper schedule becoming a season of events may be the highest-value import in the product. **The weekly review** belongs early for the same reason in reverse: it is the habit that makes the rest get used, and it is built entirely from data you already hold.

---

## 13. Open questions

1. ~~Separated households~~ — now modelled in section 3 as `custody_arrangement`. The remaining question is narrower: when the other household doesn't use the app, is a read-only shared calendar link enough, or does the co-parent need a limited account?
2. Is the DM supervision policy per-family, per-child, or fixed by tier?
3. Do actions need a reward economy, or does that turn chores into negotiations?
4. Does a teen need a "private" event visibility that parents cannot see the details of, only the busy block?
5. GDPR: children's data, parental consent for under-13 accounts, data export and deletion on a child reaching majority.
6. How much ingredient catalogue do you seed? A thin catalogue means constant free-text fallback and poor merging; a rich Swedish grocery catalogue is real curation work but is what makes generation feel magical on day one.
7. One rolling shopping list, or a new list per shop? Rolling is simpler to use and harder to model cleanly (what does "completed" mean); per-shop is the reverse.
8. When a meal plan changes after shopping is done, does the app say anything? Probably not — but decide deliberately rather than by omission.
9. At what tier does a child gain control of their own location sharing, and can a parent override it? This is the same trust trade-off as DM supervision and should probably be answered the same way, for consistency.
10. Does the map show adults to children? Mutual visibility is the more defensible design, and it costs nothing to build — but some parents will object.
11. Is the location trail retained at all, or only latest position plus arrival events? Choosing "no trail" is a legitimate product position and removes most of the compliance burden.
12. Which geocoding and routing provider, and does its licence allow caching coordinates? Several forbid storing results, which breaks the offline requirement and the learned-estimate model. Check this before building against one.
13. Do places store third-party addresses — a child's friend's home, a classmate's parents? That is personal data about people outside the household who never consented, so keep it minimal and family-scoped.
14. Is `arrive_before_minutes` per event or per activity season? Per season is less typing; per event handles the match that needs an hour's warm-up.
15. Does homework import from a school platform (SchoolSoft, InfoMentor, Google Classroom)? Manual and photo entry works from day one; imports are per-school integrations that age badly, and a half-working import is worse than none because nobody knows whether the list is complete.
16. Can a teen hide a homework item from parents? Consistent with the DM and location answers, probably yes above a tier — but it interacts with the overdue digest, so decide both together.
17. Does the cook get a veto? The person making the meal has a legitimate claim the voters don't, and "you voted for it, you cook it" is a real household rule worth supporting explicitly.
18. Are votes attributable after close? Showing who voted for what is transparent but invites "you never pick mine". Anonymous tallies with visible turnout may be the calmer default.
19. How much recipe content do you store versus link to? Structured ingredients plus a link is the low-risk pattern; a full local copy of instructions is better offline in the kitchen but is someone else's writing. Worth settling before the library grows.
20. ~~End-to-end or server-side chat?~~ — decided: end-to-end, with supervision as key membership (section 6). The remaining question is which recovery path is the default when a device is lost.
21. Do external share links expire by default, or persist until revoked? Expiry is safer and slightly annoying; persistence is convenient and accumulates live links to children's pages that nobody remembers creating. The spec assumes expiry.

---

## 14. Scope boundaries

Everything from the gap review is now specified in the sections above. These are the things deliberately left out, with the reasoning, so they don't get re-proposed every quarter.

- **Shared expenses and bill splitting.** A real need and a different product. It drags financial data handling into an app that otherwise avoids it entirely, and every family already has a way of settling this.
- **Inter-family federation.** Households linking to each other as first-class entities is enormous — identity, consent, moderation, abuse. The read-only event share link and external participants cover most of the coordination value for a fraction of the cost.
- **Grades, marks and behaviour tracking.** Argued in section 3: it converts a planning tool into a performance record that parents monitor, and children stop being honest in it.
- **Streaks, scores and compliance metrics** on chores, equipment or homework. Same reasoning. The app should help a family run; it should not generate evidence for arguments.
- **A full pantry inventory.** Specified as optional and v3 for a reason — families abandon inventory tracking fast, and a wrong inventory is worse than none.
- **Continuous location history beyond a short trail.** Deliberate: high liability, low family value, and the arrival events answer the actual question.
- **Two-way external calendar sync in early versions.** Recurrence exceptions across two systems is harder than everything else in this document combined.

### What to settle before writing code

In rough order of how expensive they are to reverse:

1. ~~The chat encryption decision~~ — settled: end-to-end with MLS, supervision expressed as key membership (section 6). What remains is device-recovery policy.
2. The custody model in the schema, even without UI (section 3).
3. Per-member export and deletion (section 9).
4. The DM and location supervision policy, and the tier at which children gain control (sections 2 and 7).
5. Your geocoding and routing provider's caching licence (section 3).
