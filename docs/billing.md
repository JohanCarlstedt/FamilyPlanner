# Selling premium

What is built, and the accounts only you can create. Nothing in this file
is code that needs writing; it is the configuration the code is waiting
for. The plan behind it, and what premium covers, is in
`docs/going-public.md`.

## What already works

- `Subscription`, one row per family, with a random `BillingId` that is
  the only thing the billing provider ever learns about them.
- `GET /v1/entitlement` — a device asks what its family has.
- `POST /v1/billing/events` — the provider tells the server, behind a
  shared secret. Unset secret means 503, never "allow".
- `Entitlement` and `PaidFeature` in the domain package: the list of what
  premium covers, and the rule for how long a cached answer is trusted.
- **More → Premium**: the paywall, restore, manage, the renewal terms and
  the two links the stores require.
- A build with no key: everything above works, the paywall says buying is
  unavailable, and nothing crashes. **That is the state today.**

**No feature is gated yet.** The whole app behaves as it always has, for
everyone. Gating comes last, deliberately, because it is the first change
that can take something away from someone.

## The names, which must match in three places

| | |
|---|---|
| Entitlement | `premium` |
| Offering | `default` |
| Products | `premium.monthly`, `premium.yearly` |

RevenueCat's entitlement id is hard-coded as `premium` in
`lib/src/billing/purchases.dart`. The product ids are yours to choose,
but they must be identical in App Store Connect and Play Console or the
same purchase looks like two products.

## 1. The stores, first

Neither RevenueCat nor this app can create products; they can only sell
ones that already exist.

**App Store Connect** → your app → Subscriptions. Make one *subscription
group* — that matters, because the group is what lets someone move
between monthly and yearly without buying twice. Inside it:

- `premium.monthly`, 1 month, 49 SEK.
- `premium.yearly`, 1 year, 399 SEK.
- An **introductory offer** of 14 days free on both, "first-time
  subscribers only". This is where the free trial lives; the app does not
  implement one.
- A localised display name and description for each, in Swedish and
  English. These are what the paywall shows — the app deliberately prints
  the store's own strings and price, never one it worked out itself.

**Play Console** → Monetise → Subscriptions. Same two ids, each with a
base plan (monthly / yearly, auto-renewing) and a **free trial offer** of
14 days. Prices per country; Sweden is the only one that matters at
first.

## 2. RevenueCat

<https://app.revenuecat.com>, free below roughly $2.5k monthly revenue.

1. A **project**, then an **app** for each platform.
2. **Apple** needs an In-App Purchase key (App Store Connect → Users and
   Access → Integrations → In-App Purchase) and your app's bundle id.
   **Google** needs a service-account JSON with Play Developer API access,
   granted in both Google Cloud and Play Console. Play takes up to 36
   hours to honour new permissions; start this before you need it.
3. **Entitlement** `premium`, with both products attached.
4. **Offering** `default`, with a monthly and a yearly package pointing at
   them. The paywall shows `current` offering's packages in order, so the
   order there is the order a person sees.
5. **Public SDK keys**, one per platform, under API keys. These ship
   inside the app and are meant to: a public key can buy and read for one
   app and nothing else. The *secret* keys never leave the dashboard.

## 3. The webhook

RevenueCat → Integrations → Webhooks.

- URL: `https://<your-domain>/v1/billing/events`
- Authorization header: the value of `BILLING_WEBHOOK_TOKEN` in the
  server's `.env` (`openssl rand -base64 32`).

Without the header the server answers 401; without the token configured
at all it answers 503 to everything, which is the safe way round. Send a
test event from the dashboard and watch for `Billing … applied` in
`docker compose logs api`.

## 4. Building with the keys

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://<your-domain> \
  --dart-define=REVENUECAT_APPLE_KEY=appl_xxx
```

```bash
flutter build appbundle --release --flavor prod \
  --dart-define=API_BASE_URL=https://<your-domain> \
  --dart-define=REVENUECAT_GOOGLE_KEY=goog_xxx
```

A build without them is not broken; it simply cannot sell anything, which
is right for a development build and for a self-hosted family.

## Giving a family premium

The honest answer to "can I give this to a friend for free" is yes, three
ways, and the first is the one to use:

1. **RevenueCat → Customers → the billing id → grant a promotional
   entitlement.** Any duration, or lifetime. No store, no money, no cut.
   It arrives over the same webhook as a purchase, so nothing special
   happens on our side.
2. **Offer codes** (Apple) and **promo codes** (Play): "three months
   free", handed out and redeemed in the store.
3. **Promotional offers** (Apple): a discounted rate aimed at one lapsed
   subscriber, signed by your server.

**Their billing id is on the paywall**, at the bottom, selectable — so
"read me the account line under Premium" is the whole support script. It
is also the `BillingId` column of `Subscriptions`.

What you **cannot** do is charge one family a different price. Both
stores sell at fixed price points per storefront. Free time and
introductory discounts, yes; a private price, no.

## Testing it without spending money

- **Apple**: App Store Connect → Users and Access → Sandbox → a test
  account. Sign out of the real account on the device *in Settings → App
  Store*, not in the app. Sandbox subscriptions renew every few minutes,
  so a year passes in an hour — which is the only practical way to watch
  a renewal, a lapse and a restore.
- **Google**: Play Console → Licence testing, with accounts that are also
  testers on the track. Purchases are not charged and renew quickly.
- **Both**: watch the server. `Billing RENEWAL … applied` in the API log
  is the proof that the loop closes; the paywall going green only proves
  the phone believes it.

The cases worth walking through, because each has its own way of being
wrong: a purchase, a renewal, a cancellation (**premium must survive to
the end of the paid period**), a refund, an expiry, and a restore on a
second device.
