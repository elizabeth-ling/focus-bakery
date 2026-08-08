yet another pomodoro timer & app blocker...

built because I'm unhappy with the forest app and because I like art and making cute things

## Art assets

In-world art comes from **[Modern Interiors](https://limezu.itch.io/moderninteriors)**
by **LimeZu** (full version). The pack is licensed and **not included in this
repo** — its licence prohibits redistributing the asset, edited or not.

To build, buy your own copy and unpack the full version to `assets/`, so that
`assets/1_Interiors/`, `assets/2_Characters/`, etc. sit at that level. Then:

```sh
python3 tools/atlas/build_atlases.py
```

That slices the sprites the app actually uses into `Resources/*.atlas`. Both
`assets/` and the generated atlases are gitignored and must stay that way. See
[`tools/atlas/README.md`](tools/atlas/README.md) for the pipeline and
[`feature-specs/14-art-asset-pipeline.md`](feature-specs/14-art-asset-pipeline.md)
for the constraints.

**Attribution to `limezu.itch.io` is required by the licence**, and ships in the
app's settings footer and in App Store metadata. It is not optional.
