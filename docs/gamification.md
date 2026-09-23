# Gamifying chores and homework: an investigation

Asked for on 2026-09-23: a ranking system for to-dos and homework, and a
game inside the app that is unlocked by doing them. This is the
investigation, not a build. Nothing here is decided.

## What the spec already says

It says no, and says why. Section 14, scope boundaries:

> **Streaks, scores and compliance metrics** on chores, equipment or
> homework. The app should help a family run; it should not generate
> evidence for arguments.

Section 3 on the kit list: the moment the app can say "Emma forgot her
shin guards three times this month", a helpful list has become a
compliance record that a parent can produce in an argument. Grades and
behaviour tracking are ruled out for the same reason: children stop being
honest in it. Open question 3 is still open: *do actions need a reward
economy, or does that turn chores into negotiations?* The action entity
also keeps a `points` field marked "optional allowance mechanic, v3".

So this request reverses a scope boundary. That is allowed (CLAUDE.md:
decisions here get reversed on good evidence), but it should be reversed
on purpose, with the spec updated, not built around quietly.

## What the objections actually are

They are worth taking seriously because they are specific, not
squeamish:

1. **A score is a record.** Anything that counts over time can be quoted
   back: "you only did two chores this week." The app then serves
   arguments rather than the week.
2. **Children stop being honest in it.** Once marking something done
   earns something, marking it done becomes the goal. Chores have an
   approval step (`requires_approval`); homework does not, and "done" on
   homework is self-reported.
3. **A ranking between siblings is unfair by construction.** A seven-year-
   old and a fourteen-year-old are not doing the same chores at the same
   speed. Whoever is older wins, every week, and the younger one learns
   the list is not for them.
4. **Chores become negotiations.** "How many points is the dishwasher?"
   is a conversation the family did not have before the app priced it.

What rewards do well is also real: some children genuinely respond to
seeing progress, and a chore with no intrinsic appeal (emptying the
dishwasher) is exactly where an external nudge helps most. The question
is which shape gets that without the four costs above.

## Four shapes, from closest to the spec to furthest

### A. Together, not against each other

The whole family fills one shared thing each week: a jar, a meter, a
picture that completes. Every approved chore and every finished piece of
homework adds to it, whoever did it. A full jar unlocks something the
family chose together: Friday's film, pizza night, a trip.

- No individual score exists, so there is no record of who slacked.
- The seven-year-old's contribution fills the same jar as the teen's.
- Resets every week. Nothing accumulates.

Closest to the spec: it rewards the week going well rather than ranking
anybody. The risk is a child who never contributes and is carried; that
is a family conversation, and not one the app should settle.

### B. Your own progress, compared with nobody

Each child sees only their own progress: a level, or better, something
that grows. It is never shown next to a sibling's, and the child sees
the same thing a parent sees. It resets or winds down weekly, so it
cannot become a history.

Honest about its limits: a parent can still look at it, so it is a small
record. Weekly reset and no history keep it small.

### C. A small game that the progress feeds

This is the "unlock a game" in the request, done so it is the progress
rather than a separate prize. For example, a garden or a pet:

- Each done chore or homework gives a seed or food.
- Things grow, new plants or animals unlock at milestones.
- Nothing dies or is lost for a quiet week. A game that punishes the
  child for a week of illness or a holiday is a compliance record with
  graphics.

Better than "earn ten minutes of a separate game", which trades chores
for screen time on the same phone, and invites the question of why the
chore app is also a games console. A self-contained garden is small,
works offline, needs no network and no ads, and does not change the
app's store category or content rating.

### D. A ranking (what was asked for)

A leaderboard of who did most. Everything in section 14 argues against
it, and objection 3 has no fix: weighting by age or by
`estimated_minutes` makes it less unfair, not fair, and a child who is
always last knows it. If the family wants it regardless, the least
harmful form is opt-in per family, weekly, reset every Monday, no
history, and never shown to anyone outside the household.

## How any of it would be built, whichever shape

- **Derived, never stored.** Progress is computed on each phone from
  things that already exist: action history (`done`, `approved`,
  `completedBy`) and homework state. There is no score object to edit,
  and nothing new for the server to hold. Invariant 1 holds: the server
  sees none of it.
- **Chores count when approved,** where the chore asks for approval.
  That is the existing guard against ticking without doing.
- **Homework is the hard part.** Its "done" is self-reported and has no
  approval step. Counting it directly is exactly objection 2. Options:
  count homework only in shape A (the shared jar, where cheating helps
  nobody in particular), or give homework an optional parent "seen it"
  step before it counts.
- **Weekly windows** in the family's time zone, like everything else
  here (invariant 4).
- **Domain first.** The rule "what counts, in which week, for whom" goes
  in `packages/domain` with its tests, like the weekly review.

## Recommendation

Build **A and C together** and leave D out: a shared family jar for the
week, and each child's own garden that their chores and homework feed,
never compared, nothing lost for a quiet week. It gets the motivation
and the unlock without a record, a ranking or a price list.

Before any of it: answer open question 3 in the spec and amend the
section 14 boundary to say which form is allowed and why, so it is not
re-argued every quarter.

## For the family to decide

1. Which shape: A, B, C, D, or a mix?
2. Does homework count, and if so, only towards the shared jar, or with
   a parent "seen it" step?
3. Is it linked to anything real (allowance, screen time), or is the
   reward only inside the app and in what the family agrees?
4. For C: garden, pet, or something else the children would actually
   want?
