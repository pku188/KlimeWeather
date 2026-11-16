#!/usr/bin/env python3
# Copyright 2026 pku188
"""Build the four Meteocons icon packs the widget ships.

Takes the published npm packages as they are — @meteocons/svg (animated, SMIL)
and @meteocons/svg-static — and writes, for each style (fill, flat, line,
monochrome), the few icons the widget uses under its own wi-* stem names:

    contents/icons/meteocons/<style>/static/wi-<stem>.svg
    contents/icons/meteocons/<style>/animated/wi-<stem>.svg

and for the colour styles (fill, flat, line) a second set for light themes, which
the widget picks when the theme's text is dark:

    contents/icons/meteocons/<style>/light/static/wi-<stem>.svg
    contents/icons/meteocons/<style>/light/animated/wi-<stem>.svg

Meteocons draws its clouds near-white — fill and flat a white shape, line a white
ring — and the fog's lines too: made for a dark background, on a light one they all
but vanished. The light sets outline fill's and flat's white shapes (LIGHT_WHITE)
in a soft grey, LIGHT_OUTLINE, LIGHT_OUTLINE_WIDTH units wide: a stroked copy of the
shape drawn just behind it, so the outline lies wholly outside the shape, and moves
with it — the copy sits in the same group and carries the shape's own animations.
Line's white rings are drawn in LIGHT_LINE instead (an outline traced both edges of
a ring and made the cloud a tube), and so are every style's fog lines (LIGHT_FOG):
a white line outlined read as a hollow bar.

It also writes the still line and monochrome weather icons the widget shows a
second time, as a JavaScript module of SVG strings, for the panel, which draws them
bolder than the files (see Weights below; WIDGET_STEMS, WEATHER_JS_STYLES):

    contents/icons/meteocons/weather.js

usage: meteocons_packs.py <svg-package-dir> <svg-static-package-dir> <out-dir>
       meteocons_packs.py --readings <svg-static-package-dir> <out-dir>
       (the package dirs are the extracted tarballs' "package" folders)

--readings writes the icons drawn before a reading (the Weather Elements' icon
style, the panel's readings, the hourly cards' readouts and the graph's sunrise
and sunset), the Detailed view's moon and time-of-day icons, and the ones the
settings list their elements with, static, in three styles — flat and line,
the colour ones ("Use colored icons", from the Element icon pack), and
monochrome, tinted to the theme's text colour:

    contents/icons/meteocons/readings/flat/<name>.svg
    contents/icons/meteocons/readings/flat.js
    contents/icons/meteocons/readings/line.js
    contents/icons/meteocons/readings/monochrome.js

The line style draws its outlines in neutral greys meant for one background or
the other — the barometer and the "UV" nearly black, the cloud and the wind
nearly white — so on a dark or a light theme some of it vanished. Its set
(line.js, like monochrome.js a module of SVG strings) has those greys
(LINE_INK) in currentColor, which the widget draws in the theme's text colour;
its colours stay as drawn. Its stroked lines grow with the weight the widget draws
them at (see Weights below). Its clouds and wind (LINE_AS_WEATHER) are
drawn as the line weather icons draw them instead, in LINE_WHITE_TOKEN, which the
widget swaps for LIGHT_LINE on a light theme and LINE_WHITE on a dark one; the
afternoon's solid cloud becomes the weather icons' ring (LINE_RING units wide).

The flat style draws a few lines in neutral greys too — the horizon under a rising
or setting sun or moon, the "UV", the night's "zz" and the umbrella's handle nearly
black, the wind and the dashed outline of the moon's dark part nearly white — which
vanished on a dark or a light theme. Its set (flat.js) has those greys (FLAT_INK)
in currentColor, drawn in the theme's text colour as the line style's are, but
for the wind (FLAT_AS_LINE), drawn in LINE_WHITE_TOKEN as the line style's wind; its
colours and its solid neutral shapes (the barometer's dial) stay as drawn. Its
near-white clouds, all but lost on a light theme, get the light sets' outline
(LIGHT_OUTLINE), drawn in OUTLINE_TOKEN, which the widget swaps for LIGHT_OUTLINE on
a light theme and "none" on a dark one. The flat/ files stay as drawn: the template for a custom folder, and what shows when
a custom folder lacks an icon.

The monochrome set is a JavaScript module of SVG strings drawn in currentColor:
the widget swaps in the theme's colour and hands Image the result as a data URL,
so every copy of an icon at one size shares one rendering (a tinting effect per
icon would cost a render pass each, and the hourly cards hold a couple hundred).
Its artwork painted white — humidity's "%", the umbrella's lit panel — is cut out
of the icon instead (a luminance mask), or it would stay white over the tint. Its
lines, filled outlines too, grow with the weight (see Weights below), all but those
of MONO_AS_DRAWN. The afternoon's cloud, solid in this
set, is drawn as a ring (MONO_RING_CLOUDS, MONO_RING), as the monochrome weather
icons draw their clouds: solid, it read as a dark blot on a light theme.

The precipitation sum's icon ("raindrops") is redrawn in every style: Meteocons'
two drops, one behind the other, read as something else entirely, so it is the
style's own raindrop three times instead — a main drop and two smaller ones beside
it (THREE_DROPS).

Weights. Meteocons' 2–4 unit lines came out under a pixel wide at the widget's
sizes, so the widget draws its line and monochrome icons bolder — by how much
depends on the style and where they show, set in contents/ui/iconweights.js. Each
icon is written once, its lines that grow marked (mark_weight): a stroke's width
written "+N", N as drawn, which the widget draws N + the weight wide, and a filled
shape that grows given a stroke of its own colour "+0" wide.

Otherwise the artwork is left as drawn; what changes is how it is written, so that Qt
draws it the way a browser does.

Masks (both sets). Meteocons hides a sun, a moon or a back cloud behind the
front cloud (and the fog sun below its horizon) with <mask style=
"mask-type:alpha"> over BLACK shapes. Qt reads every mask as a luminance mask —
QtSvg (Image, Kirigami.Icon) and Qt Quick's VectorImage alike ignore mask-type —
and black has no luminance, so the masked part vanished. An alpha mask of an
opaque shape is the same region as a luminance mask of that shape painted white,
so the shapes are repainted white and the mask-type dropped. (<clipPath> is no
way out: neither renderer applies it.)

Animations (animated set). VectorImage plays SMIL only in part (Qt 6.11):
  - <animate attributeName="opacity"> is dropped altogether, so a raindrop that
    starts at opacity 0 never shows — "rain" fell as one drop instead of three;
  - keySplines are ignored (every motion runs linear) and so are keyTimes (the
    values are spread evenly over the duration);
  - a begin offset becomes a pause inside every loop, not once before the first.
CSS @keyframes, on the other hand, play exactly — opacity, any percentages, and
transforms (rotate through translate/rotate/translate: transform-origin is
ignored). So:
  - an element with an opacity animation gets all its animations as one CSS
    @keyframes, with the easing curves sampled into linear steps and the begin
    offset turned into a phase shift (for an endless loop, starting late and
    starting part-way through are the same thing, minus the empty start);
  - every other animation stays SMIL (it also runs inside masks, whose cut-out
    must move in step with the cloud it follows), re-sampled into evenly spaced
    linear values with the easing and phase built in.
"""
import copy, json, math, os, re, sys
import xml.etree.ElementTree as ET

SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
SHAPES = {"{%s}%s" % (SVG, t) for t in ("path", "rect", "circle", "ellipse", "polygon", "polyline", "line")}

STYLES = ("fill", "flat", "line", "monochrome")
# the colour styles, which get a set for light themes (see the module's docstring)
LIGHT_STYLES = ("fill", "flat", "line")

# widget stem → Meteocons icon. Daytime precipitation is sun-free (a sun under
# a 100 % overcast rain hour reads wrong); night keeps the moon. The wi-day-*
# precipitation stems are unused by conditionStem() but kept so every pack has
# the same names as the custom-folder convention.
STEMS = {
    "wi-day-sunny":              "clear-day",
    "wi-night-clear":            "starry-night",
    "wi-day-cloudy":             "partly-cloudy-day",
    "wi-night-alt-partly-cloudy": "partly-cloudy-night",
    "wi-cloudy":                 "overcast",
    "wi-night-cloudy":           "overcast-night",
    "wi-day-fog":                "fog-day",
    "wi-night-fog":              "fog-night",
    "wi-rain":                   "rain",
    "wi-day-rain":               "partly-cloudy-day-rain",
    "wi-night-alt-rain":         "partly-cloudy-night-rain",
    "wi-sleet":                  "sleet",
    "wi-day-sleet":              "partly-cloudy-day-sleet",
    "wi-night-alt-sleet":        "partly-cloudy-night-sleet",
    "wi-snow":                   "snow",
    "wi-day-snow":               "partly-cloudy-day-snow",
    "wi-night-alt-snow":         "partly-cloudy-night-snow",
    "wi-overcast-snow":          "overcast-snow",
    "wi-thunderstorm":           "thunderstorms",
    "wi-day-thunderstorm":       "thunderstorms-day",
    "wi-night-alt-thunderstorm": "thunderstorms-night",
}


# The readings' icons, under their Meteocons names; the weather icon's in the
# settings' lists of elements; the Detailed view's moon — its phases, moonrise and
# moonset — and the time-of-day icons before its date line (TIME_ICONS).
MOON_PHASES = ("moon-new", "moon-waxing-crescent", "moon-first-quarter", "moon-waxing-gibbous",
               "moon-full", "moon-waning-gibbous", "moon-last-quarter", "moon-waning-crescent")
TIME_ICONS = ("time-night", "time-late-night", "time-morning", "time-late-morning",
              "time-afternoon", "time-late-afternoon", "time-evening", "time-late-evening")
READINGS = ("thermometer", "humidity", "uv-index", "raindrop", "raindrops", "umbrella",
            "snowflake", "cloudy", "barometer", "wind", "sunrise", "sunset",
            "thermometer-raindrop", "partly-cloudy-day") + MOON_PHASES + ("moonrise", "moonset") + TIME_ICONS
READING_STYLES = ("monochrome", "flat", "line")
# The line style's neutral greys (see the module's docstring): drawn in the theme's
# text colour (currentColor) instead.
LINE_INK = {"#1E293B", "#202939", "#475569", "#71717A", "#D6DFE9", "#E2E8F0", "#E6EFFC"}
# The flat style's neutral lines (see the module's docstring), drawn in the theme's text
# colour: the horizon lines, "UV", "zz" (#202939), the umbrella's handle (#71717A), the
# wind (but see FLAT_AS_LINE) and the moon's dashed outline (#E2E8F0). Not its solid
# shapes in neutral colours:
# the barometer's dial (#334155, #475569, #64748B) and the umbrella's lit panel (#F1F5F9)
# read on either theme, and the clouds are outlined instead (LIGHT_OUTLINE).
FLAT_INK = {"#202939", "#71717A", "#E2E8F0"}
# Light themes (see the module's docstring). The near-white clouds — a fill style
# cloud's gradient has only these stops — and the fog's lines.
LIGHT_WHITE = {"#E6EFFC", "#F3F7FE"}
LIGHT_FOG = {"#E2E8F0"}
# fill's and flat's outline: Meteocons' own edge of a grey cloud (the fill style's),
# 2 units of the 128-unit box outside the shape — a hairline on the small icons, soft on
# the large ones (3, and darker greys, read as a drawn border rather than an edge).
LIGHT_OUTLINE = "#94A3B8"
LIGHT_OUTLINE_WIDTH = 2
# line's white rings and lines: between the back cloud's #94A3B8 and slate #64748B, so
# the front cloud stays the strongest, as its white is on a dark theme.
LIGHT_LINE = "#7C8BA1"
# The line reading icons drawn as the line weather icons are (see the module's
# docstring): their clouds and wind, grey on a light theme and white on a dark one.
LINE_AS_WEATHER = ("cloudy", "partly-cloudy-day", "time-afternoon", "wind")
LINE_WHITE_TOKEN = "lineWhite"
LINE_WHITE = "#E6EFFC"   # the line style's cloud, as drawn
LINE_RING = 4            # its cloud's ring, units of 128 wide
# The flat reading icons drawn in the line icons' colours rather than the text colour:
# the wind, its near-white lines (FLAT_INK's #E2E8F0) in LINE_WHITE_TOKEN — grey on a
# light theme, white on a dark one — as the line style's wind (LINE_AS_WEATHER).
FLAT_AS_LINE = ("wind",)
FLAT_AS_LINE_INK = {"#E2E8F0"}
# The flat reading icons' cloud outline in flat.js: the widget swaps it for
# LIGHT_OUTLINE on a light theme and "none" on a dark one, where the cloud shows.
OUTLINE_TOKEN = "cloudOutline"
# The line and monochrome icons are drawn bolder than Meteocons draws them, by how much
# depends on the style and where they show — contents/ui/iconweights.js, applied as the
# widget draws them. The pipeline only marks which lines grow (mark_weight): every line
# of the monochrome icons (filled outlines too — a cloud is a thin filled ring), the
# stroked lines of the line reading icons, and every line of the line weather icons.
# Left as drawn, the monochrome icons that thickened badly: the solid icons (the
# raindrops ran together), the thermometers (the glass, mercury and drop ran into one
# hard-to-read shape) and the moon's phases (the dashed outline of the dark part
# outweighed the lit part).
MONO_AS_DRAWN = {"humidity", "raindrop", "raindrops", "snowflake",
                 "thermometer", "thermometer-raindrop"} | set(MOON_PHASES)
# The weather icons the panel draws bolder (weather.js): the still line and monochrome
# ones, the stems the widget shows (not the wi-day-* precipitation ones, see STEMS).
# Line's near-white clouds and fog lines in tokens, swapped for LIGHT_LINE on a light
# theme, as its light set draws them, and back on a dark one.
WEATHER_JS_STYLES = ("monochrome", "line")
WIDGET_STEMS = tuple(s for s in STEMS if s not in
                     ("wi-day-rain", "wi-day-sleet", "wi-day-snow", "wi-day-thunderstorm"))
LINE_FOG_TOKEN = "lineFog"
LINE_FOG = "#E2E8F0"     # the line style's fog lines, as drawn
# The monochrome icons whose cloud is solid, drawn as the monochrome weather icons draw
# theirs instead: a ring MONO_RING units wide inside the cloud's outline (and the icon's
# extra weight on top). The afternoon's solid cloud read as a dark blot on a light theme.
# Its cloud is small: the clouds' usual 4 swallowed its bumps; 3 is its sun's line.
MONO_RING_CLOUDS = ("time-afternoon",)
MONO_RING = 3
# The precipitation sum's icon ("raindrops"). Meteocons draws two drops, one behind
# the other, which read as something else entirely; the widget draws the style's own
# raindrop (raindrop.svg, centred on x DROP_ORIGIN[0] with its bottom at y
# DROP_ORIGIN[1]) three times instead: a main drop a little smaller than drawn, and a
# medium and a small one up and down beside it — each (centre x, bottom y, scale), the
# three centred in the box. Only the drop's outline is scaled, not its line's width.
DROP_ORIGIN = (64.5, 94)
THREE_DROPS = ((52.5, 95.8, 0.92), (83.5, 65.8, 0.56), (86.5, 95.8, 0.40))


def fail(path, msg):
    sys.exit("meteocons_packs: %s: %s" % (path, msg))


def luminance_masks(root, path):
    for mask in root.iter("{%s}mask" % SVG):
        style = (mask.get("style") or "").replace(" ", "")
        if style and style != "mask-type:alpha":
            fail(path, "unexpected mask style %r" % style)
        mask.attrib.pop("style", None)
        for el in mask.iter():
            if el is mask:
                continue
            if el.get("opacity") or el.get("fill-opacity") or el.get("stroke-opacity"):
                fail(path, "mask shape with its own opacity is not handled")
            if el.tag in SHAPES:
                # an absent fill is black by default: it is painted too
                if el.get("fill", "black") != "none":
                    el.set("fill", "white")
                if el.get("stroke") not in (None, "none"):
                    el.set("stroke", "white")


# ── animation rewriting ─────────────────────────────────────────────────────
SPLINE_STEPS = 8         # linear steps per eased segment
CSS_JUMP = 0.001         # seconds between the two keyframes of an instant jump


def _nums(text):
    return [float(v) for v in text.replace(",", " ").split()]


def _bezier_y_at_x(x1, y1, x2, y2, x):
    # CSS/SMIL timing curve through (0,0), (x1,y1), (x2,y2), (1,1): solve X(s) = x
    def bez(a, b, s):
        return 3 * a * s * (1 - s) ** 2 + 3 * b * s * s * (1 - s) + s ** 3
    lo, hi = 0.0, 1.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if bez(x1, x2, mid) < x: lo = mid
        else: hi = mid
    return bez(y1, y2, (lo + hi) / 2)


class Track:
    """One SMIL animation as an exact function of the loop phase τ ∈ [0, 1)."""
    def __init__(self, el, path):
        self.el = el
        self.attr = el.get("attributeName")
        self.kind = el.get("type") if self.attr == "transform" else self.attr
        if self.kind not in ("translate", "rotate", "opacity"):
            fail(path, "unhandled animation %s" % self.kind)
        if el.get("repeatCount") != "indefinite" or el.get("from") or el.get("to") \
                or el.get("additive") or el.get("accumulate"):
            fail(path, "unhandled animation form")
        self.dur = float(el.get("dur").rstrip("s"))
        self.begin = float((el.get("begin") or "0s").rstrip("s"))
        self.values = [_nums(v) for v in el.get("values").split(";")]
        width = max(len(v) for v in self.values)
        # "translate x" means y = 0; a rotation's centre defaults to the origin
        self.values = [v + [0.0] * (width - len(v)) for v in self.values]
        n = len(self.values)
        self.times = ([float(t) for t in el.get("keyTimes").split(";")] if el.get("keyTimes")
                      else [i / (n - 1) for i in range(n)])
        self.mode = el.get("calcMode", "linear")
        if self.mode not in ("linear", "spline"):
            fail(path, "unhandled calcMode %s" % self.mode)
        self.splines = ([_nums(k) for k in el.get("keySplines").split(";")]
                        if self.mode == "spline" else None)
        # where the loop starts, as a fraction of it: begin="0.4s" of a 1 s loop
        # plays from 0.6 of the way through at t = 0
        self.phase = (self.begin / self.dur) % 1.0

    def at(self, tau):
        """Value at loop phase τ of the ORIGINAL (unshifted) animation."""
        t, v = self.times, self.values
        if tau <= t[0]: return list(v[0])
        for i in range(len(t) - 1):
            if tau <= t[i + 1] and t[i + 1] > t[i]:
                x = (tau - t[i]) / (t[i + 1] - t[i])
                if self.splines:
                    x = _bezier_y_at_x(*self.splines[i], x)
                return [a + (b - a) * x for a, b in zip(v[i], v[i + 1])]
        return list(v[-1])

    def shifted(self, t):
        """Value at time t (fraction of the loop) once the begin offset is a phase."""
        return self.at((t - self.phase) % 1.0)

    def points(self):
        """The shifted animation as (t, value) points for linear interpolation:
        every key time, SPLINE_STEPS points inside each eased segment, and the
        loop seam. A jump (last value ≠ first) is two points CSS_JUMP apart."""
        taus = set(self.times)
        if self.splines:
            for i in range(len(self.times) - 1):
                a, b = self.times[i], self.times[i + 1]
                taus.update(a + (b - a) * k / SPLINE_STEPS for k in range(1, SPLINE_STEPS))
        seam = (1.0 - self.phase) % 1.0          # the original moment that plays at t = 0
        taus.add(seam)
        pts = []
        for tau in taus:
            t = (tau + self.phase) % 1.0
            if tau == 1.0 or (tau == 0.0 and self.phase > 0):
                continue                          # the loop boundary: handled below
            pts.append((t, self.at(tau)))
        first, last = self.at(0.0), self.at(1.0)
        pts.append((1.0, self.at(seam)))
        if self.phase > 0:
            if max(abs(a - b) for a, b in zip(first, last)) > 1e-9:
                gap = CSS_JUMP / self.dur
                pts.append((self.phase, last))
                pts.append((self.phase + gap, first))
            else:
                pts.append((self.phase, first))
        else:
            pts.append((0.0, first))
        pts.sort(key=lambda p: p[0])
        return pts

    def continuous(self):
        return max(abs(a - b) for a, b in zip(self.at(0.0), self.at(1.0))) < 1e-9


def _interp(pts, t):
    for i in range(len(pts) - 1):
        (t0, v0), (t1, v1) = pts[i], pts[i + 1]
        if t0 <= t <= t1:
            if t1 == t0: return v1
            f = (t - t0) / (t1 - t0)
            return [a + (b - a) * f for a, b in zip(v0, v1)]
    return pts[-1][1]


def _fmt(x):
    s = "%.4f" % x
    s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def _css_value(track, v):
    if track.kind == "opacity":
        return "opacity: %s" % _fmt(v[0])
    if track.kind == "translate":
        return "transform: translate(%spx, %spx)" % (_fmt(v[0]), _fmt(v[1]))
    a, cx, cy = v
    return "transform: translate(%spx, %spx) rotate(%sdeg) translate(%spx, %spx)" % (
        _fmt(cx), _fmt(cy), _fmt(a), _fmt(-cx), _fmt(-cy))


def rewrite_animations(root, path):
    anim_tags = ("{%s}animate" % SVG, "{%s}animateTransform" % SVG)
    rules = []
    for el in list(root.iter()):
        anims = [c for c in el if c.tag in anim_tags]
        if not anims:
            continue
        tracks = [Track(a, path) for a in anims]
        if any(t.kind == "opacity" for t in tracks):
            # all of this element's animations as one CSS @keyframes
            if len({t.dur for t in tracks}) != 1:
                fail(path, "animations of different lengths on one element")
            if sum(t.kind != "opacity" for t in tracks) > 1 or sum(t.kind == "opacity" for t in tracks) > 1:
                fail(path, "two animations of one property on one element")
            if el.get("class") or el.get("style"):
                fail(path, "element already styled")
            per = [(t, t.points()) for t in tracks]
            times = sorted({round(p[0], 6) for _, pts in per for p in pts})
            name = "k%d" % len(rules)
            frames = []
            for t in times:
                props = "; ".join(_css_value(tr, _interp(pts, t)) for tr, pts in per)
                frames.append("%s%% { %s }" % (_fmt(t * 100), props))
            rules.append("@keyframes %s { %s }\n.%s { animation: %s %ss linear infinite }"
                         % (name, " ".join(frames), name, name, _fmt(tracks[0].dur)))
            el.set("class", name)
            for a in anims:
                el.remove(a)
        else:
            # stays SMIL: evenly spaced linear values (Qt spreads values evenly and
            # ignores keySplines), easing and phase built in
            for tr in tracks:
                if tr.mode == "linear" and tr.phase == 0 and not tr.el.get("keyTimes"):
                    continue                      # already plays exactly
                if not tr.continuous():
                    fail(path, "a jumping SMIL animation needs CSS")
                segments = SPLINE_STEPS * (len(tr.values) - 1)
                vals = [tr.shifted(j / segments) for j in range(segments + 1)]
                a = tr.el
                a.set("values", ";".join(" ".join(_fmt(x) for x in v) for v in vals))
                for k in ("keyTimes", "keySplines", "begin"):
                    a.attrib.pop(k, None)
                a.set("calcMode", "linear")
    if rules:
        style = ET.Element("{%s}style" % SVG)
        style.text = "\n" + "\n".join(rules) + "\n"
        root.insert(0, style)


def build(src_anim, src_static, out):
    written = 0
    for style in STYLES:
        for kind, src in (("animated", src_anim), ("static", src_static)):
            dest = os.path.join(out, style, kind)
            os.makedirs(dest, exist_ok=True)
            for stem, name in STEMS.items():
                path = os.path.join(src, style, name + ".svg")
                tree = ET.parse(path)
                luminance_masks(tree.getroot(), path)
                if kind == "animated":
                    rewrite_animations(tree.getroot(), path)
                tree.write(os.path.join(dest, stem + ".svg"), encoding="unicode")
                written += 1
                if style in LIGHT_STYLES:
                    light = os.path.join(out, style, "light", kind)
                    os.makedirs(light, exist_ok=True)
                    light_set(tree.getroot(), style)
                    tree.write(os.path.join(light, stem + ".svg"), encoding="unicode")
                    written += 1
    write_weather_js(out)
    print("wrote %d icons and weather.js to %s" % (written, out))


def knockout_white(root, path):
    """Cut the artwork painted white out of the icon (see --readings)."""
    defined = set()   # shapes inside <mask> and <clipPath> are not artwork
    for tag in ("mask", "clipPath"):
        for d in root.iter("{%s}%s" % (SVG, tag)):
            defined.update(d.iter())
    parent = {c: p for p in root.iter() for c in p}
    whites = [el for el in root.iter()
              if el.tag in SHAPES and el.get("fill") == "white" and el not in defined]
    if not whites:
        return
    x, y, w, h = (root.get("viewBox") or "0 0 128 128").split()
    mask = ET.Element("{%s}mask" % SVG, {"id": "knockout", "maskUnits": "userSpaceOnUse",
                                         "x": x, "y": y, "width": w, "height": h})
    ET.SubElement(mask, "{%s}rect" % SVG, {"x": x, "y": y, "width": w, "height": h, "fill": "white"})
    for el in whites:
        a = parent.get(el)
        while a is not None and a is not root:
            if a.get("transform"):
                fail(path, "white artwork under a transform is not handled")
            a = parent.get(a)
        hole = ET.fromstring(ET.tostring(el))
        hole.set("fill", "black")
        mask.append(hole)
        parent[el].remove(el)
    defs = root.find("{%s}defs" % SVG)
    if defs is None:
        defs = ET.Element("{%s}defs" % SVG)
        root.insert(0, defs)
    defs.append(mask)
    group = ET.Element("{%s}g" % SVG, {"mask": "url(#knockout)"})
    for ch in list(root):
        if ch is not defs:
            root.remove(ch)
            group.append(ch)
    root.append(group)


def mark_weight(root, colours=None, fills=True):
    """Mark the lines that grow with the weight the widget draws the icon at
    (contents/ui/iconweights.js, which reads a "+N" stroke width as N + the weight):
    every stroke's width written "+N", N its width as drawn, and with `fills` every
    filled shape given a stroke of its own colour "+0" wide, so a filled outline grows
    as much. Only shapes painted in `colours` (None: any colour, not a gradient); not
    mask and clip shapes, which are geometry, not artwork."""
    defined = set()
    for tag in ("mask", "clipPath"):
        for d in root.iter("{%s}%s" % (SVG, tag)):
            defined.update(d.iter())
    def painted(c):
        return (c not in (None, "none") and not c.startswith("url(")
                and (colours is None or c in colours))
    for el in root.iter():
        if el in defined or el.tag not in SHAPES:
            continue
        if painted(el.get("stroke")):
            el.set("stroke-width", "+%g" % float(el.get("stroke-width", "1")))
        elif fills and painted(el.get("fill")):
            el.set("stroke", el.get("fill"))
            el.set("stroke-width", "+0")
            el.set("stroke-linejoin", "round")


def ink_to_current(root, ink=LINE_INK, colour="currentColor"):
    """Paint a style's greys (LINE_INK, FLAT_INK) in `colour` (currentColor), outside
    masks and clip paths, whose colours are geometry."""
    defined = set()
    for tag in ("mask", "clipPath"):
        for d in root.iter("{%s}%s" % (SVG, tag)):
            defined.update(d.iter())
    for el in root.iter():
        if el in defined:
            continue
        for attr in ("fill", "stroke", "stop-color"):
            if (el.get(attr) or "").upper() in ink:
                el.set(attr, colour)


def _whites(root):
    """The artwork's near-white shapes (LIGHT_WHITE, a white gradient's too) and
    near-white lines (LIGHT_FOG), with their parents: [(el, parent, is_line)]. Not
    the shapes of masks and clip paths, nor the gradients' own definitions."""
    defined = set()
    for tag in ("mask", "clipPath", "defs"):
        for d in root.iter("{%s}%s" % (SVG, tag)):
            defined.update(d.iter())
    white_grads = set()
    for g in root.iter():
        if g.tag in ("{%s}linearGradient" % SVG, "{%s}radialGradient" % SVG):
            stops = {(st.get("stop-color") or "").upper() for st in g}
            if stops and stops <= LIGHT_WHITE:
                white_grads.add(g.get("id"))
    parent = {c: p for p in root.iter() for c in p}
    found = []
    for el in root.iter():
        if el in defined or el.tag not in SHAPES:
            continue
        fill = el.get("fill") or ""
        grad = fill[5:-1] if fill.startswith("url(#") and fill.endswith(")") else None
        if fill.upper() in LIGHT_WHITE or grad in white_grads:
            found.append((el, parent[el], False))
        elif (el.get("stroke") or "").upper() in LIGHT_FOG:
            found.append((el, parent[el], True))
    return found


def outline_behind(root, colour, width):
    """Outline the near-white shapes and lines (_whites) in `colour`, `width` units
    outside them: a copy of each, stroked and drawn just behind it, so the outline
    shows only outside the shape, and moves with it (same group, same animations).
    Lines are left alone (see light_set)."""
    for el, par, is_line in _whites(root):
        if is_line:
            continue
        own = el.get("stroke") not in (None, "none")
        c = copy.deepcopy(el)
        c.attrib.pop("id", None)
        c.set("fill", "none")
        c.set("stroke", colour)
        c.set("stroke-width", "%g" % ((float(el.get("stroke-width", "1")) if own else 0) + 2 * width))
        c.set("stroke-linejoin", "round")
        par.insert(list(par).index(el), c)


def light_set(root, style):
    """The light theme's form of a colour style's icon (see the module's docstring)."""
    if style != "line":
        outline_behind(root, LIGHT_OUTLINE, LIGHT_OUTLINE_WIDTH)
    for el, _, is_line in _whites(root):
        if is_line:
            el.set("stroke", LIGHT_LINE)
        elif style == "line":
            el.set("fill", LIGHT_LINE)


def ring_solid_clouds(root, colour, width):
    """Draw a solid cloud in `colour` as a ring `width` units wide, as the line weather
    icons draw theirs (the line style's afternoon, see LINE_AS_WEATHER)."""
    for el in root.iter():
        if (el.tag in SHAPES and el.get("fill") == colour
                and el.get("fill-rule") != "evenodd"):
            el.set("fill", "none")
            el.set("stroke", colour)
            el.set("stroke-width", "%g" % width)
            el.set("stroke-linejoin", "round")


def ring_inside(root, ring):
    """Draw each solid cloud of a monochrome icon (MONO_RING_CLOUDS: a currentColor
    shape whose id starts "Cloud", not already a ring) as a ring `ring` units wide
    inside its outline, as Meteocons draws its rings, plus the weight its stroke gives
    it (mark_weight): a stroke twice as wide on the outline, masked by the solid cloud
    with that stroke."""
    parent = {c: p for p in root.iter() for c in p}
    x, y, w, h = (root.get("viewBox") or "0 0 128 128").split()
    clouds = [el for el in root.iter()
              if el.tag in SHAPES and el.get("fill") == "currentColor"
              and el.get("fill-rule") != "evenodd" and (el.get("id") or "").startswith("Cloud")]
    for n, el in enumerate(clouds):
        # its stroke's width: "+N" marked to grow with the weight, or as drawn
        stroke = el.get("stroke-width", "1") if el.get("stroke") == "currentColor" else None
        marked = stroke is not None and stroke.startswith("+")
        extra = float(stroke.lstrip("+")) if stroke is not None else 0
        group = ET.Element("{%s}g" % SVG, {"id": "Cloud ring"})
        mid = "cloud-ring-%d" % n
        mask = ET.SubElement(group, "{%s}mask" % SVG, {"id": mid, "maskUnits": "userSpaceOnUse",
                                                       "x": x, "y": y, "width": w, "height": h})
        solid = copy.deepcopy(el)
        solid.attrib.pop("id", None)
        solid.set("fill", "white")
        if stroke is not None:
            solid.set("stroke", "white")
        mask.append(solid)
        masked = ET.SubElement(group, "{%s}g" % SVG, {"mask": "url(#%s)" % mid})
        line = copy.deepcopy(el)
        line.set("fill", "none")
        line.set("stroke", "currentColor")
        line.set("stroke-width", ("+%g" if marked else "%g") % (2 * ring + extra))
        line.set("stroke-linejoin", "round")
        masked.append(line)
        par = parent[el]
        par.insert(list(par).index(el), group)
        par.remove(el)


def _place_path(d, cx, by, s, path):
    """Path data `d` (absolute M, L, C and Z only) scaled by `s` about DROP_ORIGIN and
    moved there to (cx, by)."""
    out = []
    for cmd, args in re.findall(r"([A-Za-z])([^A-Za-z]*)", d):
        if cmd not in "MLCZ":
            fail(path, "drop path command %r is not handled" % cmd)
        nums = [float(v) for v in re.findall(r"-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", args)]
        pts = ["%s %s" % (_fmt(cx + s * (nums[i] - DROP_ORIGIN[0])),
                          _fmt(by + s * (nums[i + 1] - DROP_ORIGIN[1])))
               for i in range(0, len(nums), 2)]
        out.append(cmd + " ".join(pts))
    return "".join(out)


def three_drops(root, path):
    """The style's raindrop drawn three times (THREE_DROPS): the precipitation sum's
    icon."""
    drops = [el for el in root.iter() if el.tag in SHAPES]
    if len(drops) != 1 or drops[0].tag != "{%s}path" % SVG:
        fail(path, "expected the raindrop as one path")
    drop = drops[0]
    parent = {c: p for p in root.iter() for c in p}
    par = parent[drop]
    at = list(par).index(drop)
    par.remove(drop)
    for n, (cx, by, s) in enumerate(THREE_DROPS):
        c = copy.deepcopy(drop)
        c.set("id", "Drop_%d" % (n + 1))
        c.set("d", _place_path(drop.get("d"), cx, by, s, path))
        par.insert(at + n, c)
    for g in root.iter("{%s}g" % SVG):
        if g.get("id") == "raindrop":
            g.set("id", "raindrops")


def drop_label(root):
    """Take out the hour range a time-of-day icon prints under its artwork ("12-15"):
    unreadable at a line's height, and the date line beside it says the hour."""
    parent = {c: p for p in root.iter() for c in p}
    for el in list(root.iter()):
        if el.get("id") == "Label" and el in parent:
            parent[el].remove(el)


def build_readings(src_static, out):
    dest = os.path.join(out, "readings")
    os.makedirs(os.path.join(dest, "flat"), exist_ok=True)
    mono, line, flat = {}, {}, {}
    def load(style, name):
        # the precipitation sum's three drops are drawn from the style's raindrop
        path = os.path.join(src_static, style, ("raindrop" if name == "raindrops" else name) + ".svg")
        tree = ET.parse(path)
        luminance_masks(tree.getroot(), path)
        if name in TIME_ICONS:
            drop_label(tree.getroot())
        if name == "raindrops":
            three_drops(tree.getroot(), path)
        return tree, path

    for style in READING_STYLES:
        for name in READINGS:
            tree, path = load(style, name)
            if style == "flat":
                tree.write(os.path.join(dest, "flat", name + ".svg"), encoding="unicode")
                if name in FLAT_AS_LINE:
                    ink_to_current(tree.getroot(), FLAT_AS_LINE_INK, LINE_WHITE_TOKEN)
                ink_to_current(tree.getroot(), FLAT_INK)
                outline_behind(tree.getroot(), OUTLINE_TOKEN, LIGHT_OUTLINE_WIDTH)
                flat[name] = ET.tostring(tree.getroot(), encoding="unicode")
            elif style == "line":
                if name in LINE_AS_WEATHER:
                    ink_to_current(tree.getroot(), LINE_INK, LINE_WHITE_TOKEN)
                ink_to_current(tree.getroot())
                mark_weight(tree.getroot(), fills=False)
                # the ring after: as wide as the weather icons' at every weight
                ring_solid_clouds(tree.getroot(), LINE_WHITE_TOKEN, LINE_RING)
                line[name] = ET.tostring(tree.getroot(), encoding="unicode")
            else:
                if name not in MONO_AS_DRAWN:
                    mark_weight(tree.getroot(), {"currentColor"})
                    if name in MONO_RING_CLOUDS:
                        ring_inside(tree.getroot(), MONO_RING)
                knockout_white(tree.getroot(), path)
                mono[name] = ET.tostring(tree.getroot(), encoding="unicode")
    write_mono_js(dest, mono)
    write_line_js(dest, line)
    write_flat_js(dest, flat)
    print("wrote %d reading icons: flat, flat.js, line.js and monochrome.js, to %s" % (len(READINGS), dest))


WEIGHT_NOTE = ("// Each icon once: its stroke widths written \"+N\" grow with the weight the widget\n"
               "// draws it at (contents/ui/iconweights.js, which reads them as N + the weight).\n")


def write_mono_js(dest, mono):
    with open(os.path.join(dest, "monochrome.js"), "w") as js:
        js.write(".pragma library\n"
                 "// Meteocons' monochrome reading icons (MIT, see ../ATTRIBUTION.md), drawn in\n"
                 "// currentColor. Generated by tools/icon-pipeline/meteocons_packs.py --readings;\n"
                 "// edit that, not this.\n" + WEIGHT_NOTE +
                 "var svg = {\n")
        for name in READINGS:
            js.write("    %s: %s,\n" % (json.dumps(name), json.dumps(mono[name])))
        js.write("};\n")


def write_line_js(dest, line):
    with open(os.path.join(dest, "line.js"), "w") as js:
        js.write(".pragma library\n"
                 "// Meteocons' line reading icons (MIT, see ../ATTRIBUTION.md), for the Element\n"
                 "// icon pack's \"Meteocons (line)\": their neutral greys in currentColor, which\n"
                 "// the widget swaps for the theme's text colour, their clouds and wind in\n"
                 "// \"%s\", which it swaps for %s on a light theme and %s on a dark one, as\n"
                 "// the line weather icons draw them, their colours as drawn.\n"
                 "// Generated by tools/icon-pipeline/meteocons_packs.py --readings; edit that, not this.\n"
                 % (LINE_WHITE_TOKEN, LIGHT_LINE, LINE_WHITE) + WEIGHT_NOTE +
                 "var svg = {\n")
        for name in READINGS:
            js.write("    %s: %s,\n" % (json.dumps(name), json.dumps(line[name])))
        js.write("};\n")


def write_weather_js(out):
    """weather.js: the still line and monochrome weather icons the panel draws
    (WEATHER_JS_STYLES, WIDGET_STEMS), from the files build() wrote, as SVG text, so
    the widget can draw them bolder than the files (contents/ui/iconweights.js
    `panel`): their lines marked to grow (mark_weight), and line's near-white clouds
    and fog lines in LINE_WHITE_TOKEN and LINE_FOG_TOKEN (see the widget's
    _tintedIcon)."""
    with open(os.path.join(out, "weather.js"), "w") as js:
        js.write(".pragma library\n"
                 "// Meteocons' still line and monochrome weather icons (MIT, see ATTRIBUTION.md), as\n"
                 "// the panel draws them: the same as line/static/ and monochrome/static/, but as\n"
                 "// SVG text, so they can be drawn bolder. Monochrome in currentColor, which the\n"
                 "// widget swaps for the panel's text colour; line's clouds in \"%s\" and fog\n"
                 "// lines in \"%s\", which it swaps for %s on a light theme, as line/light/\n"
                 "// draws them, and %s and %s on a dark one.\n"
                 "// Generated by tools/icon-pipeline/meteocons_packs.py; edit that, not this.\n"
                 % (LINE_WHITE_TOKEN, LINE_FOG_TOKEN, LIGHT_LINE, LINE_WHITE, LINE_FOG) + WEIGHT_NOTE)
        for style in WEATHER_JS_STYLES:
            js.write("var %s = {\n" % style)
            for stem in WIDGET_STEMS:
                path = os.path.join(out, style, "static", stem + ".svg")
                root = ET.parse(path).getroot()
                if style == "line":
                    for el, _, is_line in _whites(root):
                        if is_line:
                            if el.get("stroke").upper() != LINE_FOG:
                                fail(path, "unexpected fog colour %s" % el.get("stroke"))
                            el.set("stroke", LINE_FOG_TOKEN)
                        else:
                            if (el.get("fill") or "").upper() != LINE_WHITE:
                                fail(path, "unexpected cloud paint %s" % el.get("fill"))
                            el.set("fill", LINE_WHITE_TOKEN)
                    mark_weight(root)
                else:
                    mark_weight(root, {"currentColor"})
                js.write("    %s: %s,\n" % (json.dumps(stem), json.dumps(ET.tostring(root, encoding="unicode"))))
            js.write("};\n")


def write_flat_js(dest, flat):
    with open(os.path.join(dest, "flat.js"), "w") as js:
        js.write(".pragma library\n"
                 "// Meteocons' flat reading icons (MIT, see ../ATTRIBUTION.md), for the Element\n"
                 "// icon pack's \"Meteocons (flat)\": their neutral lines in currentColor, which\n"
                 "// the widget swaps for the theme's text colour, and an outline round their\n"
                 "// near-white clouds in \"%s\", which it swaps for %s on a light theme\n"
                 "// and \"none\" on a dark one; the wind in \"%s\", as the line icons' (line.js);\n"
                 "// the rest as drawn (flat/).\n"
                 "// Generated by tools/icon-pipeline/meteocons_packs.py --readings; edit that, not this.\n"
                 "var svg = {\n" % (OUTLINE_TOKEN, LIGHT_OUTLINE, LINE_WHITE_TOKEN))
        for name in READINGS:
            js.write("    %s: %s,\n" % (json.dumps(name), json.dumps(flat[name])))
        js.write("};\n")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--readings":
        build_readings(*sys.argv[2:])
    elif len(sys.argv) == 4:
        build(*sys.argv[1:])
    else:
        sys.exit(__doc__)
