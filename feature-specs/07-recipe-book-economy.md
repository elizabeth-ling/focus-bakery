# 07 — Recipe Book & Coin Economy

**Depends on:** 02, 03. **Blocks:** 10.

## Goal

Permanent progression: earn coins by focusing, spend them to unlock recipes you
keep forever.

## The recipe book is permanent

The recipe book is *permanent progression*, distinct from the display case
(`08`), which is today's output and resets each morning. Keep them separate in
data and UI.

## Recipe set — 5–6, not 10

Ship **5–6 excellent classic recipes**. Chocolate-chip cookie is the **only**
starter; the rest are bought with coins.

Do not pad the list. A thinner-but-perfect launch beats a padded one, and the
remaining "classic collection" recipes become free post-launch updates — good for
App Store visibility and content cadence.

Each recipe needs: name, sprite, coin price, unlock state (`02`).

**Recipe sprites come from the asset pack** (`14`) — the Kitchen, Grocery store,
and Ice Cream Shop themes between them cover cookies, cakes, breads, and
pastries. Pick the 5–6 recipes from what the pack renders well at 16×16, rather
than picking names first and then hunting for art. Each treat needs to read at
two sizes: inside the display case in-world (`08`) and in the recipe-book modal
(`10`).

## Coins

- **Minutes correlate to coins earned** from a session.
- Coins are awarded on `.completed` only. A **burned** session earns nothing —
  that is the entire weight behind the soft-commitment mechanic (`03`).
- Award exactly once per session, even when completion is resolved on foreground
  rather than live.
- The balance updates visibly at the moment of award (`06`), with sound and
  haptic (`12`).

## Balance values live in one place

Earn rates (minutes → coins) and recipe prices **will be tuned iteratively**.
Keep every one of these numbers in a single configuration location. Never
scatter them as magic numbers across timer, wallet, and recipe code.

This is a hard requirement, not a style preference — economy tuning running long
is a named schedule risk, and scattered constants are what makes it long.

## Unlocking

- Locked recipes are visible in the book with their price — visible goals are the
  point of the progression.
- Purchase requires sufficient balance; insufficient balance is communicated
  clearly rather than by a disabled control with no explanation.
- Unlocks are permanent and survive the daily reset and app relaunch.
- Purchase is a spend of earned currency, and should feel deliberate. Whether it
  needs a confirmation step is an open question.

## Acceptance criteria

- [x] A new install has exactly one unlocked recipe: chocolate-chip cookie.
- [x] Completing a session awards coins proportional to session minutes, exactly
      once. *Proportional, but no longer linear* — see the resolved curve below.
      Exactly-once is inherited from `03`: awarding runs through
      `finishActiveSession`, and of the live path and the foreground path,
      whichever arrives second finds an empty slot.
- [x] A burned session awards zero coins and no treat.
- [x] Purchasing a recipe deducts the price and unlocks it permanently.
- [x] Unlocks survive daily reset, app relaunch, and cold start with an in-flight
      session.
- [x] Every earn rate and price is defined in one file; grepping for a price
      literal finds exactly one occurrence. **With one caveat worth knowing
      about**, below.
- [x] Coin balance can never go negative.

### How they were checked

Unit tests over the injectable clock (`EconomyTests.swift`), driving purchases
through the store the app actually talks to and earning the coins by baking
rather than by poking the wallet — so the tests spend what the product does.

Two properties are asserted that no single criterion asks for, because they are
what the banded curve could plausibly get wrong: the curve is **monotonic** (no
duration earns less than a shorter one) and **continuous** (a band change raises
the per-minute rate but never pays a lump sum, so no threshold rewards stopping
just past it).

On the "exactly one occurrence" caveat: `210`, `455`, `840` and `1400` each
appear once in the tree, in `Economy.swift`. `70` matches five lines, but four
are colour channels (`0.70`, where the word boundary falls after the decimal
point) and a glyph count — no *economy* number is duplicated at a call site,
which is what the criterion is protecting. The tests were changed to ask
`Economy.coins(forCompletedMinutes:)` rather than hardcode totals, so the next
tuning pass does not have to hunt through the suite; `EconomyTests` is the one
deliberate exception, since pinning the bands is its job.

The book was exercised on the simulator against a seeded balance: locked rows
show their price, and the shortfall arithmetic is right on screen (455 − 250 =
205, 840 − 250 = 590, 1400 − 250 = 1150).

**Still owed a manual pass:** the confirmation sheets themselves — both the buy
and the "not enough coins" variant — were never driven, because this machine has
no simulator tap tooling (`idb` is absent and System Events is blocked by
accessibility permissions). The data behind them is unit-tested and the rows
they open from render correctly, but nobody has yet watched the sheet appear.

## Do not build in v1

- **Monetization is an unresolved decision** (coins-earned-only with a premium
  unlock vs. seasonal-collection IAPs). Do **not** wire either assumption into
  the coin economy. No StoreKit, no IAP scaffolding, no "premium" flag until the
  model is chosen.
- Workspace / display-case customization (the big coin sink) is v2+.
- Seasonal limited-edition collections are v2+.
- Achievements and deeper economy are v2+.

## How it is built

- `Models/Economy.swift` is the single tuning location the hard requirement
  above asks for: the earn bands and every price, and nothing else. Callers ask
  `coins(forCompletedMinutes:)` and `price(for:)`.
- `Wallet.spend` refuses to go negative and reports it, and `BakeryStore.purchase`
  only records the unlock once the spend has actually succeeded — so a short
  balance cannot half-apply a purchase. That ordering is the whole of "can never
  go negative"; there is no separate guard to keep in sync.
- `PurchaseResult` is three cases rather than a `Bool`, because "you already own
  this" and "you are 40 coins short" are different things to a user and only one
  of them can be explained. The shortfall is carried so it can be said out loud.
- `BakeryStore.recipeBook` is the read model `10` consumes: the whole catalogue,
  locked rows included, each priced against the current balance.
- Awarding is not implemented here. It hangs off `finishActiveSession` in `03`,
  which is what makes exactly-once free rather than something this spec has to
  re-establish.
- The recipe book lives in `ProgressState` and the display case in `TodayState`,
  in separate files on disk (`02`). The daily reset writes only the latter, so
  "unlocks survive the reset" is true by construction.
- No StoreKit, no IAP scaffolding, no premium flag — see the open question below.

## Open questions

- **Monetization model** — must be locked before the economy is built out, so it
  isn't bolted on awkwardly. **Still open, and deliberately so.** Nothing in the
  economy assumes an answer: there is no StoreKit import, no IAP scaffolding and
  no premium flag anywhere in the tree. The requirement this spec places on the
  decision is inaction, and that requirement is met — but the decision itself is
  the owner's and is still outstanding.
- ~~The exact minutes → coins curve: linear, or weighted toward longer
  sessions?~~ **Resolved: weighted**, as a banded per-minute rate — a coin a
  minute through minute 15, two through 45, three after.
  - A flat rate makes five five-minute bakes pay exactly what one
    twenty-five-minute bake does. For a product whose whole premise is depth,
    being indifferent between those is the wrong signal.
  - Each band applies only to the minutes falling *inside* it, so the curve is
    continuous. Banding the **total** instead would put a cliff at each
    threshold and reward stopping just past one — the opposite of the intent.
  - Legibility is the cost, and `10` carries it: "25 minutes, 25 coins" explains
    itself and "25 minutes, 35 coins" does not. The modal should show the payout
    for the duration currently selected rather than expect the user to infer the
    bands.
- ~~Recipe prices and their pacing — how many sessions should the second recipe
  take?~~ **Resolved: two to three.** The first unlock has to land while the
  user is still deciding whether the loop is worth keeping, so the croissant is
  70 — two twenty-five-minute bakes. From there the gaps widen to a cake that is
  a long-haul goal rather than a purchase. All provisional, and all in one file
  precisely because they will move.
- ~~Whether purchases need a confirmation step.~~ **Resolved: yes.** It matches
  the confirmation already in front of cancelling a bake, and a spend of
  currency earned by sitting still for an hour should not be reachable by a
  mis-tap. The unaffordable case opens the *same* sheet with the shortfall spelt
  out and no buy button, rather than presenting a dead control — which is the
  spec's "communicated clearly" requirement.
- ~~The specific 5–6 recipes, chosen against what the pack provides (`14`).~~
  **Resolved: six**, and settled by the atlas rather than by this spec — cookie,
  croissant, sourdough loaf, chocolate donut, fruit tart, celebration cake are
  what `Resources/Treats.atlas` already slices, each legible at 16×16.
