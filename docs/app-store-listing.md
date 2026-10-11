# What to put in App Store Connect

Everything the App Store submission asks for, written out to be copied,
in the order App Store Connect shows it. `docs/play-listing.md` is the
same thing for Google; `docs/going-public.md` is why. Written 2026-10-11
against build 0.7.0+44.

Read the first section before typing anything: five things in the app
or the account are not ready, and two of them are rejections waiting to
happen.

---

## Before submitting: what has to change first

### 1. A way to delete the family — rejection if missing

Guideline 5.1.1(v): an app that lets people create an account must let
them delete it, in the app. Creating a family is creating an account.
What exists today is per-member erasure and a device leaving the
family; **deleting the family itself, and its data on the server, does
not exist** (`going-public.md` lists it under phase 3). Build it before
submitting: More → Family settings → Delete the family, with a typed
confirmation, which deletes every object, blob, device and the family
row on the server and wipes this phone.

### 2. Export compliance — the Info.plist answer is wrong

`ios/Runner/Info.plist` says `ITSAppUsesNonExemptEncryption = false`,
meaning "only the encryption built into iOS". That is not this app. The
Rust core implements standard algorithms itself, in addition to iOS's
HTTPS: HPKE with X25519, ChaCha20-Poly1305, Ed25519, HKDF/SHA-2, Argon2
and MLS (OpenMLS). None of them is proprietary.

Apple's table for that case ([export compliance
documentation](https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption)):
an app using **industry-standard algorithms not provided by the
operating system** needs no US paperwork uploaded to App Store
Connect, but **does need a French encryption declaration if it is
distributed in France**. A [third-party
guide](https://developer.signicat.com/docs/mobile-identity/encap/sdk-ios/publish-your-app/apple-export-compliance-requirements/)
agrees, and advises removing France from availability if you have no
French declaration.

So:

- Change the key to `true` in the next build (I can do this), and
  answer the questions per build: *uses encryption: yes*, *proprietary
  or non-standard algorithms: no*, *standard algorithms instead of or
  in addition to the OS's: yes*.
- **Leave France out** of availability (below). Sweden-first was the plan
  anyway.
- Re-read Apple's page on the day you submit; this is export law, and
  the wording moves.

### 3. Premium must either work or not be shown

The App Store build is made without `REVENUECAT_APPLE_KEY`, so More →
Premium opens a paywall that says buying is unavailable. A reviewer who
finds a purchase screen that cannot purchase rejects under 2.1 (app
completeness). Either set up the products and the key (docs/billing.md)
**or hide the Premium entry when `Billing.available` is false**. The
second is a one-line change, and launching free first is simpler in
every other section too. Everything below assumes free, no in-app
purchases.

### 4. Screenshots at the sizes Apple takes

`tool/make_screenshots.dart` renders 390×844 pixels for Play. App Store
Connect needs **6.9-inch iPhone (1320×2868)**, and because the app runs
on iPad (`TARGETED_DEVICE_FAMILY = 1,2`), **13-inch iPad (2064×2752)**.
Up to ten each, minimum one. The tool can render both from the sample
family at the right size and pixel ratio (I can add it).

### 5. A support address someone answers

The privacy page (`infra/site/privacy.html`, served at
`https://2.29.40.14.sslip.io/privacy`) has no contact address, and the
Support URL must lead to a way to reach you. Add an email address
to the privacy page, and a short `/support` page beside it (same
Caddy route pattern). Use an address you will keep, because both
stores test it.

---

## App Information (left column → General → App Information)

| Field | Enter |
|---|---|
| Name | `Family Planner Pro` (already reserved; "Family Planner" was taken) |
| Subtitle (sv) | `Krypterad familjekalender` |
| Subtitle (en-GB) | `Encrypted family organiser` |
| Primary language | **Swedish**: Sweden is the first market and every tester is Swedish. Add English (U.K.) as a second localisation. |
| Bundle ID | `io.github.johancarlstedt.family` (set, permanent) |
| Category | Primary **Productivity**, secondary **Lifestyle** |
| Content rights | **No**, it does not contain, show or access third-party content. Recipes are fetched by the family's own phone from a link they paste, and only the ingredients are kept. |
| Age rating | See below |
| Privacy Policy URL | `https://2.29.40.14.sslip.io/privacy` (moves when the domain exists; editable later) |

### Age rating questionnaire

Answer as the app behaves. Every content question (violence, sexual
content, profanity, drugs, gambling, horror, medical information) is
**None / No**. The questions that matter:

- **User-generated content: Yes.** Chat, notes, lists and photos.
  Visible only to members of the same household, who join by scanning
  a code shown on a device already in the family. No public content,
  no discovery, no way for strangers to reach each other.
- **Messaging and chat: Yes**, within the family only.
- **Location sharing:** if asked, yes, with people the user picks, latest
  position only.
- **Advertising: No.** There is none.
- **Unrestricted web access: No.** Links open in the system browser; the
  app has no browser of its own.
- **Parental controls: Yes.** Parents set what children share and
  whether parents can read younger children's messages.
- **Made for Kids: No.** Do not enter the Kids Category (going-public.md
  explains why). The app is set up and run by a parent.

App Store Connect works out the rating from the answers. Don't pick a
rating to aim for. Answer the questions and accept the result.

---

## Pricing and Availability

- **Price:** Free.
- **Availability:** **Sweden only** to begin with. Norway, Denmark and
  Finland can follow once the support load is known. **Never France**
  until there is a French encryption declaration (see 2 above).
- **Pre-orders:** No.
- **iPad and Mac:** keep iPad. Turn **off** "Make available on Mac
  (Apple silicon)" and visionOS: neither has been tested.

### EU trader status (Digital Services Act)

App Store Connect asks every developer who distributes in the EU whether
they are a **trader**. A trader's address, phone number and email are
shown publicly on the listing. A free app from a private person who
isn't running a business is usually not a trader. Once premium charges
money, it probably is. **This is your call, and it is legal, not
technical.** If unsure, answer "trader" now: it's the safer answer.
But your home address becomes public unless you use a business address.

---

## App Privacy (left column → App Privacy)

Apple's definition of "collect" is data sent off the device and kept
"in a readable form" ([App privacy
details](https://developer.apple.com/app-store/app-privacy-details/)).
The server can read none of the family's content. You could argue that
nothing is collected. Apple doesn't say so for end-to-end encryption,
though. **Declare it anyway:** overstating a label costs nothing, while
understating one is a rejection or a removal. It also matches what
Play's Data safety form says (`play-listing.md`).

Data types to declare. For every one: purpose **App Functionality**
only, **not used for tracking**. The data sits under the family's
account on the server, but only in encrypted form. Answer **Not linked
to you** and say why in the privacy policy. If App Review disagrees,
switching to "linked" makes the label stricter, never misleading.

| Apple's category | Data type | Why |
|---|---|---|
| Contact Info | Name | Members' names, in the encrypted profile |
| Location | Precise Location | Position sharing, places |
| Location | Coarse Location | Weather: about a kilometre, sent to MET Norway |
| User Content | Emails or Text Messages | The family chat |
| User Content | Photos or Videos | Photos on homework, wishes, events |
| User Content | Other User Content | Events, lists, to-dos, notes, homework, saved passwords |
| Identifiers | Device ID | The device's random id and its push token |

Not collected (answer no):
- Email, phone number, physical address
- Contacts
- Health and fitness
- Financial info
- Purchases (while free)
- Browsing and search history
- Audio: dictation runs in iOS's own speech service, and nothing reaches our server
- Usage data, diagnostics: there's no analytics and no crash reporting
- Sensitive info

---

## The version page (iOS App → 1.0 Prepare for Submission)

**Version:** The builds say 0.7.0. For the first public release, consider
`1.0.0` in pubspec. It's the number everyone sees, and every build
uploaded for that version has to carry it.

**Copyright:** `2026 Johan Carlstedt`

**Support URL:** `https://2.29.40.14.sslip.io/support` (once it exists,
see 5)

**Marketing URL:** leave empty.

**Build:** the latest TestFlight build that has passed your own testing.

**Release:** **Manually release this version.** Then turn on **phased
release**, which reaches users over seven days and can be paused.

### Promotional text (170 characters, editable without review)

sv:
> Kalender, inköpslista, läxor och chatt för hela familjen — krypterat
> från telefon till telefon. Ingen på något företag kan läsa er vardag.

en-GB:
> Calendar, shopping list, homework and chat for the whole family —
> encrypted from phone to phone. Nobody at any company can read your day.

### Description (sv)

```
Family Planner samlar familjens vardag på ett ställe: kalendern, matsedeln, inköpslistan, läxorna, att göra-listan och chatten. Allt krypteras på telefonen innan det lämnar den. Servern lagrar och skickar vidare, men kan inte läsa något ni skriver.

DAGEN OCH VECKAN
• Idag: vad som händer, för vem, vem som kör och vad som ska med
• Veckan för alla bredvid varandra, med veckonummer
• Påminnelser som kan planen: dags att åka, dags att göra sig klar, en sammanfattning på morgonen
• Lagets schema från laget.se eller annan kalenderlänk, och telefonens egna kalendrar om ni vill

MAT OCH INKÖP
• Veckans matsedel, recept från ICA, Arla och de flesta receptsajter
• Inköpslista per avdelning, från matsedeln eller inskriven, avbockad i butiken på vilken telefon som helst
• Sakerlista för skor, kläder, skolsaker och fotbollsgrejer, med storlek, vem det är till och när det behövs
• Prata in det du ska köpa: "mjölk, ägg och bröd" blir tre varor

ATT GÖRA
• Sysslor som turas om, läxor med veckans glosor, och lärarens veckobrev inläst
• "Kan jag…?": barnet frågar, en förälder svarar

FAMILJEN
• Familjechatt, direktmeddelanden och grupper
• Familjekarta med bara senaste position, aldrig en historik, och var och en väljer vad som delas
• Födelsedagar, namnsdagar och önskelistor där den som önskar aldrig ser vem som köper
• Sparade lösenord för wifi, streamingkonton och lånekort, låsta bakom Face ID
• Två hem: ett eget konto för den andra föräldern och ett vårdnadsschema

INTEGRITET
Allt krypteras från början till slut. Ingen reklam, ingen analys och ingen spårning. Barn har inga egna konton: en förälder lägger till dem och parar ihop deras enhet. Ni kan exportera eller radera allt om en person när ni vill.
```

### Description (en-GB)

```
Family Planner keeps your family's day in one place: the calendar, the menu, the shopping list, homework, to-dos and chat. Everything is encrypted on the phone before it leaves it. The server stores and relays, but cannot read a word you write.

THE DAY AND THE WEEK
• Today: what's on, for whom, who drives and what to bring
• Everyone's week side by side
• Reminders that know the plan: time to leave, time to get ready, a morning summary
• A team's schedule from any calendar link, and your phone's own calendars if you want them

FOOD AND SHOPPING
• The week's menu and the recipes you keep
• A shopping list by aisle, from the menu or typed in, ticked off in the shop on any phone
• A things list for shoes, clothes, school things and kit, with size, who it's for and when it's needed
• Say what to buy: "milk, eggs and bread" becomes three items

GETTING THINGS DONE
• Chores that take turns, homework that comes back every week, the teacher's week letter read in
• "Can I…?": a child asks, a parent answers

THE FAMILY
• A family thread, direct messages and groups
• A family map with the latest position only, never a trail, and everyone choosing what they share
• Birthdays and wishlists whose claims the person they're for can never see
• Saved passwords for the wifi, streaming and library card, behind Face ID
• Two homes: a co-parent's own account and a custody schedule

PRIVACY
End-to-end encrypted throughout. No ads, no analytics, no tracking. Children have no accounts of their own: a parent adds them and pairs their device. Export or erase one person's data whenever you want.
```

### Keywords (100 bytes, comma-separated, no spaces after commas)

Don't repeat words already in the name ("Family", "Planner"): Apple
counts the name already.

- sv: `kalender,familj,inköpslista,matsedel,läxor,chatt,att göra,barn,schema,vårdnad,veckoplanering`
  (96 bytes; å, ä and ö count as two)
- en-GB: `calendar,shopping list,meal plan,homework,chores,chat,kids,schedule,co-parent,location,to do`

---

## App Review Information

**Sign-in required: No.** There are no accounts, usernames or passwords.
Leave the demo account fields empty.

**Contact:** your name, phone and email. Apple calls this number if
review gets stuck, so give one you answer.

**Notes** (English; paste and adjust):

```
Family Planner is a private organiser for one household. There is no sign-up, email or password: on first launch, tap "Create family", enter a family name and your own name, and you are in as that family's parent with the full app. Everything is stored end-to-end encrypted; our server cannot read any content.

Children never create accounts. A parent adds a child under More → Members and pairs the child's device by showing a QR code from a device already in the family (More → Add a device). So joining as a second person requires a second device; everything else can be tested from one.

Two features worth explaining up front:
- Messaging (Chat tab) is only between members of the same family, who can only join in person via that QR code. There is no discovery, no public content, and no way to contact anyone outside the family.
- Location sharing (More → Family map) is off until a person turns it on, shares the latest position only (no history), with people they choose, at the precision they choose. Background sharing is a separate, explicit choice and shows a visible indicator.

The microphone is used only for dictation into text fields (iOS speech recognition, on-device where available); nothing is recorded or uploaded by us. The camera is used to scan the pairing QR code and to attach photos, which are encrypted on the phone.
```

**Attachment:** a 30–60 second screen recording of pairing a second
device and turning on location sharing. Reviewers rarely have two
devices, and this answers both of their likely questions before they're
asked.

---

## Submit

1. Add the build, check the screenshots on both sizes, save.
2. **Add for Review** → **Submit to App Review**.
3. Typical review time is one to two days. A rejection comes with a
   guideline number and arrives in Resolution Center. Reply there
   rather than resubmitting blind.
4. Once approved: **Release** (manual), then watch the phased release.

## Afterwards

- The privacy policy, support and marketing URLs can be changed at any
  time without a new review. Move them to the real domain once it exists.
- Promotional text changes without review; the description and keywords
  only with a new version.
