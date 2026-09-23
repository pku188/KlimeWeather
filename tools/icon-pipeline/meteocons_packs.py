#!/usr/bin/env python3
# Copyright 2026 pku188
"""Build the four Meteocons icon packs the widget ships.

Takes the published npm packages as they are — @meteocons/svg (animated, SMIL)
and @meteocons/svg-static — and writes, for each style (fill, flat, line,
monochrome), the few icons the widget uses under its own wi-* stem names:

    contents/icons/meteocons/<style>/static/wi-<stem>.svg
    contents/icons/meteocons/<style>/animated/wi-<stem>.svg

usage: meteocons_packs.py <svg-package-dir> <svg-static-package-dir> <out-dir>
       (the package dirs are the extracted tarballs' "package" folders)

The artwork is left as drawn; what changes is how it is written, so that Qt
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
import math, os, sys
import xml.etree.ElementTree as ET

SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
SHAPES = {"{%s}%s" % (SVG, t) for t in ("path", "rect", "circle", "ellipse", "polygon", "polyline", "line")}

STYLES = ("fill", "flat", "line", "monochrome")

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
    print("wrote %d icons to %s" % (written, out))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    build(*sys.argv[1:])
