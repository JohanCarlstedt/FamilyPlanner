# ICA, and what a shopping list can honestly do

Two separate questions get muddled here: getting recipes *from* ICA, and
getting the family's list *into* ICA.

## Recipes: already works

ICA's recipe pages carry schema.org JSON-LD, so pasting a link imports
the title, ingredients and servings like any other site (spec §4). Only
the link, the structured ingredients and the family's own notes are
kept — never the method text, which is theirs.

## The list: sent, not synced

The shopping list has **Send the list**, which hands the still-needed
items to whatever the family shops with — ICA's app, Coop's, or a message
to whoever is already at the shop. It works everywhere and asks the
family for nothing.

## Why not a real ICA account integration

It is technically possible. ICA's app talks to `apimgw-pub.ica.se`, and
an unofficial MCP server ([kanylbullen/ica-mcp][mcp]) already drives it:
read and edit the real shopping lists on an account. Four things argue
against wiring it in here, and they are worth writing down so the
question stays answered:

1. **It wants a personnummer and a password.** That is the credential
   that opens someone's grocery account, and storing it to sync a
   shopping list is a poor trade. BankID-only accounts cannot be used at
   all, which is how many people have theirs.
2. **It refuses non-Swedish addresses** — `451` to anything outside
   Sweden. The family's server is in Helsinki, so this could only ever
   run on a phone, never as part of sync.
3. **It is nobody's published contract.** An undocumented private API
   changes without notice, and a shopping list that silently stops
   syncing is worse than one that was never claimed to.
4. **ICA may simply not want it.** The spec already says to check whether
   the chains offer a sanctioned integration before building against
   their internals.

**What would change this:** ICA publishing an API, or an MCP server of
their own. Then the list could sync properly, and the login would be
theirs to handle rather than ours to store.

[mcp]: https://github.com/kanylbullen/ica-mcp
