/*
 * Sunrise / sunset for a coordinate and a local calendar date — no network.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Open-Meteo hands us sunrise/sunset in its response; met.no does NOT — its
 * sunrise API takes one date per request, so a 7-day forecast would cost seven
 * extra round trips per refresh. This computes them instead, from the standard
 * low-precision sunrise equation (NOAA / Astronomical Almanac). Accurate to
 * ~1 minute at temperate latitudes, which is well inside what the widget shows
 * (whole minutes) and how it uses them (day/night shading, sun markers).
 *
 * Used for providers that publish no sun times or day/night flag (met.no), and
 * by the hourly grid to re-derive day/night for hours expanded out of a 6-hour
 * block. Open-Meteo reports both itself, and those are used as published.
 */
.pragma library

var _RAD = Math.PI / 180;

// Sun's apparent altitude at rise/set: -0.833° accounts for refraction plus
// the solar disc's radius (the standard "upper limb touches the horizon").
var _ALTITUDE = -0.833;

function _jdFromMs(ms)  { return ms / 86400000 + 2440587.5; }
function _msFromJd(jd)  { return (jd - 2440587.5) * 86400000; }

/*
 * Sunrise/sunset for the local calendar date `dateStr` ("YYYY-MM-DD") at
 * lat/lon, where the location's clock is utcOffsetSeconds ahead of UTC.
 *
 * Returns { riseMs, setMs, polarDay, polarNight } with UTC epoch ms, or
 * riseMs/setMs NaN when the sun never crosses the horizon that day — polarDay
 * and polarNight say which, so callers can still resolve day/night above the
 * arctic circles instead of guessing.
 */
function sunTimes(lat, lon, dateStr, utcOffsetSeconds) {
    var p = dateStr.split("-");
    // Local noon expressed as UTC — anchoring on midday keeps us on the right
    // calendar day for every timezone, which midnight would not.
    var noonUtcMs = Date.UTC(+p[0], +p[1] - 1, +p[2], 12, 0, 0) - utcOffsetSeconds * 1000;

    var n = Math.round(_jdFromMs(noonUtcMs) - 2451545.0 + 0.0008);
    // Mean solar time at this longitude. East of Greenwich the sun transits
    // EARLIER in UT, hence the minus with east-positive longitude.
    var jStar = n - lon / 360;

    var M = (357.5291 + 0.98560028 * jStar) % 360;                       // solar mean anomaly
    var C = 1.9148 * Math.sin(M * _RAD)                                  // equation of the centre
          + 0.0200 * Math.sin(2 * M * _RAD)
          + 0.0003 * Math.sin(3 * M * _RAD);
    var lambda = (M + C + 180 + 102.9372) % 360;                         // ecliptic longitude

    var jTransit = 2451545.0 + jStar
                 + 0.0053 * Math.sin(M * _RAD)
                 - 0.0069 * Math.sin(2 * lambda * _RAD);

    var sinDec = Math.sin(lambda * _RAD) * Math.sin(23.4397 * _RAD);
    var cosDec = Math.cos(Math.asin(sinDec));

    var cosOmega = (Math.sin(_ALTITUDE * _RAD) - Math.sin(lat * _RAD) * sinDec)
                 / (Math.cos(lat * _RAD) * cosDec);

    // |cosOmega| > 1 → the sun stays entirely above (< -1) or below (> 1) the
    // horizon all day. Midnight sun and polar night are real cases for a
    // Norwegian data source, so name them rather than returning nothing.
    if (cosOmega < -1) return { riseMs: NaN, setMs: NaN, polarDay: true,  polarNight: false };
    if (cosOmega >  1) return { riseMs: NaN, setMs: NaN, polarDay: false, polarNight: true  };

    var omega = Math.acos(cosOmega) / _RAD;   // hour angle, degrees
    return {
        riseMs: _msFromJd(jTransit - omega / 360),
        setMs:  _msFromJd(jTransit + omega / 360),
        polarDay: false,
        polarNight: false
    };
}

/*
 * UTC epoch ms → the naive LOCAL ISO string the widget's model uses
 * ("2026-06-16T06:18"), seconds truncated. This is the same shape Open-Meteo
 * returns with timezone=auto, which is what timeline() and the hourly grid parse.
 */
function toLocalIso(ms, utcOffsetSeconds) {
    if (isNaN(ms)) return "";
    var d = new Date(ms + utcOffsetSeconds * 1000);
    function pad(v) { return (v < 10 ? "0" : "") + v; }
    return d.getUTCFullYear() + "-" + pad(d.getUTCMonth() + 1) + "-" + pad(d.getUTCDate())
         + "T" + pad(d.getUTCHours()) + ":" + pad(d.getUTCMinutes());
}

/*
 * Is `ms` (UTC epoch) daylight at this coordinate? 1 = day, 0 = night —
 * matching Open-Meteo's is_day, so the model field means the same thing
 * whichever provider filled it.
 */
function isDayAt(lat, lon, ms, utcOffsetSeconds) {
    var localDate = toLocalIso(ms, utcOffsetSeconds).substring(0, 10);
    var s = sunTimes(lat, lon, localDate, utcOffsetSeconds);
    if (s.polarDay)   return 1;
    if (s.polarNight) return 0;
    return (ms >= s.riseMs && ms < s.setMs) ? 1 : 0;
}
