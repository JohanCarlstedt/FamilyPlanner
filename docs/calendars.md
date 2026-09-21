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

## The school's week plan

### Setting it up

There is no configuration to fill in. A family arrives with whatever
their school gives them, and all four routes end at the same confirm
screen:

| What the school does | What the family does |
|---|---|
| Publishes a document (SharePoint, OneDrive, Teams) | Share the link once — **Keep this for next week** saves it against that child, and Homework opens straight into the current week after that |
| Emails a letter, or hands one out | Share the document into the app, or paste its text |
| Writes it on the board | Photograph it |
| Uses a system nobody can read | Add the homework by hand, as before |

The link is saved **per child**, because siblings are in different
classes and often different schools. The class within the document — the
row in the table — is picked once and remembered with it.

Nothing about this is required. A family with no link loses nothing they
had before.

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

**The link works too.** A SharePoint "anyone with the link" address does
serve the document without a login — but only to something that looks
like a browser; with a script's own user agent it answers 401, which is
what made this look impossible at first. The share token becomes a
download address, the phone fetches it, and the family's server never
sees the school's address. A link that genuinely needs a sign-in says so
instead.

**Most of them are tables, not letters.** A veckoöversikt is a grid:
weekday columns, often with only Monday dated, and a row per class, with
homework in the cells and several subjects in one cell
("Sv: Läsuppdrag och veckans ord Eng: glosor"). Flattening that to lines
loses which day a cell belonged to, so the tables are read as tables —
the column gives the date, the row gives the class, and the cell is split
where a new subject starts. The class is chosen once and remembered on
that device.

The same table carries school news: a conference day, a vaccination time,
an outing. Without a subject in front of it and without a word that means
homework, a cell is something to read rather than something to do, and it
is left out.

**It proposes, never imports.** Teachers change these documents every
term, so everything here is a guess about someone else's formatting. A
cell it cannot place leaves the homework dateless rather than wrongly
dated, and nothing is saved until a person has ticked it.

**A photograph of the whiteboard** works the same way: take one in the
app, or share one into it, and the text is read **on the phone** (ML
Kit's local model) before the same confirm screen. A classroom
whiteboard has other children's names on it, so the picture is never
uploaded — and it is not kept either; only the text it produced, and only
what someone ticks.
