# Meteocons icon packs

The icons in this folder are **Meteocons by Bas Milius**
(https://github.com/basmilius/meteocons, https://meteocons.com), licensed under
the MIT License (see `LICENSE` in this folder).

- Source: the npm packages **`@meteocons/svg` 0.1.0** (animated, SMIL) and
  **`@meteocons/svg-static` 0.1.0**, in all four styles: fill, flat, line and
  monochrome.
- Layout: `<style>/static/wi-<stem>.svg` and `<style>/animated/wi-<stem>.svg`,
  and for the colour styles (fill, flat, line) the same again under
  `<style>/light/` for light themes (see below).
  The `wi-*` stem names are this widget's own convention (shared with the custom
  folder option), kept stable so the QML needs no change across icon updates.
- `weather.js`: the still line and monochrome icons again, as SVG text, which the
  panel draws bolder than the files (see the readings' weights below).
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

**Light themes** (the `light/` sets). Meteocons draws its clouds near-white (fill
and flat a white shape, line a white ring) and the fog's lines too: made for a dark
background, on a light one they all but vanished. The light sets, which the widget
shows when the theme's text is dark, outline fill's and flat's white shapes in
`#94A3B8` (Meteocons' own edge of a grey cloud), 2 units of 128 outside the shape.
Each outline is a stroked copy drawn just behind its shape, in the same group with
the same animations, so it moves with the shape. Line's white rings are drawn in
`#7C8BA1` instead (an outline would trace both edges of a ring), and so is every
style's fog lines: a white line outlined read as a hollow bar.

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

## Reading icons (`readings/`)

The icons drawn before a reading — the Weather Elements' icon style, the panel's
readings, the hourly cards' readouts, the graph's sunrise and sunset and the Detailed
view — and the ones the settings list the elements with, from
**`@meteocons/svg-static` 0.1.0**, static, in three styles: the flat set as
`flat/<name>.svg` and `flat.js` and the line set as `line.js`, the Element icon
pack's two for "Use colored icons", and the monochrome set as `monochrome.js` —
`flat.js`, `line.js` and `monochrome.js` SVG strings drawn in `currentColor` that the
widget recolours to the theme's text colour: the whole of a monochrome icon, the
neutral greys of a line icon (its near-black barometer and "UV") and the neutral
lines of a flat icon (its near-black horizons, "UV", "zz"
and umbrella handle, its near-white dashed moon outline), which on one theme
or the other vanished. On a light theme the flat icons' near-white clouds get the
light sets' outline (see above): `flat.js` draws it in a placeholder colour the widget
swaps for `#94A3B8`, or for none on a dark theme. The line icons' clouds and wind
are drawn as the line weather icons draw theirs: `line.js` draws them in a placeholder
colour the widget swaps for `#7C8BA1` on a light theme and `#E6EFFC` on a dark one,
and the afternoon's solid cloud as the weather icons' 4-unit ring; the flat wind is
drawn in the same placeholder, so it matches the line one. The monochrome
afternoon's solid cloud is a ring too, 3 units (its sun's line) inside its outline,
as the monochrome weather icons draw theirs. The precipitation sum's icon
(`raindrops`) is redrawn in every style: in place of Meteocons' two drops, one behind
the other, the style's own raindrop three times — the main one at 92 % and two
smaller ones beside it, at 56 % and 40 %. The `flat/` files are as drawn but for those
drops: the template for a custom folder, and what shows when a custom folder lacks
an icon.
Built by `tools/icon-pipeline/meteocons_packs.py --readings`: masks as above, and
in the monochrome set the artwork painted white (humidity's "%", the umbrella's lit
panel) cut out of the icon, so it shows the background as any symbolic icon does.

thermometer, humidity, uv-index, raindrop, raindrops, umbrella, snowflake, cloudy,
barometer, wind, sunrise, sunset, thermometer-raindrop, partly-cloudy-day; for the
Detailed view the moon's eight phases (moon-new … moon-waning-crescent, drawn without
the extra weight), moonrise and moonset, and the eight time-of-day icons
(time-night … time-late-evening) with the hour range under their artwork taken out.

The line and monochrome icons — the readings' and the panel's weather icon
(`weather.js`) — are drawn bolder than Meteocons draws them: its 2–4 unit lines came
out under a pixel wide at the widget's sizes. By how much depends on the style and the
place (`contents/ui/iconweights.js`): the monochrome readings 3 units (of 128) bolder,
as drawn in the Detailed view, whose icons are larger, and not the solid ones, the
thermometers or the moon's phases; the line readings' stroked lines 2, as drawn in
the Detailed view; the panel's weather icon 2. Each icon is stored once, its lines that
grow marked, and drawn at the place's weight.
