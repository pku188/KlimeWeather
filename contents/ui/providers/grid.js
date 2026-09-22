/*
 * Uniform hourly grid — the graph's data source.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 *
 * The graph is a CURVE: it needs evenly spaced points, and its sun-marker
 * x-mapping derives the step from samples[1] − samples[0], so a series that
 * silently changes resolution partway would misplace every marker after the
 * change. But the hourly model is NOT uniform under met.no — roughly the first
 * 54 h are hourly, then it drops to 6-hour blocks (see spanHours in the provider
 * contract). The CARD layout renders those blocks as blocks, which is honest at
 * that range; the graph instead expands them onto a 1-hour grid here.
 *
 * Temperature (and feels) interpolate linearly toward the next block, since a
 * straight segment is exactly what a 6-hourly source claims to know. Precipitation
 * and snowfall AMOUNTS are split evenly across the block's hours: they are totals
 * for the whole block, and holding a total on every hour counted it once per hour —
 * a 12 mm block read as 12 mm on six consecutive hours, 72 mm in all. Everything
 * else — code, precip chance, cloud, wind — is HELD across the block: a chance or a
 * condition is not divisible, and inventing intermediate values would fabricate
 * detail the forecast does not have. Each expanded point keeps the spanHours it
 * came from, so anything downstream can still tell real hours from stretched ones.
 *
 * Open-Meteo is hourly the whole way out, so for it this is a copy.
 *
 * Kept as a pure function over explicit inputs — no widget state — so it can be
 * exercised directly against real provider output.
 */
.pragma library

function _pad(v) { return (v < 10 ? "0" : "") + v; }

/*
 * A Date in the LOCATION's wall clock → the naive local ISO string the model
 * uses ("2026-06-16T14:00"). new Date(h.time) parses in that same frame, so
 * round-tripping through here is exact.
 */
function localIso(d) {
    return d.getFullYear() + "-" + _pad(d.getMonth() + 1) + "-" + _pad(d.getDate())
         + "T" + _pad(d.getHours()) + ":" + _pad(d.getMinutes());
}

/*
 * Day/night for an expanded hour, from that day's sunrise/sunset. Falls back to
 * the parent block's flag when the day has no sun times — polar day or polar
 * night, where the block's own flag is already the right answer.
 */
function dayAtLocal(dailyData, d, fallback) {
    var date = localIso(d).substring(0, 10);
    for (var i = 0; i < dailyData.length; ++i) {
        if (dailyData[i].date !== date) continue;
        var sr = dailyData[i].sunrise, ss = dailyData[i].sunset;
        if (!sr || !ss) return fallback;
        var t = d.getTime();
        return (t >= new Date(sr).getTime() && t < new Date(ss).getTime()) ? 1 : 0;
    }
    return fallback;
}

/*
 * allHourly (mixed spans) → a contiguous 1-hour series covering `days` forecast
 * days from `nowMs` (the location's "now", i.e. locNow().getTime()).
 */
function build(allHourly, dailyData, days, nowMs) {
    if (!allHourly || !allHourly.length) return [];
    var n = Math.min(days, dailyData.length);
    var cutoff = n > 0 ? dailyData[n - 1].date : "";
    var out = [];

    for (var i = 0; i < allHourly.length; ++i) {
        var s = allHourly[i];
        var span = s.spanHours > 0 ? s.spanHours : 1;
        // Interpolate toward the NEXT block even when that block belongs to a day
        // we are about to drop — otherwise the last hours of the final day would
        // flatten out for want of an endpoint. The trim happens below, on the
        // expanded points, so the leaked block shapes the tail without being shown.
        var nxt = (i + 1 < allHourly.length) ? allHourly[i + 1] : null;
        var t0 = new Date(s.time).getTime();

        for (var k = 0; k < span; ++k) {
            var f = span > 1 ? k / span : 0;
            var pt = Object.assign({}, s);
            if (k > 0) {
                var d = new Date(t0 + k * 3600000);
                pt.time = localIso(d);
                pt.date = pt.time.substring(0, 10);
                // day/night can flip inside a 6-hour block, so re-derive it per hour
                // rather than smearing the block's flag across a sunrise
                pt.day = dayAtLocal(dailyData, d, s.day);
            }
            if (nxt && span > 1) {
                if (!isNaN(s.temp)  && !isNaN(nxt.temp))  pt.temp  = s.temp  + (nxt.temp  - s.temp)  * f;
                if (!isNaN(s.feels) && !isNaN(nxt.feels)) pt.feels = s.feels + (nxt.feels - s.feels) * f;
            }
            if (span > 1) {
                // block totals → per-hour share, so the hours sum back to the block
                if (!isNaN(s.precipAmt)) pt.precipAmt = s.precipAmt / span;
                if (!isNaN(s.snow))      pt.snow      = s.snow / span;
            }
            pt.spanHours = span;   // provenance: >1 means this hour was stretched
            out.push(pt);
        }
    }

    // Drop hours already past, so the graph opens near the current time, and
    // anything beyond the requested day span (including the leaked tail block) —
    // except for ONE closing hour.
    //
    // The graph's day window is inclusive at both ends: 24 hours means 25 points,
    // 20:00 through 20:00. Without a sample one hour past the last day, the final
    // window has nothing to close on and comes up an hour short. That one extra
    // sample is only ever the right-hand endpoint; it is never a day the view
    // presents as its own.
    var kept = [];
    for (var j = 0; j < out.length; ++j) {
        var h = out[j];
        if (new Date(h.time).getTime() + 3600000 < nowMs) continue;   // already gone
        kept.push(h);
        if (cutoff !== "" && h.date > cutoff) break;                  // the closing endpoint
    }
    return kept;
}
