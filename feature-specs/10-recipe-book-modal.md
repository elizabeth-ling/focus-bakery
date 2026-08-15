# 10 — Recipe-Book Timer Modal

**Depends on:** 01, 07, 14. **Blocks:** nothing.

The entry point to every session, and one of the two places the craft bar is most
visible.

> **This screen is now the largest remaining art task in the project.** The asset
> pack covers the bakery world but contains **no UI panels, frames, or buttons** —
> `4_User_Interface_Elements/` is emotes and speech bubbles (`14`). The recipe
> book's cover, page, arrows, and stepper controls must all be authored, in the
> pack's palette so they read as the same app. Budget for it: with world art
> solved, this and the font (`01`) are what's left.

## Goal

Tapping "+" opens a modal **styled as an old grandma's recipe book**, where you
pick a recipe and set a duration, then start baking.

## Layout

- Presented from the "+" button on the main screen (`06`).
- **Left / right arrows beside the baked-good image** to choose a recipe.
- **Below it, a duration number with "−" and "+" buttons.**
- A clear start action that dismisses the modal and returns to the main screen
  with the sprite now working (`05`).

The recipe-book styling is the point — this is not a generic picker sheet with a
skin. The arrows-around-an-image pattern is deliberate and should feel like
turning pages.

The baked-good images themselves are pack treat sprites (`07`, `14`), shown at an
integer scale like everything else (`01`). A 16×16 treat is very small for a hero
image — scale it up by a whole factor rather than reaching for a different
resolution from the pack. Expect to need a larger multiple here than the room's
×2; ×6 or ×8 is still uniform pixels.

## Recipe selection

- Cycles through the user's **unlocked** recipes (`07`).
- Locked recipes: whether they appear here (greyed, with price) or only in the
  recipe book proper is an open question. Defaulting to unlocked-only keeps the
  start-a-session flow uncluttered.
- With only chocolate-chip cookie unlocked (fresh install), the arrows must
  degrade gracefully rather than appearing broken — see `11`.

## Duration

- "−" / "+" step the duration by a fixed increment.
- Constrain min and max **here**, at the input layer. The timer (`03`) should
  never receive an absurd duration.
- Duration drives coins earned (`07`), so the relationship should be legible to
  the user, at least implicitly.
- Remembering the last-used duration is likely the right default. Not decided.

## Text

- Duration digits are grid-critical. If they sit inside the pixel-art frame, they
  use the **bitmap font** (`01`). If the modal is SwiftUI chrome, the pixel TTF
  tier applies.
- Do **not** mix the two tiers within the modal. Pick one and keep it consistent,
  because a bitmap duration next to a TTF label is exactly the jarring mismatch
  `01` forbids.

## Acceptance criteria

- [ ] "+" opens the modal; the modal can be dismissed without starting a session.
- [ ] Arrows cycle only through unlocked recipes.
- [ ] With one unlocked recipe, the control reads as intentional, not broken.
- [ ] Duration cannot be set below the minimum or above the maximum.
- [ ] Starting creates exactly one `.inProgress` session with the chosen recipe
      and duration, schedules the completion notification (`04`), and returns to
      the main screen with the sprite working.
- [ ] The modal cannot be opened while a session is in progress (`06`).
- [ ] Text within the modal uses a single text tier.

## Open questions

- Duration min, max, and step increment.
- Whether the last-used duration and recipe are remembered.
- Whether locked recipes are visible here with their prices, or only in the
  recipe book.
- Whether recipes have suggested/native durations, which would tie the two
  controls together.
