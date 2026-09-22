/*
 * MET Norway (met.no) provider adapter.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Data from MET Norway's Locationforecast 2.0 API (https://api.met.no/), free
 * and key-less under NLOD / CC BY 4.0. Their terms require THREE things of us,
 * all of them honoured here or in main.qml's fetch lifecycle:
 *   1. an identifying User-Agent (see userAgent below) — Qt's default
 *      "Mozilla/5.0" is exactly what they block;
 *   2. conditional requests (If-Modified-Since) rather than re-fetching before
 *      the response's Expires — main.qml does this for any provider that sets
 *      `conditional: true`;
 *   3. visible attribution — `attribution` below.
 * We also send coordinates truncated to 2 decimals (main.qml's coarseCoord),
 * which met.no asks for anyway to improve their cache hit rate.
 *
 * ── How this differs from Open-Meteo ─────────────────────────────────────
 * met.no's model is much rawer, so this adapter does real work rather than
 * renaming fields. In particular:
 *   · No WMO codes — a `symbol_code` string, mapped to WMO below so the icon
 *     packs, conditionText/conditionStem and precipAwareCode all keep working.
 *   · No timezone — everything is UTC. The location's offset arrives in
 *     ctx.utcOffsetSeconds (main.qml resolves it via Plasma's time engine).
 *   · No sunrise/sunset in this API — computed locally (solar.js) rather than
 *     spending one extra request per forecast day on their sunrise endpoint.
 *   · No apparent temperature — derived (Australian Apparent Temperature).
 *   · No snowfall — derived from precipitation on snow-coded hours at 10:1.
 *   · No daily aggregates — folded up from the hourly series here.
 *   · Hourly resolution runs out. Roughly the first 54 h carry next_1_hours;
 *     after that only 6-hourly blocks exist, so samples past that point carry
 *     spanHours: 6 and the views render them as blocks. MET also stops
 *     publishing UV index and wind gusts out there, so those come back NaN on
 *     6-hour samples — that is missing data, not a mapping gap, and the views'
 *     isNaN() guards already blank the readouts.
 * Every one of those is a genuine difference in what MET publishes, so the two
 * providers will not agree exactly — that is expected, not a bug.
 */
import QtQuick
import "solar.js" as Solar

QtObject {
    readonly property string providerId:     "metno"
    readonly property string displayName:    "MET Norway"
    readonly property string attribution:    i18n("Weather data from MET Norway (met.no)")
    readonly property string attributionUrl: "https://www.met.no/en"
    // Header source button: logo mark under contents/icons/providers/, and its
    // width:height, so the mark can be laid out at a set height without distortion.
    readonly property string logo:           "metno.svg"
    readonly property real   logoAspect:     16 / 24

    // Their terms require a UA that identifies the application and gives them a
    // way to make contact. Keep the version in step with metadata.json.
    readonly property string userAgent: "KlimeWeather/1.0.0 (+https://github.com/pku188/KlimeWeather)"
    readonly property var requestHeaders: [["User-Agent", userAgent]]

    // Ask the lifecycle for If-Modified-Since / Expires handling (met.no terms).
    readonly property bool conditional: true

    function buildUrl(ctx) {
        // `complete` rather than `compact`: compact omits UV index, gusts and
        // precipitation probability, three things the widget shows.
        return "https://api.met.no/weatherapi/locationforecast/2.0/complete"
             + "?lat=" + ctx.lat
             + "&lon=" + ctx.lon;
    }

    // ── symbol_code → WMO ────────────────────────────────────────────────
    // met.no's symbol vocabulary, mapped onto the WMO codes the rest of the
    // widget speaks. The mapping targets the BUCKETS conditionStem/conditionText
    // actually branch on (clear / partly / overcast / fog / sleet / rain /
    // snow / showers / thunder), so what matters is landing in the right bucket,
    // not matching WMO's exact intensity semantics.
    // Note sleet → 66: WMO has no "sleet", and 56/57/66/67 is the range
    // KlimeWeather renders with the sleet glyph. It is also the range
    // precipAwareCode deliberately exempts from its sub-freezing "must be snow"
    // rule, which is right for a genuine mixed-phase forecast.
    readonly property var symbolToWmo: ({
        "clearsky":           0,
        "fair":               1,
        "partlycloudy":       2,
        "cloudy":             3,
        "fog":               45,

        "lightrain":         61,
        "rain":              63,
        "heavyrain":         65,
        "lightrainshowers":  80,
        "rainshowers":       81,
        "heavyrainshowers":  82,

        "lightsleet":        66,
        "sleet":             66,
        "heavysleet":        67,
        "lightsleetshowers": 66,
        "sleetshowers":      66,
        "heavysleetshowers": 67,

        "lightsnow":         71,
        "snow":              73,
        "heavysnow":         75,
        "lightsnowshowers":  85,
        "snowshowers":       85,
        "heavysnowshowers":  86
    })

    // symbol_code is "<base>_<day|night|polartwilight>", and every thunder
    // variant ends in "andthunder" — strip both to reach the base above.
    // Anything with thunder goes to 95 regardless of its precipitation type,
    // since that is the only thunderstorm bucket the icon packs have.
    function codeFor(symbol) {
        if (!symbol) return -1;
        var base = symbol.split("_")[0];
        if (base.indexOf("andthunder") >= 0) return 95;
        var c = symbolToWmo[base];
        return (c === undefined) ? -1 : c;
    }

    // Does this symbol mean frozen precipitation? Drives the derived snowfall
    // below. Sleet is deliberately EXCLUDED — it is mostly liquid, and counting
    // it as snow would trip precipAwareCode's snow override on a mixed hour.
    function isSnowSymbol(symbol) {
        if (!symbol) return false;
        var base = symbol.split("_")[0];
        return base.indexOf("snow") >= 0;
    }

    // Severity ranking used to pick ONE representative code for a whole day, so a
    // daily glyph never looks milder than the hours it summarises: thunder, then
    // snow, sleet, rain, fog, overcast, and clear/partly cloudy last.
    function _severity(c) {
        if (c >= 95) return 6;                                        // thunderstorm
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return 5;   // snow
        if (c === 56 || c === 57 || c === 66 || c === 67) return 4;   // sleet
        if ((c >= 51 && c <= 65) || (c >= 80 && c <= 82)) return 3;   // rain
        if (c === 45 || c === 48) return 2;                           // fog
        if (c === 3) return 1;                                        // overcast
        return 0;                                                     // clear / partly
    }

    // ── units ────────────────────────────────────────────────────────────
    // Providers deliver °C and km/h; the user's units are applied once, for every
    // provider, in main.qml (convertUnits). met.no publishes °C and m/s, so only
    // the wind needs changing here.
    function _temp(c) {
        return (c === undefined || c === null || isNaN(c)) ? NaN : c;
    }
    function _kmh(ms) {
        return (ms === undefined || ms === null || isNaN(ms)) ? NaN : ms * 3.6;
    }

    // Australian Apparent Temperature (Steadman): the "feels like" the Bureau of
    // Meteorology publishes, and the closest well-defined stand-in for the field
    // met.no simply doesn't have. Works across the whole range rather than
    // switching between a heat index and a wind chill at arbitrary cutoffs.
    // Inputs metric, result metric — convert AFTER.
    function _apparentC(tempC, rh, windMs) {
        if (isNaN(tempC)) return NaN;
        var h = isNaN(rh) ? 50 : rh;                      // no humidity → assume middling
        var v = isNaN(windMs) ? 0 : windMs;
        var e = (h / 100) * 6.105 * Math.exp(17.27 * tempC / (237.7 + tempC));   // vapour pressure, hPa
        return tempC + 0.33 * e - 0.70 * v - 4.00;
    }

    function _n(v) { return (v === undefined || v === null) ? NaN : v; }

    function parse(text, ctx) {
        var data = JSON.parse(text);
        var ts = data.properties.timeseries;
        var off = ctx.utcOffsetSeconds;
        var out = { utcOffsetSeconds: off, current: null, daily: [], hourly: [] };
        if (!ts || !ts.length) return out;

        // ── hourly ───────────────────────────────────────────────────────
        // One sample per forecast block. next_1_hours while it exists, then
        // next_6_hours; entries with neither (the tail of the series) are
        // dropped — there is nothing to show for them.
        for (var i = 0; i < ts.length; ++i) {
            var e = ts[i];
            var det = (e.data && e.data.instant) ? e.data.instant.details : null;
            if (!det) continue;
            var b1 = e.data.next_1_hours;
            var b6 = e.data.next_6_hours;
            var blk = b1 || b6;
            if (!blk) continue;

            var span = b1 ? 1 : 6;
            var bd = blk.details || {};
            var symbol = (blk.summary && blk.summary.symbol_code) ? blk.summary.symbol_code : "";
            var ms = Date.parse(e.time);
            var localIso = Solar.toLocalIso(ms, off);

            var tempC  = _n(det.air_temperature);
            var rh     = _n(det.relative_humidity);
            var windMs = _n(det.wind_speed);
            var amt    = _n(bd.precipitation_amount);

            out.hourly.push({
                time:      localIso,
                date:      localIso.substring(0, 10),
                spanHours: span,
                temp:      _temp(tempC),
                feels:     _temp(_apparentC(tempC, rh, windMs)),
                code:      codeFor(symbol),
                // Day/night from the SAME solar model that produces the sunrise /
                // sunset markers, so an icon can never show a moon on the daylight
                // side of the marker. (symbol_code carries a _day/_night suffix
                // too, but it is met.no's own boundary, not ours.)
                day:       Solar.isDayAt(ctx.lat, ctx.lon, ms, off),
                humidity:  rh,
                uv:        _n(det.ultraviolet_index_clear_sky),   // clear-sky, as MET publishes it
                precip:    _n(bd.probability_of_precipitation),
                precipAmt: amt,
                // Derived snowfall: on a snow-coded block the precipitation is
                // falling as snow, and the conventional 10:1 fresh-snow ratio makes
                // mm of water = cm of snow exactly. 0 (not NaN) elsewhere, matching
                // what Open-Meteo returns for a dry or rainy hour.
                snow:      isSnowSymbol(symbol) ? amt : 0,
                cloud:     _n(det.cloud_area_fraction),
                wind:      _kmh(windMs),
                gust:      _kmh(_n(det.wind_speed_of_gust)),
                windDir:   (det.wind_from_direction === undefined) ? 0 : det.wind_from_direction,
                // MET publishes it in hPa already, which is the contract's unit
                pressure:  _n(det.air_pressure_at_sea_level),
                // 6-hour blocks publish their own extremes — better than the
                // instant reading when folding the day up below.
                _blockHi:  _temp(_n(bd.air_temperature_max)),
                _blockLo:  _temp(_n(bd.air_temperature_min))
            });
        }

        // ── daily ────────────────────────────────────────────────────────
        // met.no has no daily product, so fold the blocks up by LOCAL date.
        // Note day 0's high/low can only cover the hours still ahead — the series
        // starts at the current hour, so on a warm evening "today's high" will read
        // lower than Open-Meteo's, which knows the whole calendar day.
        var byDate = {};
        var order = [];
        for (var h = 0; h < out.hourly.length; ++h) {
            var s = out.hourly[h];
            var d = byDate[s.date];
            if (!d) {
                d = { date: s.date, code: -1, hi: NaN, lo: NaN,
                      snowSum: 0, precipSum: 0, precipChanceMax: NaN,
                      sunrise: "", sunset: "" };
                byDate[s.date] = d;
                order.push(s.date);
            }
            var hi = isNaN(s._blockHi) ? s.temp : Math.max(s.temp, s._blockHi);
            var lo = isNaN(s._blockLo) ? s.temp : Math.min(s.temp, s._blockLo);
            if (!isNaN(hi) && (isNaN(d.hi) || hi > d.hi)) d.hi = hi;
            if (!isNaN(lo) && (isNaN(d.lo) || lo < d.lo)) d.lo = lo;
            if (!isNaN(s.precipAmt)) d.precipSum += s.precipAmt;
            if (!isNaN(s.snow))      d.snowSum   += s.snow;
            if (!isNaN(s.precip) && (isNaN(d.precipChanceMax) || s.precip > d.precipChanceMax))
                d.precipChanceMax = s.precip;
            // `> severity` alone can never replace the -1 seed, because clear,
            // fair and partly-cloudy all rank 0 — a whole day of sunshine would
            // have kept the sentinel and rendered as a blank/cloudy day. Take the
            // first real code unconditionally, then upgrade on severity.
            if (d.code < 0 || _severity(s.code) > _severity(d.code)) d.code = s.code;
        }

        for (var k = 0; k < order.length && out.daily.length < ctx.forecastDays; ++k) {
            var day = byDate[order[k]];
            var sun = Solar.sunTimes(ctx.lat, ctx.lon, day.date, off);
            // Polar day / night: no crossing to mark, so leave the strings empty —
            // SimpleView already skips sun markers for a day with no times.
            day.sunrise = Solar.toLocalIso(sun.riseMs, off);
            day.sunset  = Solar.toLocalIso(sun.setMs,  off);
            out.daily.push(day);
        }

        // The block extremes were scratch space for the fold above — drop them so
        // what leaves here is exactly the documented model.
        for (var t = 0; t < out.hourly.length; ++t) {
            delete out.hourly[t]._blockHi;
            delete out.hourly[t]._blockLo;
        }

        // Trim hourly to the days we kept, so the two arrays can't disagree about
        // how far the forecast runs.
        if (out.daily.length) {
            var lastDate = out.daily[out.daily.length - 1].date;
            out.hourly = out.hourly.filter(function (s) { return s.date <= lastDate; });
        }

        // ── current ──────────────────────────────────────────────────────
        // met.no has no observation product; timeseries[0] is the analysis for the
        // current hour, which is what the widget's header wants anyway (heroCode
        // already prefers currentHourSample over this block).
        var c0 = ts[0];
        var cd = (c0.data && c0.data.instant) ? c0.data.instant.details : null;
        if (cd) {
            var cblk = c0.data.next_1_hours || c0.data.next_6_hours;
            var csym = (cblk && cblk.summary) ? cblk.summary.symbol_code : "";
            var cTempC = _n(cd.air_temperature);
            var cRh    = _n(cd.relative_humidity);
            var cWind  = _n(cd.wind_speed);
            out.current = {
                temperature:  _temp(cTempC),
                weatherCode:  codeFor(csym),
                apparentTemp: _temp(_apparentC(cTempC, cRh, cWind)),
                humidity:     cRh,
                isDay:        Solar.isDayAt(ctx.lat, ctx.lon, Date.parse(c0.time), off),
                uvIndex:      _n(cd.ultraviolet_index_clear_sky),
                precipRate:   (cblk && cblk.details) ? _n(cblk.details.precipitation_amount) : NaN,
                windSpeed:    _kmh(cWind),
                windGust:     _kmh(_n(cd.wind_speed_of_gust)),
                cloudCover:   _n(cd.cloud_area_fraction),
                pressure:     _n(cd.air_pressure_at_sea_level)
            };
        }

        return out;
    }
}
