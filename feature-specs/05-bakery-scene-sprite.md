# 05 — Bakery Scene & Baker Sprite

**Depends on:** 01, 03, 14. **Blocks:** 06, 08.

The companion feeling lives here. You're working next to your digital clone who
is also working hard at their bakery.

## Goal

A SpriteKit scene, embedded in SwiftUI via `SpriteView`, rendering the bakery as
a **single top-down room** whose baker and fixtures visibly react to session
state.

## The room is top-down and full-screen

The asset pack is top-down (`14`), so the scene is no longer a side-on workbench
panel occupying the top half of the screen. It is one continuous room filling the
screen, read from above, divided into two zones:

| Zone | Contents | Role |
|---|---|---|
| **Back of house** (upper) | Oven, prep counter, the baker's station | Where work happens. The baker spends session time here. |
| **Front of house** (lower) | Glass display cases, café seating, door | Where output accumulates. The case fills as you bake (`08`). |

The zones are one continuous space, not two panels — the divider is a counter
line or floor change within the room, not a UI boundary. The baker can walk
between them, and that walk is the point.

`6_Home_Designs/Ice-Cream_Shop_Designs/` is the layout reference (`14`).

### Anchor-relative layout

Room tile dimensions vary by device (`01`). Place fixtures relative to anchors —
back wall, case row, door — never at absolute tile coordinates. A layout that
hardcodes "oven at (3, 2)" breaks on the next screen size.

## Boundary — keep it strict

- **SpriteKit owns:** sprite states, texture atlases, in-scene bitmap-font
  rendering, fixture animation, per-frame scene updates.
- **SpriteKit does not own:** the timer, persistence, notifications, navigation.
- **Data flows one way: app state → scene.** The scene renders state; it does not
  own it. Do not scatter timer or persistence logic inside `SKScene`.

Violating this is the single most likely way this codebase gets messy, because
`SKScene` makes it easy to stash mutable state.

Taps inside the scene (the display case, `08`) travel **up** to the app layer as
events. The scene does not present sheets or mutate model state itself.

## The baker has no baking animation — the room animates

The character sheets contain no mixing, kneading, or cooking animation (`14`).
The available vocabulary is: **idle, walk, pick up, lift, throw, sit, phone,
read, push cart** — plus an unusable combat set.

So the work reads through **choreography and fixtures**, not through one looping
character animation:

- The **oven** (`animated_grocery_store_bakery_industrial_oven_*`) runs its frame
  loop for the duration of a session. This is the primary "something is baking"
  signal, and it's visible from across the room.
- The **baker** plays a short station loop assembled from `pick up` / `lift`,
  facing the counter.
- **Movement between stations** carries the state transitions.

This is better than a single mixing loop would have been: the room feels alive
rather than one sprite twitching in place. Do not author a custom mixing
animation for v1 (`14`).

## Sprite state machine

Driven entirely by session state from the app layer. No player input, no
pathfinding — the baker moves along fixed, authored routes between known anchors.

| State | When | Behavior |
|---|---|---|
| **Idle** | No session running | Idle loop at a resting anchor. May drift between anchors on a slow timer; must never look like it's working. |
| **Walk to station** | Session just started | Walks from wherever it is to the oven/prep anchor. Short — this is a transition, not a cutscene. |
| **Working** | Session `.inProgress` | Station loop at the oven; **oven fixture animates**. The state the user watches for a long time, so it must bear repetition. |
| **Deliver** | Session just completed | `pick up` at the oven → walk to the display case → place the treat. The treat appears in the case at the end of this walk (`08`). |
| **Celebrate** | End of deliver | Short beat, then back to idle. The payoff moment (`06`, `12`). |
| **Burned** | Session `.burned` | Returns to idle **without** the deliver walk and **without** celebrate. Nothing enters the case. |

The deliver walk is the completion payoff — the treat is physically carried from
oven to case. Do not shortcut it into the treat popping into existence.

### Transitions must be interruptible

Every one of these states can be cut short by app state changing underneath it —
the user cancels mid-walk, or foregrounds the app after the session already
completed and burned. **Any state must be enterable from any other state
directly**, without waiting for an in-flight animation to finish. Model this
explicitly; a chain of completion handlers will strand the baker mid-room.

Notably: returning from background after `endDate` should resolve to a completed
case, not replay the deliver walk from the beginning at the wrong moment (`06`).

## Scene contents

- The room: floor, walls, oven, prep counter, display cases, seating (`14`).
- The baker sprite, pre-composited to a single atlas (`14`).
- **In-scene bitmap text** rendered through the sprite pipeline (`01`): timer
  digits, coin count, "baking…" tag. Never `SKLabelNode` for these.
- Ambient animated fixtures are available in the pack and cheap to add, but each
  one is a moving thing competing for attention during a focus session. Add
  deliberately, not because they're free.
- Parallax backgrounds were floated during early planning. They do not apply to a
  top-down fixed room — disregard.

## Rendering requirements

Inherits every rule from `01`, restated because this is where they break:

- 32×32 tiles, integer scale, room dimensions flexing per device.
- `filteringMode = .nearest` on every texture at load.
- Sprite positions snapped to whole grid units.
- Walk animation in whole grid units — no sub-pixel tweens, which shimmer. This
  now matters far more than it did: the baker walks across the room regularly,
  so sub-pixel motion would be visible constantly rather than never.
- Animated fixtures honor their encoded loop ranges (`14`).

## Depth sorting

Top-down rooms need the baker to pass **behind** the counter's back edge and **in
front of** its near edge. Resolve draw order by the sprite's Y position within
the room, via `zPosition`. Getting this wrong is the most obvious "this is
broken" artifact in a top-down scene, and it will not show up until the baker
first walks past a fixture.

## Placeholder-first — now cheaper, still worth it

Build the scene with **placeholder colored blocks** and validate the loop before
wiring real art. With the pack in hand this phase is short — the art already
exists — but the state machine, the walk choreography, and the transition feel
should still be settled on blocks. Debugging interruptible states is easier
without art in the way.

## Acceptance criteria

- [ ] The scene reflects session state within one frame of the state changing,
      driven only by input from the app layer.
- [ ] No timer arithmetic, persistence call, or notification scheduling exists
      inside the `SKScene`.
- [ ] Every state in the table is reachable, and any state can be entered
      directly from any other without stranding the baker mid-walk.
- [ ] The oven animates for exactly the duration of a session, and stops on
      completion, burn, and cancel.
- [ ] Completing a session plays the deliver walk and the treat lands in the case
      at the end of it.
- [ ] A burned session plays neither deliver nor celebrate, and adds nothing.
- [ ] The baker sorts correctly against fixtures from every approach direction.
- [ ] Timer digits render as bitmap text, crisp, matching the art's pixel size.
- [ ] The room lays out correctly on the smallest and largest supported devices
      with no fractional scaling.
- [ ] Reduced-motion is honored (`13`) without breaking state transitions —
      including the deliver walk, which must have a calmer path that still
      delivers the treat.

## Gotchas

- **Text tier bleed:** watch for an `SKLabelNode` or a SwiftUI `Text` landing
  next to bitmap numbers.
- Scene lifecycle across `scenePhase` changes: the scene should not keep running
  animation work while backgrounded, and must resume correctly without
  re-deriving timer state itself.
- Do not let the scene become the place where "just one more bit of state" lives.
- The walk is the piece most likely to be cut when the schedule tightens. It is
  also the piece that makes the room feel inhabited rather than decorated. Cut
  ambient fixtures first.

## Open questions

- Room tile dimensions per device class (shared with `01`).
- Exact anchor positions and walk routes.
- Whether the idle baker drifts between anchors or holds one resting spot.
- Whether a burned session gets any visual acknowledgment beyond returning to
  idle, or stays deliberately quiet.
- Whether the ambient bakery hum (`12`) is driven from the scene or the app
  layer — prefer the app layer, since audio outlives individual scene instances.
