# Calendars from elsewhere

Two ways in, for two different things.

## The phone's own calendars

More → **This phone's calendars**. Whatever the phone already syncs —
Google, Outlook, iCloud, a work account — can be shown in the family's
calendar.

This is the whole integration. There is no OAuth client registered with
Google or Microsoft, no refresh token kept anywhere, and neither company
is told that this family exists. The phone did the syncing; the app reads
what is already on the device, which is also why it works offline and
updates within minutes rather than the hours a published feed lags.

Two choices per calendar, because they are the ones that matter:

- **Which calendars.** Off by default, one switch each. Most people want
  one work calendar visible, not an entire account.
- **Busy only, or full details.** Busy shares the time and nothing else —
  no title, no place, no notes. A work calendar full of client names has
  no business in a family planner, but "unavailable 14:00–15:00" is
  exactly what stops a double-booking. It is the default.

The choice is per device and never synced: these are the accounts signed
in on *this* phone, and another member's phone has its own. What syncs is
the events the choice brings in, sealed to the family like everything
else.

Entries arrive through the same import as a subscribed feed, so they
inherit its behaviour: a stable id per entry (no duplicates on the next
sync), an event the family deleted stays deleted, and one that disappears
from the phone is cancelled rather than silently vanishing.

**Permissions.** iOS asks once (`NSCalendarsFullAccessUsageDescription`,
and the pre-17 key beside it); Android needs `READ_CALENDAR`. Read-only:
nothing is ever written back to anyone's calendar.

## Subscribed feeds

More → **Linked calendars**, for schedules nobody has in their phone: a
team's fixtures, a school's term dates. A parent's device fetches the ICS
every three hours and imports it; the server never sees the URL.

Google and Outlook can both publish a secret ICS address, so a calendar
can come in this way too — but they refresh it slowly, often hours late.
For a calendar that is already on the phone, the phone is the better
source.

## What was decided against

**OAuth against the Google Calendar API and Microsoft Graph.** It buys
real two-way sync and push notifications, at the cost of registering
OAuth clients, Google's verification review, and refresh tokens that have
to live somewhere. Somewhere means the server, and a server that holds
tokens and reads plaintext events breaks the first invariant this project
has. Doing it on the device instead is the same result with none of that
— which is what the phone's own calendars already are.

**CalDAV.** Works for iCloud and, with OAuth, Google. Not Outlook. Half a
solution for twice the work.

## The school's week letter

More → Homework → the document icon. A teacher's veckobrev can be shared
into the app from Word, Teams or OneDrive, or pasted as text; the app
reads the homework out of it and shows what it found for someone to
confirm.

**Why sharing rather than fetching.** A SharePoint link like
`harrydakommun-my.sharepoint.com/:w:/g/personal/...` answers **401** to
anyone outside the school's tenant — tested, not assumed. Fetching it
would need an app registered in the municipality's Entra directory, with
their IT consenting to it, which is not a thing that happens for a family
app. The document shared out of Word arrives readable because the app
that shared it was already signed in.

**It proposes, never imports.** Teachers write these letters differently
and change the layout every term, so every deadline here is a heuristic.
The parser reads lines that look like homework — a subject with a colon,
"läxa", "glosor", "prov", "inlämning" — takes the date it finds, or the
weekday if that is all there is, and leaves the rest out. A line it does
not understand is dropped rather than guessed at, and nothing is saved
until a person has ticked it.

**Not yet:** a photo of the whiteboard, which the spec calls the entry
flow that survives a Tuesday evening. It needs OCR, and the same confirm
screen would follow it.
