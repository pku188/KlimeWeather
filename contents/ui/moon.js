/*
 * The moon for the Detailed view — its phase, when it rises and sets, and the pass
 * across the sky an hour falls in — computed here, as neither provider sends it. The
 * low-precision formulas of "Astronomy Answers" (aa.quae.nl, Aa. Bloemhof): a minute
 * or two out, which the widget's whole-minute times never show.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
.pragma library

var RAD = Math.PI / 180;
var DAY_MS = 86400000;
var OBLIQUITY = RAD * 23.4397;   // of the Earth's axis
// Altitude of the moon's centre as it rises or sets: its radius and the
// atmosphere's refraction lift it into view a little below the horizon.
var HORIZON = RAD * 0.133;

// days since the J2000 epoch
function _days(ms) { return ms / DAY_MS - 0.5 + 2440588 - 2451545; }
function _ra(l, b) {
    return Math.atan2(Math.sin(l) * Math.cos(OBLIQUITY) - Math.tan(b) * Math.sin(OBLIQUITY), Math.cos(l));
}
function _dec(l, b) {
    return Math.asin(Math.sin(b) * Math.cos(OBLIQUITY) + Math.cos(b) * Math.sin(OBLIQUITY) * Math.sin(l));
}

function _sun(d) {
    var m = RAD * (357.5291 + 0.98560028 * d);   // mean anomaly
    var c = RAD * (1.9148 * Math.sin(m) + 0.02 * Math.sin(2 * m) + 0.0003 * Math.sin(3 * m));
    var l = m + c + RAD * 102.9372 + Math.PI;     // ecliptic longitude
    return { ra: _ra(l, 0), dec: _dec(l, 0) };
}
function _moon(d) {
    var l0 = RAD * (218.316 + 13.176396 * d);     // ecliptic longitude
    var m = RAD * (134.963 + 13.064993 * d);      // mean anomaly
    var f = RAD * (93.272 + 13.229350 * d);       // mean distance
    var l = l0 + RAD * 6.289 * Math.sin(m), b = RAD * 5.128 * Math.sin(f);
    return { ra: _ra(l, b), dec: _dec(l, b), km: 385001 - 20905 * Math.cos(m) };
}

// The moon's altitude above the horizon at `ms` (UTC), in radians.
function _altitude(ms, lat, lon) {
    var d = _days(ms), c = _moon(d), phi = RAD * lat;
    var h = RAD * (280.16 + 360.9856235 * d) + RAD * lon - c.ra;   // hour angle
    return Math.asin(Math.sin(phi) * Math.sin(c.dec) + Math.cos(phi) * Math.cos(c.dec) * Math.cos(h));
}

/*
 * The phase at `ms` (UTC): `phase` 0 new, 0.25 first quarter, 0.5 full, 0.75 last
 * quarter; `lit` the fraction of the disc in sunlight; `index` one of PHASES.
 */
function phase(ms) {
    var d = _days(ms), s = _sun(d), m = _moon(d), sunKm = 149598000;
    var elong = Math.acos(Math.sin(s.dec) * Math.sin(m.dec)
                          + Math.cos(s.dec) * Math.cos(m.dec) * Math.cos(s.ra - m.ra));
    var inc = Math.atan2(sunKm * Math.sin(elong), m.km - sunKm * Math.cos(elong));
    var side = Math.atan2(Math.cos(s.dec) * Math.sin(s.ra - m.ra),
                          Math.sin(s.dec) * Math.cos(m.dec) - Math.cos(s.dec) * Math.sin(m.dec) * Math.cos(s.ra - m.ra));
    var p = 0.5 + 0.5 * inc * (side < 0 ? -1 : 1) / Math.PI;
    // eight phases, each the eighth of the cycle around its own moment
    return { phase: p, lit: (1 + Math.cos(inc)) / 2, index: Math.floor(p * 8 + 0.5) % 8 };
}
// The phases' Meteocons icons, in order from the new moon.
var PHASES = ["moon-new", "moon-waxing-crescent", "moon-first-quarter", "moon-waxing-gibbous",
              "moon-full", "moon-waning-gibbous", "moon-last-quarter", "moon-waning-crescent"];

// The first time from `fromMs` on (dir +1) or back (dir -1) that the moon crosses the
// horizon, within a day and a half; NaN if it doesn't. In 10-minute steps, then
// between the two steps the horizon falls between.
function _crossing(fromMs, dir, lat, lon) {
    var step = 600000 * dir, t0 = fromMs, a0 = _altitude(t0, lat, lon) - HORIZON;
    for (var k = 0; k < 216; ++k) {
        var t1 = t0 + step, a1 = _altitude(t1, lat, lon) - HORIZON;
        if ((a0 < 0) !== (a1 < 0)) return t0 + (t1 - t0) * a0 / (a0 - a1);
        t0 = t1;
        a0 = a1;
    }
    return NaN;
}
/*
 * The moon's pass across the sky that `ms` (UTC) falls in, for the Detailed view's
 * arc: while it is up, the rise before and the set after; while it is down, the next
 * rise and the set after that. { up, riseMs, setMs }, a time NaN where none comes
 * within a day and a half (near the poles the moon can stay up, or down, for days).
 */
function pass(ms, lat, lon) {
    if (_altitude(ms, lat, lon) - HORIZON >= 0)
        return { up: true, riseMs: _crossing(ms, -1, lat, lon), setMs: _crossing(ms, 1, lat, lon) };
    var rise = _crossing(ms, 1, lat, lon);
    return { up: false, riseMs: rise, setMs: isNaN(rise) ? NaN : _crossing(rise + 60000, 1, lat, lon) };
}
