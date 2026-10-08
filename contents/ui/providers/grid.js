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
 * Temperature (and feels) follow a monotone cubic curve (PCHIP) through the block
 * values: it passes exactly through every value the source gives and never goes
 * beyond the two it lies between, so it invents no highs or lows — but where the
 * source turns, it turns smoothly instead of in a corner. (Straight segments made a
 * 6-hourly day look like a row of cones.) Hourly stretches are all knots, so they
 * come through unchanged. Precipitation
 * and snowfall AMOUNTS are split evenly across the block's hours: they are totals
 * for the whole block, and holding a total on every hour counted it once per hour —
 * a 12 mm block read as 12 mm on six consecutive hours, 72 mm in all. Everything
 * else — code, precip chance, cloud, wind — is HELD across the block: a chance or a
 * condition is not divisible, and inventing intermediate values would fabricate
 * detail the forecast does not have. Each expanded point keeps the spanHours it
 * came from, so anything downstream can still tell real hours from stretched ones.
 *
 * Those are the values the graph PRINTS. For the rain curve it DRAWS, stretched hours
 * also get a smooth shape — the even split drew every rainy block as a flat box:
 *   - precipAmtCurve: the running total of the amounts follows a monotone cubic, and
 *     each hour takes the rise over its own hour. A block's hours still add up to
 *     exactly its total, none goes negative, and a dry block stays exactly dry (its
 *     running total is flat, so the curve through it is too) — a rainy block between
 *     dry ones becomes a hump instead of a box;
 *   - precipCurve: the chance, on a monotone cubic through the middle of each block.
 * main.qml's precipWashPct draws these in place of the printed values.
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
 * Slopes for a monotone cubic Hermite curve (Fritsch–Carlson, as in PCHIP) through
 * the samples' `key` values, at their own times (in hours, so uneven spacing — an
 * hourly run meeting a 6-hour block — is handled). A slope is 0 at every turning
 * point, which is what keeps the curve from overshooting a peak or a valley. NaN
 * where the value or a neighbour is missing; the caller then falls back to a line.
 */
function pchipSlopes(samples, key) {
    var x = [], y = [];
    for (var i = 0; i < samples.length; ++i) {
        x.push(new Date(samples[i].time).getTime() / 3600000);
        y.push(samples[i][key]);
    }
    return pchipSlopesXY(x, y);
}
// the same for any points: x in hours, y the values
function pchipSlopesXY(x, y) {
    var n = x.length, d = [], i;
    for (i = 0; i < n; ++i) d.push(NaN);
    // secant of each interval
    var sec = [];
    for (i = 0; i < n - 1; ++i)
        sec.push((y[i + 1] - y[i]) / (x[i + 1] - x[i]));
    for (i = 0; i < n; ++i) {
        if (isNaN(y[i])) continue;
        var a = i > 0 ? sec[i - 1] : NaN, b = i < n - 1 ? sec[i] : NaN;
        if (isNaN(a) && isNaN(b)) continue;
        if (isNaN(a) || isNaN(b)) { d[i] = isNaN(a) ? b : a; continue; }   // an end: one-sided
        if (a * b <= 0) { d[i] = 0; continue; }                            // a turn, or flat
        var h0 = x[i] - x[i - 1], h1 = x[i + 1] - x[i];
        var w1 = 2 * h1 + h0, w2 = h1 + 2 * h0;
        d[i] = (w1 + w2) / (w1 / a + w2 / b);                               // weighted harmonic mean
    }
    return d;
}

/*
 * The value a fraction `f` of the way from sample a to sample b, `hours` apart, on
 * the Hermite curve with slopes da, db (per hour). Straight line if a slope is
 * missing.
 */
function hermite(ya, yb, da, db, hours, f) {
    if (isNaN(da) || isNaN(db)) return ya + (yb - ya) * f;
    var f2 = f * f, f3 = f2 * f;
    return (2 * f3 - 3 * f2 + 1) * ya + (f3 - 2 * f2 + f) * hours * da
         + (-2 * f3 + 3 * f2) * yb + (f3 - f2) * hours * db;
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
    var tempSlope = pchipSlopes(allHourly, "temp"), feelsSlope = pchipSlopes(allHourly, "feels");
    // The rain curve's shape (see the top of this file). The running total is known at
    // the start of every sample and after the last one; the chance at each sample's
    // middle.
    var cumX = [], cumY = [], chX = [], chY = [], total = 0, m;
    for (m = 0; m < allHourly.length; ++m) {
        var sm = allHourly[m], hm = new Date(sm.time).getTime() / 3600000;
        var spm = sm.spanHours > 0 ? sm.spanHours : 1;
        cumX.push(hm);
        cumY.push(total);
        if (!isNaN(sm.precipAmt)) total += Math.max(0, sm.precipAmt);
        chX.push(hm + spm / 2);
        chY.push(sm.precip);
        if (m === allHourly.length - 1) { cumX.push(hm + spm); cumY.push(total); }
    }
    var cumSlope = pchipSlopesXY(cumX, cumY), chSlope = pchipSlopesXY(chX, chY);

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
                // the curve between this block and the next, in the hours they are apart
                var gap = (new Date(nxt.time).getTime() - t0) / 3600000;
                if (!isNaN(s.temp) && !isNaN(nxt.temp))
                    pt.temp = hermite(s.temp, nxt.temp, tempSlope[i], tempSlope[i + 1], gap, k / gap);
                if (!isNaN(s.feels) && !isNaN(nxt.feels))
                    pt.feels = hermite(s.feels, nxt.feels, feelsSlope[i], feelsSlope[i + 1], gap, k / gap);
            }
            if (span > 1) {
                // block totals → per-hour share, so the hours sum back to the block
                if (!isNaN(s.precipAmt)) pt.precipAmt = s.precipAmt / span;
                if (!isNaN(s.snow))      pt.snow      = s.snow / span;
                // the curve's share: the rise of the curved running total over this hour
                if (!isNaN(s.precipAmt)) {
                    var cw = cumX[i + 1] - cumX[i];
                    var c0 = hermite(cumY[i], cumY[i + 1], cumSlope[i], cumSlope[i + 1], cw, k / cw);
                    var c1 = hermite(cumY[i], cumY[i + 1], cumSlope[i], cumSlope[i + 1], cw, (k + 1) / cw);
                    pt.precipAmtCurve = Math.max(0, c1 - c0);
                }
                // the curve's chance, at the middle of this hour, between the middles of
                // the two samples around it
                if (!isNaN(s.precip)) {
                    var mid = t0 / 3600000 + k + 0.5;
                    var j = mid < chX[i] ? i - 1 : i;
                    if (j >= 0 && j + 1 < chX.length && !isNaN(chY[j]) && !isNaN(chY[j + 1])) {
                        var chw = chX[j + 1] - chX[j];
                        pt.precipCurve = hermite(chY[j], chY[j + 1], chSlope[j], chSlope[j + 1], chw, (mid - chX[j]) / chw);
                    }
                }
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
