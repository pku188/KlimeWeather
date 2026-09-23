# Icon pipeline

Reproducible steps to (re)generate the widget's bundled icons.
**No build step ships with the plasmoid** — these are one-off authoring tools.

## Condition icons — the Meteocons packs (`contents/icons/meteocons/`)

The four icon packs (fill, flat, line, monochrome) come straight from the
published npm packages, animated and static:

```fish
npm pack @meteocons/svg @meteocons/svg-static     # svg-0.1.0.tgz, svg-static-0.1.0.tgz
mkdir anim static
tar xzf svg-0.1.0.tgz -C anim; tar xzf svg-static-0.1.0.tgz -C static
python3 meteocons_packs.py anim/package static/package ../../contents/icons/meteocons
```

`meteocons_packs.py` holds the stem map (widget `wi-*` stem → Meteocons icon) and
rewrites two things Qt draws differently from a browser: alpha masks become
luminance masks (Qt ignores `mask-type`, so suns, moons and back clouds vanished),
and the animations are rewritten into the SMIL and CSS subset `VectorImage` plays
correctly (it drops opacity animations and ignores easing, key times and begin
offsets). See `contents/icons/meteocons/ATTRIBUTION.md`.

- **Static** icons are drawn by QtSvg (`Kirigami.Icon`), which handles luminance
  masks since Qt 6.7.
- **Animated** icons are drawn by Qt Quick's `VectorImage` (SMIL animations need
  Qt 6.10). It draws masks with a shader, so **verify them on the GPU**: the
  offscreen platform uses the software scene graph, where masked parts are simply
  missing. A headless nested KWin gives a real GPU without opening a window:
  ```fish
  kwin_wayland --virtual --socket wl-test --no-lockscreen \
      --exit-with-session "env QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=wl-test qml6 probe.qml"
  ```

## Panel white set and sun-event glyphs (older pipeline, still shipped)

`contents/icons/basmilius-white/` (the panel's white icons) and
`contents/icons/sun-events/` (the graph's sunrise/sunset markers) were made from
Meteocons v3.0.0-next.10 with the steps below, when QtSvg could not draw masks at
all. The WebP heroes these steps also produced (`bake_v3.sh`, `render_frames.py`,
`pad_lottie.py`, `animate_fog.py`) are retired: the Meteocons packs animate their
SVGs directly. The scripts stay for reference.

## Why each step exists
- **The widget renders static SVGs through QtSvg** (`Kirigami.Icon`), which
  **ignores `<mask>`**. Meteocons hides the sun/moon/back-cloud behind the front
  cloud with masks, so a raw copy renders with **suns/moons missing** and fog as
  bare lines. `strip_masks.py` removes the masks (the opaque cloud on top already
  occludes what the mask hid → same picture, QtSvg-safe).
- **`AnimatedImage` can't play Lottie/SMIL** → animations are baked to GIF.
- The panel/tray uses a **white silhouette** → `flatten_white.py`.

## Prerequisites
```fish
python3 -m venv /tmp/v3venv
/tmp/v3venv/bin/pip install lottie==0.7.1 cairosvg setuptools pillow
# system: imagemagick (magick), librsvg (rsvg-convert), and PyQt6 for verification
```
⚠️ **Version pins matter — the recipe is fragile across lottie releases + new Python:**
- **`lottie==0.7.1`** — the two pipeline scripts need APIs from *different* eras:
  `render_frames.py` imports `lottie.exporters.cairo.export_png` (**removed in 0.7.2**)
  and `pad_lottie.py` calls `anim.to_precomp()` (**absent in ≤0.6.x**). 0.7.1 is the
  only version with both. If a frame render emits 0 frames or `pad_lottie` throws
  `AttributeError: to_precomp`, you're on the wrong version.
- **`cairosvg`** is what actually rasterizes — python-lottie's PNG path is gated on
  `lottie.exporters.cairo.has_cairo`, which is **only true when `cairosvg` imports**.
  `pycairo` alone does **not** satisfy it (`export_png` won't even import).
- **`setuptools`** — Python 3.12+ removed `distutils`, which older `lottie` imports
  (`ModuleNotFoundError: No module named 'distutils'`); setuptools restores it.

### Adjusting raindrop / streak length (sleet, rain)
Each precip streak is a 2-vertex vertical line in the Lottie (`"v": [[x,88],[x,91]]`
= length 3) and in the static SVG (`d="M52 88v3"`). To lengthen, extend the bottom
point downward — keep the top at y=88 so it still hangs from the cloud. Sleet drops
were taken to **11** (`v11`) so sleet reads distinctly from snow (flakes, no streak).
Edit BOTH the baked webp (re-run the Lottie through `bake_v3.sh`) AND the static SVGs
(`wi-*-sleet.svg`, both packs, all sizes) or the two will disagree when animation is off.

## Steps
1. **Static color** — fetch flat `svg-static`, strip masks, drop into
   `contents/icons/basmilius/{16,22,24,32}/wi-<stem>.svg` (one SVG copied to all
   four sizes; SVGs are scalable, the dirs just satisfy Plasma's size lookup).
   ```fish
   python3 strip_masks.py in.svg out.svg
   ```
2. **Static white** — `python3 flatten_white.py color.svg white.svg` →
   `contents/icons/basmilius-white/...`.
3. **Animations** — `bash bake_v3.sh` (fetches flat Lottie, renders, decimates to
   ~90 frames, optimizes) → `contents/icons/animated/*.gif`.
4. **VERIFY with the real renderer**, not rsvg/magick (they support masks; QtSvg
   does not, so they lie):
   ```fish
   QT_QPA_PLATFORM=offscreen python3 qtsvg_render.py out.svg check.png 96   # static
   QT_QPA_PLATFORM=offscreen python3 qmovie_render.py out.gif check.png 30  # animated, frame 30
   ```
   `qtsvg_render.py` uses PyQt6's `QSvgRenderer` (= the widget's QtSvg);
   `qmovie_render.py` uses `QMovie` (= what `AnimatedImage` uses). `magick` lies for
   both: it supports SVG masks and composites optimized GIF frames that Qt does not.

## Stem ↔ Meteocons name maps
See `contents/icons/meteocons/ATTRIBUTION.md` (the icon packs) and
`contents/icons/basmilius-white/ATTRIBUTION.md` (the panel set).
