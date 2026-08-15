# The UI chrome

Authored pixel art for the recipe-book modal (`10`). The Modern Interiors pack
ships no panels, frames or buttons — `4_User_Interface_Elements/` is emotes and
speech bubbles — so this is one of the three art gaps `14` names, drawn here
rather than sourced.

```sh
python3 tools/ui/build_ui.py                 # write Resources/UI.atlas/
python3 tools/ui/build_ui.py --preview /tmp/ui.png
```

Requires Pillow only. The script is deterministic and does **not** read the
pack: every colour was sampled once from `Palettes/palette_interiors.png` (as
`14` requires, so the chrome reads as the same app) and lives in the script as
RGB values. Colours are not pixels, so the output is original art —
`Resources/UI.atlas/` is committed, unlike the pack-derived atlases, and the
app builds without Python or the pack for anyone who only wants to run it.

| Asset | Size (art px) | Used for |
|---|---|---|
| `book_page` | 160×240 | The modal itself: leather cover, brass corners, stitched page, ribbon |
| `arrow_left` / `arrow_right` | 16×16 | Recipe paging beside the treat |
| `stepper_minus` / `stepper_plus` | 16×16 | Duration stepper |
| `button_close` | 16×16 | Dismiss |
| `button_start` | 112×24 | The start action's plate; its label is TTF text over it |

The page is a **fixed-size** image, not a 9-slice: at chrome scale ×2 it is
320×480 pt, which fits every supported iPhone with margin, and a fixed canvas
lets the stitching, ribbon and corner caps sit exactly where they were drawn —
stretching a 9-slice would smear them. The small controls share one plate
(aged paper, ink outline) so they read as a family.
