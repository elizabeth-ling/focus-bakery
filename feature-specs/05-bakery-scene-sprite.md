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
  digits, ♦ quantities, "baking…" tag. Never `SKLabelNode` for these. (The coin
  count was in here too until `06` moved the balance to chrome, where it can sit
  inside the safe area and be read aloud.)
- Ambient animated fixtures are available in the pack and cheap to add, but each
  one is a moving thing competing for attention during a focus session. Add
  deliberately, not because they're free.
- Parallax backgrounds were floated during early planning. They do not apply to a
  top-down fixed room — disregard.

## Rendering requirements

Inherits every rule from `01`, restated because this is where they break:

- 16×16 tiles, integer scale, room dimensions flexing per device.
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

- [x] The scene reflects session state within one frame of the state changing,
      driven only by input from the app layer. `apply(_:)` is synchronous and
      the host calls it on every session edge, not only on the display tick.
- [x] No timer arithmetic, persistence call, or notification scheduling exists
      inside the `SKScene`. Verifiable by inspection: `BakeryScene` receives a
      seconds count and formats it; it imports nothing but SpriteKit.
- [x] Every state in the table is reachable, and any state can be entered
      directly from any other without stranding the baker mid-walk. Asserted
      headlessly for every ordered pair of phases, and by the route tests,
      which include a walk cut off in the counter corridor.
- [x] The oven animates for exactly the duration of a session, and stops on
      completion, burn, and cancel — it runs iff the phase is `.baking`, and
      completion, burn and cancel all leave that phase. Unit-tested, and
      confirmed on the simulator by frame-diffing screenshots. (Diff against
      the *right* frames: the strip ping-pongs, `oven_01` == `oven_03`, so two
      samples half a loop apart can compare equal while animating.)
- [x] Completing a session plays the deliver walk and the treat lands in the case
      at the end of it. The store records the treat at completion (02); the
      scene withholds the last one until the place step, which is asserted, and
      the walk itself was watched on the simulator with a seeded bake.
- [x] A burned session plays neither deliver nor celebrate, and adds nothing.
      Burn and cancel reach the scene as `.idle` — only a completion the user
      watched becomes `.delivering`, so there is no path from a burn to the
      payoff choreography.
- [ ] The baker sorts correctly against fixtures from every approach direction.
      Sorting is one rule — `zPosition` from base y, baker re-sorted each
      frame — and the front-of-counter and front-of-oven cases were verified by
      screenshot, but a full walk around every fixture still owes a device pass.
- [x] Timer digits render as bitmap text, crisp, through the spec-01 pipeline.
      The digits are magnified ×2 over the room scale (as `01`'s proof surface
      was) — an integer multiple, so pixels stay uniform within the text; `06`
      owns whether the final chrome keeps that size.
- [x] The room lays out correctly on the smallest and largest supported devices
      with no fractional scaling. The plan's anchors and routes are asserted
      for every supported size, and the SE and 16 Pro Max rooms were shot with
      `06`'s shell: both zones on screen, margin at the room edges, ×2
      everywhere.
- [ ] Reduced-motion is honored (`13`) without breaking state transitions —
      including the deliver walk, which repositions instead of walking and
      still delivers the treat. The state machine under reduce-motion is
      unit-tested; how the calm path *feels* is owed to `13`'s device pass.

## How it is built

- `RoomPlan` (`Rendering/RoomPlan.swift`) is the layout half: every fixture and
  walk anchor derived from the room's tile dimensions — oven hung on the back
  wall, counter line at half height with a corridor gap, door and rest in front
  of house. Routes are authored and axis-aligned, computable from *any* tile,
  because an interrupted walk resumes from wherever it was cut. The route tests
  caught the café seating sitting in a walk lane, which is why the seats stand
  against the left wall — the one strip no route crosses.
- `BakeryScene` (`App/BakeryScene.swift`) renders one `Model` value and emits
  events. `BakerDirector` is the state machine made explicit: app phase →
  target activity as a pure function, with `nil` meaning "already serving it".
  Every activity enters through a single `enter(_:)` that first removes all
  actions and snaps the baker to the grid — cancellation is the default, and a
  removed action never fires its completion, so superseded choreography cannot
  come back to life. The scene phases are `.idle`, `.baking(seconds)` and
  `.delivering(recipe)`: burn and cancel are just `.idle`, and only the host
  view decides a completion earned `.delivering` — one that resolved while the
  app was away arrives as `.idle` with the treat already in `treats`, which is
  how the walk is never replayed out of context.
- Rebuilds (size change, first presentation) *settle* into the state the model
  implies instead of replaying transitions. SpriteView hands the scene
  transient sizes (a 1×1 probe among them) while SwiftUI lays out, so the
  scene also re-checks its layout on each rendered frame and rebuilds if the
  size moved under it.
- `MainScreenView` (`App/MainScreenView.swift`) is the app-layer half of the
  boundary: it derives the model from the store each second and on each session
  edge, and translates scene events back into `acknowledgeOutcome` and
  notification cleanup. SpriteView's `isPaused:` parameter kept the scene from
  ever being presented, so backgrounding relies on SKView's automatic pause
  instead. It was `BakeryRoomView` behind a `-bakeryRoom` flag until `06` made
  the room the app's root; the coin count it drew in bitmap text moved to
  chrome at the same time, and the countdown moved a tile down the room to keep
  the two text tiers apart.
- Placeholder-first, still partly placeholder: baker, oven, display case and
  treats are pack art (the atlases already existed); floor, walls, prep
  counter and seating are colored blocks, and every pack sprite has a block
  fallback so a checkout without `assets/` still shows the full choreography.
  Choosing the real floor/wall/fixture sprites is the `14` layout task `06`
  picks up.

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

- ~~Room tile dimensions per device class (shared with `01`).~~ **Resolved by
  `01`'s `RoomLayout`**; the plan flexes over whatever it resolves.
- ~~Exact anchor positions and walk routes.~~ **Resolved: `RoomPlan`**, derived
  from anchors per device, with authored corridor-crossing routes.
- ~~Whether the idle baker drifts between anchors or holds one resting spot.~~
  **Resolved for v1: one resting spot.** Drifting is an ambient nicety, and the
  spec's own priority order says cut ambient before choreography — revisit only
  once the real art is in and the room feels static.
- ~~Whether a burned session gets any visual acknowledgment beyond returning to
  idle, or stays deliberately quiet.~~ **Resolved: quiet in-scene.** The baker
  walks home and the oven stops; the app layer breaks the bad news in chrome.
  Nothing in the room celebrates or scolds.
- Whether the ambient bakery hum (`12`) is driven from the scene or the app
  layer — prefer the app layer, since audio outlives individual scene instances.
