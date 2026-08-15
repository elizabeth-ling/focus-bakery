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

- [ ] A new install has exactly one unlocked recipe: chocolate-chip cookie.
- [ ] Completing a session awards coins proportional to session minutes, exactly
      once.
- [ ] A burned session awards zero coins and no treat.
- [ ] Purchasing a recipe deducts the price and unlocks it permanently.
- [ ] Unlocks survive daily reset, app relaunch, and cold start with an in-flight
      session.
- [ ] Every earn rate and price is defined in one file; grepping for a price
      literal finds exactly one occurrence.
- [ ] Coin balance can never go negative.

## Do not build in v1

- **Monetization is an unresolved decision** (coins-earned-only with a premium
  unlock vs. seasonal-collection IAPs). Do **not** wire either assumption into
  the coin economy. No StoreKit, no IAP scaffolding, no "premium" flag until the
  model is chosen.
- Workspace / display-case customization (the big coin sink) is v2+.
- Seasonal limited-edition collections are v2+.
- Achievements and deeper economy are v2+.

## Open questions

- **Monetization model** — must be locked before the economy is built out, so it
  isn't bolted on awkwardly.
- The exact minutes → coins curve: linear, or weighted toward longer sessions?
- Recipe prices and their pacing — how many sessions should the second recipe
  take?
- Whether purchases need a confirmation step.
- The specific 5–6 recipes, chosen against what the pack provides (`14`).
