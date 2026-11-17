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
 *
 * Also the sun's height at a moment (cosZenith), and the clear-sky UV index that
 * follows from it (clearSkyUv), for the hours met.no publishes no UV for.
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
 * Cosine of the sun's zenith angle at `ms` (UTC epoch) and this coordinate: 1 with
 * the sun overhead, 0 on the horizon, below 0 at night. The same low-precision solar
 * model as sunTimes, for the sun's height at one moment rather than its crossings.
 */
function cosZenith(lat, lon, ms) {
    var n = _jdFromMs(ms) - 2451545.0;
    var M = (357.5291 + 0.98560028 * n) % 360;                           // solar mean anomaly
    var C = 1.9148 * Math.sin(M * _RAD)                                  // equation of the centre
          + 0.0200 * Math.sin(2 * M * _RAD)
          + 0.0003 * Math.sin(3 * M * _RAD);
    var lambda = ((M + C + 180 + 102.9372) % 360) * _RAD;                // ecliptic longitude
    var eps = 23.4397 * _RAD;                                            // obliquity of the ecliptic
    var dec = Math.asin(Math.sin(lambda) * Math.sin(eps));               // declination
    var ra = Math.atan2(Math.cos(eps) * Math.sin(lambda), Math.cos(lambda));   // right ascension
    var gmst = (280.46061837 + 360.98564736629 * n) % 360;               // sidereal time, degrees
    var ha = (gmst + lon) * _RAD - ra;                                   // hour angle
    return Math.sin(lat * _RAD) * Math.sin(dec) + Math.cos(lat * _RAD) * Math.cos(dec) * Math.cos(ha);
}

/*
 * Clear-sky UV index — the UV a cloudless sky lets through — at a sun height of
 * `cosZ` (cosZenith): it follows the sun's height almost alone, as
 * scale · cos(zenith)^2.42 (Madronich's fit), `scale` carrying the ozone and the
 * altitude. 0 with the sun down.
 */
var UV_POWER = 2.42;
var UV_SCALE = 12.5;   // sea level, average ozone
function clearSkyUv(cosZ, scale) {
    return cosZ > 0 ? scale * Math.pow(cosZ, UV_POWER) : 0;
}

/*
 * The scale (see clearSkyUv) that best fits the clear-sky UV a forecast publishes —
 * `pairs` of [cosZ, uv], by least squares over the daytime ones — so an estimate
 * carries on from the published values: the location's ozone and altitude are in it.
 * Measured against met.no's own values it was 12 to 19, and the fit came within 0.05
 * UV on average. UV_SCALE when there is too little daylight in them to tell (polar
 * night).
 */
function clearSkyUvScale(pairs) {
    var sxy = 0, sxx = 0, n = 0;
    for (var i = 0; i < pairs.length; ++i) {
        var cz = pairs[i][0], uv = pairs[i][1];
        if (!(cz > 0.02) || isNaN(uv)) continue;   // the sun over ~1°: below, UV is all noise
        var f = Math.pow(cz, UV_POWER);
        sxy += uv * f;
        sxx += f * f;
        ++n;
    }
    if (n < 3 || !(sxx > 0)) return UV_SCALE;
    return Math.max(5, Math.min(30, sxy / sxx));
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
