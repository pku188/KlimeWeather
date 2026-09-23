# Meteocons icon packs

The icons in this folder are **Meteocons by Bas Milius**
(https://github.com/basmilius/meteocons, https://meteocons.com), licensed under
the MIT License (see `LICENSE` in this folder).

- Source: the npm packages **`@meteocons/svg` 0.1.0** (animated, SMIL) and
  **`@meteocons/svg-static` 0.1.0**, in all four styles: fill, flat, line and
  monochrome.
- Layout: `<style>/static/wi-<stem>.svg` and `<style>/animated/wi-<stem>.svg`.
  The `wi-*` stem names are this widget's own convention (shared with the custom
  folder option), kept stable so the QML needs no change across icon updates.
- Built by `tools/icon-pipeline/meteocons_packs.py`, which holds the stem map
  below as code.

## What the pipeline changes

The artwork is left as drawn; only how it is written changes, so Qt draws it the
way a browser does.

**Masks.** Meteocons hides a sun, a moon or a back cloud behind the front cloud
(and the fog sun below its horizon) with `<mask style="mask-type:alpha">` over
black shapes. Qt reads every mask as a luminance mask — QtSvg (`Image`,
`Kirigami.Icon`) and Qt Quick's `VectorImage` both ignore `mask-type` — and black
has no luminance, so the masked artwork vanished. The pipeline repaints those mask
shapes white and drops the mask-type: an alpha mask of an opaque shape and a
luminance mask of the same shape painted white are the same region, so the picture
is unchanged and the masks keep their animation. (`<clipPath>` is no way out:
neither renderer applies it.)

**Animations** (the `animated/` sets). `VectorImage` plays SMIL only in part: it
drops `<animate attributeName="opacity">` (so "rain" fell as one drop instead of
three), ignores `keySplines` and `keyTimes`, and turns a `begin` offset into a
pause inside every loop. CSS `@keyframes` it plays exactly. So an element with an
opacity animation gets all its animations as one CSS `@keyframes`, and every other
animation stays SMIL (it must, inside masks) re-sampled into evenly spaced linear
values. Either way the easing curves are sampled into linear steps and a `begin`
offset becomes a phase shift — for an endless loop, starting late and starting
part-way through look the same, minus the empty start.

## Widget stem → Meteocons icon

| widget stem | meteocons |
|---|---|
| wi-day-sunny | clear-day |
| wi-night-clear | starry-night |
| wi-day-cloudy | partly-cloudy-day |
| wi-night-alt-partly-cloudy | partly-cloudy-night |
| wi-cloudy | overcast |
| wi-night-cloudy | overcast-night |
| wi-day-fog | fog-day |
| wi-night-fog | fog-night |
| wi-rain | rain |
| wi-day-rain | partly-cloudy-day-rain |
| wi-night-alt-rain | partly-cloudy-night-rain |
| wi-sleet | sleet |
| wi-day-sleet | partly-cloudy-day-sleet |
| wi-night-alt-sleet | partly-cloudy-night-sleet |
| wi-snow | snow |
| wi-day-snow | partly-cloudy-day-snow |
| wi-night-alt-snow | partly-cloudy-night-snow |
| wi-overcast-snow | overcast-snow |
| wi-thunderstorm | thunderstorms |
| wi-day-thunderstorm | thunderstorms-day |
| wi-night-alt-thunderstorm | thunderstorms-night |

Daytime precipitation uses the sun-free icons (a sun under a fully overcast rain
hour reads wrong); night keeps the moon. The `wi-day-*` precipitation stems are
not used by the widget itself, but keep every pack complete for anyone copying one
as a custom folder.
