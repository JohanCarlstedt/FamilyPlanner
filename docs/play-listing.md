# What to put in the Play Console

Everything the internal-testing listing asks for, written out to be
copied. `docs/play-store.md` is the *how*; this is the *what*.

Two things before any of it.

## The one answer that has changed since play-store.md was written

That page says **in-app purchases: none**. That was true when it was
written and is no longer necessarily true: the app now has a premium
subscription behind RevenueCat.

Whether it is true of *your bundle* depends on how you build it:

- Built **without** `--dart-define=REVENUECAT_GOOGLE_KEY=…`,
  `Billing.available` is false, the paywall says buying is unavailable
  and nothing can be purchased. **In-app purchases: none** is then
  accurate, and RevenueCat is not a third party receiving anything.
- Built **with** the key, the answers change: in-app purchases **yes**,
  a third party **does** receive data (a random billing id — see below),
  and the store listing has to say the app offers a subscription.

**Recommendation for internal testing: build without the key.** The
family is not buying anything from itself, the declarations stay simple,
and nothing about this decision is permanent. The command in
`play-store.md` already omits it, so the default is the honest one — but
check before you upload, because getting this wrong is a false
declaration rather than a mistake.

## The app's name has a stray full stop

App Store Connect currently carries **"Family Planner Pro."** — with a
trailing full stop, which was a typo. The Android app's own name is
**"Family Planner"** (`build.gradle.kts`, prod flavour). Use *Family
Planner* on Play and fix the Apple one when convenient; two stores
disagreeing about an app's name is the kind of small wrongness that is
awkward to correct once people have installed it.

---

## Store listing

**App name** (30 characters max)

```
Family Planner
```

**Short description** (80 characters max)

```
One calendar for the whole family. Private by design, end-to-end encrypted.
```

**Full description** (4000 characters max)

```
Family Planner keeps one household organised: the calendar, the week, who
is driving whom, what is for dinner, the shopping list, homework, and the
questions a family has to answer together.

It is built for a family that wants to run its own life, not to be the
product. Everything the family writes is encrypted on the phone before it
leaves it. The server stores sealed bytes and routing information, and
cannot read a single event title, message or shopping item — not because
it promises not to, but because it does not hold the keys.

THE DAY, AND THE WEEK
• Today opens on a summary: what is on, when the next thing starts, what
  is due, who is away — and, separately, anything that needs a person
  rather than their attention, like a child's activity with no adult
  responsible or two things booked over each other.
• The week shows all seven days, in each family member's colour, with the
  weather, school breaks and holidays on the days they cover.
• Repeating events understand real life: move one occurrence, or this one
  and all after it, or the whole series.

EVERYONE'S SHARE OF IT
• Children can add and correct their own entries; the youngest see today
  and tomorrow and nothing more.
• Chores rotate between people and plan themselves a month ahead.
• Homework has its own place, including who is seeing to it, and appears
  on the day it is due.
• A babysitter can be given access to one evening and the children it
  concerns, and it ends by itself.

FOOD AND SHOPPING
• Plan the week's dinners, and send the ingredients to the shopping list
  in one go — the list knows how much came from where, so removing a meal
  takes exactly its share back off.
• Recipes are read from a page on the phone: the link, the ingredients
  and the family's own notes, never the website's method text.

TALKING, AND DECIDING
• Family chat, and conversations between individuals, end-to-end
  encrypted with MLS — the same protocol standardised for secure
  messaging.
• Ask the family a question with a closing time, and everyone hears the
  result. Nobody has to remember to tell anyone.

WHERE PEOPLE ARE
• Share your position with the people you choose, at the precision you
  choose — exact, roughly, or just which place you are at.
• Only the latest position is ever kept. There is no trail, anywhere, by
  design: this app can answer "where are they now" and can never answer
  "where have they been".
• It is never silent. While it is sharing, your own phone says so, and
  your own screen tells you whether you chose it or a parent did.

WHOSE DATA THIS IS
• End-to-end encrypted: the server cannot read your family's content.
• No advertising. No analytics. No profiling. Nothing sold, ever.
• Export what your family has, or delete it, from inside the app.
```

**App icon** `app/apps/family/tool/play/icon-512.png`
**Feature graphic** `app/apps/family/tool/play/feature-1024x500.png`
**Phone screenshots** `app/apps/family/tool/play/0{1,2,3,4}-*.png`

Retake the screenshots after any visible change:

```bash
cd app/apps/family && flutter test --update-goldens tool/make_screenshots.dart
```

**Category** Parenting, or Productivity. Parenting fits what it is;
Productivity is where people look. Either is defensible.

**Contact email** your own. It is shown publicly on the listing.

**Privacy policy** `https://2.29.40.14.sslip.io/privacy` — already served
by Caddy from `infra/site/privacy.html`. See the roadmap's hostname item
before this becomes permanent.

---

## Data safety

Answer as the app actually behaves. Where Play asks "collected" it means
"leaves the device", which sealed bytes do — so these are all yes, and
the encryption answers are what make that honest.

| Category | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Name | Yes | No | App functionality | Required |
| Email address | No | — | — | — |
| Approximate location | Yes | No | App functionality | Optional |
| Precise location | Yes | No | App functionality | Optional |
| Photos | Yes | No | App functionality | Optional |
| Messages (in-app) | Yes | No | App functionality | Optional |
| Calendar events | Yes | No | App functionality | Required |
| Files and docs | Yes | No | App functionality | Optional |
| Health, financial, contacts, browsing, audio | No | — | — | — |

Then:

- **Is all of the data encrypted in transit?** Yes.
- **Do you provide a way to request data deletion?** Yes — in the app, and
  the family can delete its own server.
- **Is the data end-to-end encrypted?** Yes. Say so; Play has the box, and
  it is the single most important true thing about this app.
- **Collected for advertising, analytics or personalisation?** No, to all
  three. None of those exist in the code.

**If and only if you built with the RevenueCat key**, add: *Purchase
history — collected, shared with a third party (RevenueCat), for app
functionality.* What RevenueCat receives is a random billing id and
nothing else: not the family id, not a name, not an email. That design is
in `docs/going-public.md` and is worth stating in the listing if asked.

---

## Content rating questionnaire

- Violence, sexual content, profanity, controlled substances: **no** to
  all.
- **Does the app contain user-generated content?** Yes — chat and shared
  notes.
- **Is that content visible to other users?** Yes, but only to members of
  the same household, who are invited by scanning a code in person. It is
  not public, there is no discovery, and strangers cannot reach each other
  through it. Say exactly that; it is the answer the question is for.
- **Does it share the user's location with other users?** Yes, with people
  the user chooses, and only the latest position.
- Ads: **none**. In-app purchases: see the note at the top.

Expect **PEGI 3 / ESRB Everyone**.

---

## Target audience and content

This is the section with real consequences, so answer it deliberately.

Children use this app — that is what it is for. Ticking an under-13 age
band brings Google's **Families policy**: a separate review, stricter
rules on ads and analytics (the app has neither, which helps), and a
requirement that the app be appropriate for children.

- **Target age groups**: the honest answer includes under-13 *and*
  adults, because the app is designed for a household containing both.
- **Is the app designed primarily for children?** No. It is designed for a
  family; children are members of it, not the audience.
- **Do you want your app in the Designed for Families programme?** No —
  it is a private household app on internal testing, not a listing anyone
  should find.

---

## Permissions that get their own review

**Background location** is reviewed separately from everything else, and
is the most likely reason a release sits waiting.

- **Why the app needs it**: a parent seeing where a child is when neither
  has the app open — the whole point of the feature.
- **Why a foreground-only permission will not do**: the question is asked
  when the app is closed. On the way home, on the way to training.
- **What is kept**: the latest position only, cut to the precision the
  person chose, encrypted on their phone before it is sent. There is no
  history table.
- **Video**: Play asks for a recording of the feature in use. Show:
  More → Family map → turning *Share while using* on, then *Share always*,
  the permission prompt, and the Android notification that appears and
  cannot be dismissed while it is sharing. That notification is the point
  — it is how the app keeps the promise that this is never silent.

Other permissions worth a sentence if asked: **fine location** (places
and sharing), **calendar read** (importing the phone's own calendars,
never written back), **notifications** (reminders), **microphone** (a
child asking a question out loud instead of typing it; on-device
dictation, nothing recorded or uploaded).

---

## App access for the reviewer

A reviewer cannot get in: there is no sign-up, and joining a family means
scanning a QR code held up by a device already in it.

Answer **"All functionality is available without special access"** if the
app is on internal testing only — the testers are the family, invited by
email, and there is no reviewer sign-in to provide. If a reviewer does
ask, the truthful explanation is that the app creates a new empty family
on first run, and that is the full experience for a new household; no
credentials exist to hand out because none are ever issued.
