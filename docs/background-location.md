# Sharing a position when the app is closed

`ShareMode.always`: the family can see where someone is without that
person's phone being open. What it does, what it deliberately does not,
and the declarations both stores require before it may ship.

## The decisions, and who made them

- **Children by a parent's floor; adults choose for themselves.** The
  same shape supervision already has for messages (spec open question 9),
  so a teen above the family's supervised tier decides alone.
- **Never silent**, for anyone, a child who cannot switch it off
  included. `sharingNotice` in the domain package says whether someone is
  being followed, whether they chose it, and whether they may turn it
  down; the map screen says it on their own phone.
- **Built before going public**, with these declarations, rather than
  after.

## What is kept, which is the whole defence

**The latest position and nothing before it.** Positions go to a slot the
server keeps exactly one of, per person, and they are cut to the chosen
precision — exact, about a kilometre, or place only — on the sharer's own
phone before they are sealed. There is no table a trail could accumulate
in.

So "all the time" here means *where are they now*, never *where have they
been*. That is the difference between this and every commercial family
tracker, it is the reason the feature is defensible to a reviewer and to
a teenager, and it must not be traded away for a feature request later.

## Never silent, in practice

Both operating systems say so themselves, and that is deliberate rather
than tolerated:

- **Android** runs it as a foreground service, so there is a notification
  the person cannot dismiss while it is on.
- **iOS** keeps the blue location indicator up
  (`showBackgroundLocationIndicator`).

Neither is worked around. Covert tracking was never on offer — the
indicators appear regardless — so an app that looked like it was trying
would only teach a child not to trust it.

## Battery

A stream the operating system drives, waking on movement of
`LocationReporter.backgroundMeters` (100 m), not a timer. A timer would
not work anyway: the app is suspended, and its timers with it. iOS is
also allowed to pause updates when someone is plainly still.

## What Google Play needs

Background location is reviewed on its own, separately from the app.

1. **Declare it** in Play Console → App content → Sensitive app
   permissions → Location permissions.
2. **Say what it is for.** The honest version, which is also the one that
   passes: *a parent seeing where a child is when neither has the app
   open — the feature the app is for, not an enhancement of it.*
3. **A demo video**, publicly viewable, showing the in-app flow:
   - the map screen with sharing off,
   - turning on "Also when the app is closed",
   - the permission prompt and choosing Always,
   - the ongoing notification appearing,
   - another family member's map showing the position.
   Show the notification. It is evidence for the claim, not an
   embarrassment to crop out.
4. **Runtime flow.** `ACCESS_BACKGROUND_LOCATION` is requested only after
   the ordinary permission is held and only from the screen where the
   person chose it (`askForAlwaysLocation`). Play rejects apps that ask
   at launch, and rightly.

Expect this to take longer than the rest of the review put together.

## What App Store review needs

No separate submission, but the review notes should say:

- The purpose strings, which were rewritten rather than quietly dropped —
  they used to promise "it never follows you in the background".
- That a parent may set it for a supervised child, and that the child's
  own screen states it plainly and names it as a parent's decision.
- That only the latest position exists anywhere, and that it is encrypted
  on the sharer's device before it leaves.
- The demo path (docs/going-public.md), so a reviewer can reach the map
  at all.

`UIBackgroundModes` includes `location`, and
`NSLocationAlwaysAndWhenInUseUsageDescription` describes background use
in the terms above.

## The privacy policy

It currently describes sharing while the app is open. Before this ships
to anyone outside this household it has to say: when background sharing
is on, who it is visible to, that only the latest position is kept, that
the person is always told, and that a parent may set it for a supervised
child.

## Still to do

- Wire the child's own Today screen to carry the notice too, not only the
  map. Someone who never opens the map should still be told.
- Geofenced arrivals (spec §7): "at school since 08:12" exists, but
  arriving somewhere does not yet notify anyone.
- Watch a real phone for a day and see what it costs in battery. Nobody
  has, and the 100 m figure is reasoning rather than measurement.
