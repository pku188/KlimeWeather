/*
 * Simple (graph) representation — a compact header plus a graph over ONE
 * continuous forward timeline (from now): a smooth temperature curve with an
 * area fill, a precipitation-chance band, per-point value labels, hour icons and
 * a time axis. A sliding window (`hourPos`) pans the icons/time/markers while the
 * curve RESHAPES in fixed columns; the timeline flows across midnight with
 * correctly-dated new-day markers. The zoom (`graphZoom`: 12 / 24 / 48 hours) only
 * sets the window width and how sparsely it is labelled. Free drag/scroll slides;
 * tapping a day pill cross-fades the curve to that day (`dayMorphT`). Ported from
 * the MorphCurve design (quadratic ease-in-out tween).
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "wheel.js" as Wheel

Item {
    id: simple

    property var weatherRoot

    // Animated icons are built only once the popup has been opened and the curve
    // has risen into shape: until then the static icons show, which look the same
    // at rest, so neither the first frame nor the reveal waits on building them.
    // Stays true — built icons are kept and just hold still while the popup is closed.
    property bool iconsLive: false
    Timer {
        id: iconsLiveTimer
        interval: revealAnim.duration + 50
        onTriggered: if (simple.onScreen && simple.visible) simple.iconsLive = true
    }

    // `hourPos` is the left-edge position (in sample-index units) of the sliding
    // window over the continuous timeline; the columns stay fixed and the curve
    // RESHAPES in place as the window slides — see loSamples/hiSamples below.
    property real hourPos: 0
    // A day-pill click morphs the curve IN PLACE from the current shape to the
    // target day's shape (dayMorphT 0→1, columns held fixed) while the window
    // scrolls there. 1 = settled → curve follows the window.
    property real dayMorphT: 1
    property var morphFromT: []
    property var morphFromP: []
    property var morphFromS: []
    property var morphFromA: []
    property var morphToT: []
    property var morphToP: []
    property var morphToS: []
    property var morphToA: []
    // 0/1 per column: does that column's hour carry a real chance of precipitation?
    // Snapshotted with the rest so the % label's visibility can morph too.
    property var morphFromC: []
    property var morphToC: []
    // global sample index of column 0 in the from / to snapshots (for the 48-hour
    // readout plan, which is keyed on the hour)
    property int morphFromBase: 0
    property int morphToBase: 0
    property bool dragging: false
    // The highlighted day. Normally the day at the start of the window (leadDay), but
    // a day picked from the pills wins (chosenDay): at 48 hours the window cannot pan
    // far enough for the LAST day to start it, so tracking the window alone would keep
    // the day before highlighted, with its totals and sun times in the header. Any
    // scroll of the graph itself hands the selection back to the window.
    property int chosenDay: -1
    readonly property int selectedDay: (chosenDay >= 0 && chosenDay < dayCount) ? chosenDay : leadDay
    readonly property int leadDay: {
        if (!weatherRoot || !weatherRoot.dailyData || !samples.length) return 0;
        // the day at the START of the window (where you actually are) — using the
        // window centre rounds onto tomorrow once the 13h window crosses midnight,
        // so at 5 PM today it would wrongly highlight tomorrow's tab
        var c = Math.max(0, Math.min(samples.length - 1, Math.round(hourPos)));
        var date = samples[c].date;
        for (var d = 0; d < dayCount; ++d)
            if (weatherRoot.dailyData[d] && weatherRoot.dailyData[d].date === date) return d;
        return 0;
    }
    // The focused hour's sample (the one at the START of the window — where you
    // actually are). Drives instantaneous header metrics (humidity) so they sync
    // to the scrolled hour, the way the daily-total metrics sync to selectedDay.
    // Sample under the pointer while it is over the graph (the plot, the icon row
    // and the time axis — not the header above them). The card layout's header
    // metrics follow the hovered CARD; this gives the graph the same behaviour,
    // scrubbing by pointer instead of by scroll position. null when not hovering,
    // so the readouts fall back to focusedSample below.
    // Resolution is per HOUR regardless of zoom: samples are hourly even in the
    // day view where only every second hour carries a label, so the hours between
    // labels scrub too.
    property var hoveredSample: null
    function sampleAtX(px) {
        if (!samples.length || plotW <= 0) return null;
        // inverse of hourX(): x = (g - hourPos + 0.5) * (plotW / pointsVisible)
        var g = Math.round(px * pointsVisible / plotW - 0.5 + hourPos);
        if (g < 0 || g >= samples.length) return null;
        return samples[g];
    }

    readonly property var focusedSample: {
        if (!samples.length) return null;
        var c = Math.max(0, Math.min(samples.length - 1, Math.round(hourPos)));
        return samples[c];
    }

    readonly property int pad: Math.round(Kirigami.Units.gridUnit * 0.85)
    readonly property string precipColor: "#42a5f5"
    readonly property string snowLabelColor: "#d8ecff"   // pale icy blue for snow cm labels
    readonly property string sunGold: "#ffa840"          // warm amber of the sunset glyph + its time label
    readonly property string sunRiseColor: "#f8c01c"     // sunrise gold, nudged slightly toward yellow from the glyph's #f8af18 — sunrise time label + bloom share it

    // ── Sun bloom: a soft radial glow that rises off the temp line where it
    // crosses a sunrise or sunset, clipped to the area ABOVE the curve so it
    // never spills below. Two-tone — sunrise is the gold of its icon (#f8af18,
    // #fbbf24 hot core), sunset orange.
    // Ported from a Claude-design SVG (radialGradient + clip + blurred streak)
    // to Canvas 2D: the radial is an ellipse via ctx.scale, the streak is a
    // stack of wide low-alpha strokes (Canvas has no feGaussianBlur). Colours
    // are RGB triples; alphas come from the *Alpha tunables below so "soft" can
    // be dialled in one place. core = on the line, mid = the body, streak = the
    // glow laid along the line itself.
    readonly property var sunGlow: ({
        "rise": { core: [252, 208,  46], mid: [248, 192,  28], streak: [248, 192,  28] },
        "set":  { core: [255, 205, 120], mid: [255, 145,  62], streak: [255, 154,  68] }
    })
    readonly property real sunGlowCoreA:   0.62   // brightest (on the line) — softened from the design's .97
    readonly property real sunGlowFeather: 3.5    // radial falloff exponent: alpha = coreA·exp(−feather·r²). Higher = softer, more feathered rim; lower = a fuller, more defined glow
    readonly property real sunGlowStreakA: 0.45   // peak alpha of the line streak
    // Horizontal radius of the radial bloom, in curve columns (feathering keeps a
    // soft edge instead of wedging on a slope). Tuned per zoom: the same width in
    // columns reads as a far bigger smear once a screen holds 49 hours instead of
    // 13, so the wider views take proportionally less.
    readonly property real sunGlowHalfCols: (zoom === 0 ? 1.4 : zoom === 1 ? 1.0 : 0.7) * densityScale
    readonly property real sunGlowRiseIcons: 1.2  // vertical reach upward, in sun-glyph heights (≤1 keeps the glow no taller than the icon)
    // Half-width of the warm streak ALONG the line, in columns. 0 = off, and off is
    // the default: the streak is a wide stroke CENTRED on the curve, so half of it
    // always fell BELOW the line, which read as a smudge under the curve rather
    // than a glow on it. Raise it (2.2 was the old width) to bring it back.
    readonly property real sunStreakHalfCols: 0 * densityScale

    // ── Temperature → colour gradient: cold blue → cool teal → mild green →
    // warm amber → hot orange-red. The line and band are tinted per hour by how
    // hot it is.
    readonly property var tempRamp: [
        [0.0,  [86, 148, 213]],   // cold blue
        [0.35, [104, 188, 191]],  // cool teal
        [0.55, [134, 192, 143]],  // mild green
        [0.78, [232, 176, 74]],   // warm amber
        [1.0,  [226, 104, 63]]    // hot orange-red
    ]
    readonly property real bandAlpha: 0.38   // opacity of the gradient band fill

    // graph colouring toggle (config graphColorMode): 0 = both, 1 = temp only,
    // 2 = precip only, 3 = none. When a series is "off" it falls back to a flat
    // neutral (theme-grey) instead of its colour.
    readonly property int  colorMode:   weatherRoot ? weatherRoot.graphColorMode : 0
    // 4 colours the precipitation and the temperature LINE but leaves the
    // temperature wash neutral, so the curve reads warm over a quiet background.
    readonly property bool colorTempLine: colorMode === 0 || colorMode === 1 || colorMode === 4
    readonly property bool colorTempBand: colorMode === 0 || colorMode === 1
    readonly property bool colorPrecip:   colorMode === 0 || colorMode === 2 || colorMode === 4
    // Which halves of a precipitation readout print (config precipLabelMode, a bit
    // pair): 1 = the chance %, 2 = the snow / rain amount. Hiding one does not change
    // which hours qualify or how the 24- and 48-hour spells are thinned; it can only let
    // neighbours merge, where they now print the same thing (see readoutPlan).
    readonly property bool showPrecipPct: !weatherRoot || (weatherRoot.precipLabelMode & 1) !== 0
    readonly property bool showPrecipAmt: !weatherRoot || (weatherRoot.precipLabelMode & 2) !== 0

    // ── Graph data & geometry ─────────────────────────────────────────────
    // Zoom (toolbar + / −): 0 = 12 hours, 1 = 24 hours, 2 = 48 hours.
    readonly property int zoom: weatherRoot ? weatherRoot.graphZoom : 1
    // The graph is ONE continuous forward timeline (from now) for both detail
    // levels — so it flows across midnight: after tonight's 10 PM comes 12 AM with
    // a correctly-dated "new day" marker, no seam, no overlap, no missing hours.
    // The detail level only changes timeline DENSITY + window width.
    // Hourly = every hour. Every-2h = even-hour points only, folding the skipped
    // odd hour's MAX precip into each 2h cell so an odd-hour spike isn't lost.
    // Rough "how wet is this condition" rank for a WMO code, so a 2h cell can show
    // the wetter of its two hours' ICONS (rain often lands on the odd hour we skip,
    // which otherwise leaves a high chance next to a dry cloud icon).
    // The curve is ALWAYS hourly. It used to be decimated to every second hour in
    // the default mode, which threw away half the data the provider had already
    // sent — the axis showed a 2-hour scale, so the curve was drawn at a 2-hour
    // scale too. Those are separate concerns: the axis is about how many labels
    // fit, the curve about how much shape it can show. `hourlyGrid` also flattens
    // met.no's 6-hour blocks onto the same 1-hour spacing, which the sun-marker
    // x-mapping requires.
    readonly property var samples: weatherRoot ? weatherRoot.hourlyGrid(simple.dayCount) : []
    readonly property int dayCount: weatherRoot ? weatherRoot.graphDays : 0

    // Sliding window width, in POINTS. Every zoom is inclusive at both ends, so a
    // span of N hours needs N+1 points: 25 covers a full day (20:00 through 20:00
    // the next day, the last label a whole 24 h after the first), 13 covers 12 h and
    // 49 covers 48 h. A 24-point window ended one label short — 20:00 to 18:00 — which
    // read as the day being clipped rather than framed. The data reaches one hour past
    // the last day (see grid.js), so even the 48-hour window from the second day's
    // midnight closes on a real point.
    readonly property int pointsVisible: zoom === 0 ? 13 : zoom === 1 ? 25 : 49
    // Draw a time label / icon every Nth sample: every hour at 12 hours, every second
    // at 24 and every fourth at 48, so each zoom shows about the same number of labels.
    // Keyed on the GLOBAL sample index, so a label belongs to a fixed hour and doesn't
    // flip parity as the strip scrolls past.
    readonly property int labelStride: zoom === 0 ? 1 : zoom === 1 ? 2 : 4
    function isLabelled(g) { return g >= 0 && (g % labelStride) === 0; }
    // Several constants below (scroll velocity, sun-bloom width) are expressed in
    // CURVE COLUMNS, and were tuned when one screen was ~12 columns. Now that the
    // curve is hourly a screen can be 24, which would silently halve a wheel notch
    // and shrink the sun bloom to half its width — same numbers, twice the columns.
    // Scaling by the density keeps them fixed in TIME and in screen fraction, which
    // is what they were really describing.
    readonly property real densityScale: pointsVisible / 12
    // Hours moved per mouse-wheel notch, configurable per zoom level (Appearance →
    // Graph). The defaults are a quarter of each zoom's visible window, which is
    // what the previous fixed step worked out to.
    readonly property int scrollHours: zoom === 0 ? (weatherRoot ? weatherRoot.graphScrollHoursDetail : 3)
                                     : zoom === 1 ? (weatherRoot ? weatherRoot.graphScrollHoursDay    : 6)
                                     :              (weatherRoot ? weatherRoot.graphScrollHoursWide   : 12)
    // How long that notch takes to arrive, also per zoom (Appearance → Graph).
    // It needs its own setting because the step alone doesn't decide how the scroll
    // FEELS: one notch covers a quarter of the window at 12 hours and can cover half
    // of it at 48, so a duration that reads as a gentle glide in the narrow view
    // reads as a lurch in the wide one.
    readonly property int slideMs: zoom === 0 ? (weatherRoot ? weatherRoot.graphSlideMsDetail : 350)
                                 : zoom === 1 ? (weatherRoot ? weatherRoot.graphSlideMsDay    : 450)
                                 :              (weatherRoot ? weatherRoot.graphSlideMsWide   : 800)
    readonly property int maxHourPos: Math.max(0, (samples ? samples.length : 0) - pointsVisible)
    // A zoom change alters the window width, which can leave the window running past
    // the end of the data. Keep its start, clamped to the new range — or, when a day
    // was picked, re-open that day at the new width (so zooming in from 48 hours with
    // the last day picked shows that day, not the one before it).
    // (The limit is worked out here rather than read from maxHourPos: this handler can
    // run before that binding has caught up with the new width.)
    onPointsVisibleChanged: {
        posAnim.stop(); cancelDayMorph();
        var max = Math.max(0, (samples ? samples.length : 0) - pointsVisible);
        var want = chosenDay >= 0 ? dayFirstSampleIndex(chosenDay) : Math.round(hourPos);
        hourPos = Math.max(0, Math.min(max, want));
    }
    function windowAt(w) {
        var o = [], n = samples.length;
        for (var i = 0; i < pointsVisible; ++i) {
            var idx = w + i;
            if (idx >= 0 && idx < n) o.push(samples[idx]);
        }
        return o;
    }
    // Sliding filmstrip (icons / time / markers PAN with the scroll, unlike the
    // curve which reshapes in fixed columns). A small FIXED pool of delegates
    // recycles: delegate `index` shows global sample `windowBase + index - 1`
    // (one off-left for buffer), positioned continuously by hourX(g). `windowBase`
    // is the INTEGER hour, so a delegate's *content* only changes once per hour
    // while its *x* slides every frame — smooth, and never rebuilt.
    readonly property int  windowBase: Math.floor(hourPos)
    readonly property int  poolSize:   pointsVisible + 3
    function hourX(g) { return (g - hourPos + 0.5) * (plotW / pointsVisible); }
    // a sample STARTS a new day when its date differs from the previous sample's.
    // Works for both hourly (midnight IS a sample) and every-2h (when "now" is odd, no
    // sample lands exactly on hour 0, so an hour-0 test would MISS the rollover and the
    // new-day divider would vanish). g <= 0 is the leading edge, never a day-start.
    function isDayStart(g) {
        return g > 0 && g < samples.length && samples[g].date !== samples[g - 1].date;
    }
    // Global sample indices of the midnights inside the window (plus a marker's
    // width either side of the pool: a marker is ready before it slides in, and one
    // its line is carrying off the plot is still partly on screen after the line
    // itself has gone — see dayMarkerX). Three or four at 48 hours, one or two at
    // 12 — which is why the new-day markers get their own small model instead of a
    // slot per hour like the filmstrip pools: each marker carries a dash run, and
    // holding 52 of those to draw 3 was the single most expensive thing in
    // building the graph.
    //
    // The LENGTH only changes when a midnight enters or leaves (twice per day of
    // scrolling), and a Repeater over a JS array recreates its delegates only when
    // the length changes — so scrolling reuses the same few items.
    // The filmstrip's icons and clock labels only appear on LABELLED hours — every
    // hour at 12, every 2nd at 24, every 4th at 48 (see isLabelled) — so they get a
    // pool of that many rather than one slot per hour. Before this, 48 hours built
    // 52 icon slots to draw 13 of them.
    //
    // Indexing is stride-aligned (`filmBase` is a multiple of labelStride) so the
    // COUNT never changes as the window slides, only each delegate's hour. An int
    // model that holds its value keeps the same delegates alive across a scroll;
    // a count that ticked up and down would rebuild them all every hour.
    readonly property int filmBase:  Math.floor((windowBase - 1) / labelStride) * labelStride
    readonly property int filmCount: Math.floor(poolSize / labelStride) + 3
    function filmG(i) { return filmBase + i * labelStride; }

    readonly property var dayStartsInWindow: {
        var out = [];
        var extra = Math.ceil(2 * dayMarkerHalfW / (plotW / pointsVisible));
        for (var k = -1 - extra; k <= poolSize + extra; ++k)
            if (isDayStart(windowBase + k)) out.push(windowBase + k);
        return out;
    }
    // the two window frames the position sits between + the blend. Keyed on the
    // INTEGER hour so they only re-allocate when the window actually shifts (once
    // per hour), not every drag frame — only the scalar curFrac changes per frame,
    // which is what drives the smooth in-column reshape.
    readonly property int  hourFloor: Math.floor(hourPos)
    readonly property int  hourCeil:  Math.ceil(hourPos)
    readonly property real curFrac:   hourPos - hourFloor
    readonly property var  loSamples: windowAt(hourFloor)
    readonly property var  hiSamples: windowAt(hourCeil)

    // interpolate two equal-length column arrays (drives the day-tab morph)
    function lerpArr(a, b, t) {
        var o = [], n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = i < a.length ? a[i] : 0, bv = i < b.length ? b[i] : av;
            o.push(av + (bv - av) * t);
        }
        return o;
    }

    // Curve values: the sliding-window reshape between loSamples/hiSamples (above).
    readonly property var curTemps: {
        // a day-tab click morphs the held from→to columns in place
        if (dayMorphT < 1) return lerpArr(morphFromT, morphToT, dayMorphT);
        var a = loSamples, b = hiSamples, f = curFrac, out = [];
        var n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = i < a.length ? a[i].temp : (i < b.length ? b[i].temp : 0);
            var bv = i < b.length ? b[i].temp : av;
            out.push(av + (bv - av) * f);
        }
        return out;
    }
    // Rain WASH per column on the 0-100 chance scale — what the precip band is drawn
    // from, and the silhouette the readouts and markers ride above. Where an hour has
    // a real chance this IS that chance, unchanged; where it has none (met.no outside
    // the Nordics) the amount stands in, so the band still shows the rain. The printed
    // % must not come from here blindly — see curChanceOn.
    readonly property var curPrecip: {
        if (dayMorphT < 1) return lerpArr(morphFromP, morphToP, dayMorphT);
        var a = loSamples, b = hiSamples, f = curFrac, out = [];
        var n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = (i < a.length && weatherRoot) ? weatherRoot.precipWashPct(a[i]) : 0;
            var bv = (i < b.length && weatherRoot) ? weatherRoot.precipWashPct(b[i]) : 0;
            out.push(av + (bv - av) * f);
        }
        return out;
    }
    // 0/1 per column: whether the hour NEAREST the slot has a real chance. Gates the
    // printed % — curPrecip alone can't, because for an hour without a chance it holds
    // an amount-derived stand-in, and printing that would claim a probability the
    // provider never gave (the old code printed it as a flat "0%"). Nearest-hour, the
    // same rule the other readouts use to decide visibility.
    readonly property var curChanceOn: {
        if (dayMorphT < 1) return dayMorphT < 0.5 ? morphFromC : morphToC;
        var arr = curFrac < 0.5 ? loSamples : hiSamples, out = [];
        for (var i = 0; i < arr.length; ++i)
            out.push(weatherRoot && weatherRoot.hasPrecipChance(arr[i]) ? 1 : 0);
        return out;
    }
    // Per-point "snowiness" 0..1 (blended through the morph) graded by the
    // forecast snowfall AMOUNT, so the precip band tints toward white in
    // proportion to how heavy the snow is (not a binary rain/snow flag).
    // The band is the dominant element on screen, so ANY real snow must read
    // clearly white — not just a blizzard. snowiness() rises fast from the first
    // flake (≈70% white by snowWhiteCm) and saturates by ~4×, so light all-day
    // snow no longer looks like rain-blue; heaviness still modulates within white.
    readonly property real snowWhiteCm: 0.5   // cm/hr that already reads ~70% white
    function snowiness(cm) {
        if (!(cm > 0)) return 0;
        return Math.min(1, 1 - Math.exp(-cm / (snowWhiteCm * 0.83)));
    }
    function snowCm(s) { return (s && !isNaN(s.snow)) ? Math.max(0, s.snow) : 0; }
    // curSnow carries the raw cm/hour per column (blended through the morph): the
    // band tint derives its 0..1 "snowiness" from it, and the snow labels read it.
    readonly property var curSnow: {
        if (dayMorphT < 1) return lerpArr(morphFromS, morphToS, dayMorphT);
        var a = loSamples, b = hiSamples, f = curFrac, out = [];
        var n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = i < a.length ? snowCm(a[i]) : 0;
            var bv = i < b.length ? snowCm(b[i]) : 0;
            out.push(av + (bv - av) * f);
        }
        return out;
    }
    function precipMm(s) { return (s && !isNaN(s.precipAmt)) ? Math.max(0, s.precipAmt) : 0; }
    // curPrecipAmt carries the raw mm/hour per column (blended through the morph),
    // so the amount readout above each chance label morphs in place like the others.
    readonly property var curPrecipAmt: {
        if (dayMorphT < 1) return lerpArr(morphFromA, morphToA, dayMorphT);
        var a = loSamples, b = hiSamples, f = curFrac, out = [];
        var n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = i < a.length ? precipMm(a[i]) : 0;
            var bv = i < b.length ? precipMm(b[i]) : 0;
            out.push(av + (bv - av) * f);
        }
        return out;
    }
    // ── Delayed value-label morph (temp numbers) ──────────────────────────
    // On a flick / wheel-notch the temp VALUE labels trail the curve: the number is
    // held for lblMorphDelay ms, then ticks to the new value, finishing a beat after
    // the curve settles. The label POSITION still rides the LIVE curve (curTempY), so
    // labels never detach — only the shown number lags. Inline (not a helper fn) so the
    // binding captures lblMorphT / lblMorphActive as dependencies (see the Repeater-
    // model gotcha: deps read only inside a called fn aren't tracked).
    property real lblMorphT: 1
    readonly property bool lblMorphActive: lblMorphAnim.running
    readonly property var lblTemps: {
        if (lblMorphActive) return lerpArr(morphFromT, morphToT, lblMorphT);
        return curTemps;
    }
    // ── which hours get a temperature label ──────────────────────────────
    // Fixed positions, never recomputed from the values. An earlier version
    // collapsed runs of equal temperature into one centred label; the centre of a
    // run depends on the values, so every scroll and day-morph re-derived it and
    // the labels visibly drifted before settling. Position now depends only on the
    // HOUR, so a label either is or isn't there — nothing to animate into place.
    //
    // Base rule: the same hours the time axis labels, so the two rows line up.
    // isLabelled() is keyed on the GLOBAL sample index, exactly as the axis pool
    // is, and curve column i holds global sample (windowBase + i) — so at rest the
    // temperature sits directly above its own clock label.
    //
    // Plus the day's extremes: with a 2-hourly rule the actual high or low can fall
    // on an unlabelled hour and never be shown. Each is added back at EVERY hour it
    // occurs — but only if that value isn't already printed by a regular label
    // somewhere in the day, since then it is on screen anyway and the extras would
    // just be duplicates. High and low are judged independently.
    //
    // Both the extremes and their coverage are computed over the WHOLE series, per
    // calendar day, so the answer doesn't change as you scroll.
    readonly property var tempExtremes: {
        var out = ({});
        if (!samples || !samples.length) return out;
        var i, s, v, e;
        for (i = 0; i < samples.length; ++i) {
            s = samples[i];
            if (isNaN(s.temp)) continue;
            v = Math.round(s.temp);
            e = out[s.date];
            if (!e) out[s.date] = { hi: v, lo: v, hiCovered: false, loCovered: false };
            else { if (v > e.hi) e.hi = v; if (v < e.lo) e.lo = v; }
        }
        // second pass, once the extremes are known: is either already printed?
        for (i = 0; i < samples.length; ++i) {
            if (!isLabelled(i)) continue;
            s = samples[i];
            if (isNaN(s.temp)) continue;
            e = out[s.date];
            if (!e) continue;
            v = Math.round(s.temp);
            if (v === e.hi) e.hiCovered = true;
            if (v === e.lo) e.loCovered = true;
        }
        return out;
    }
    // Which hour a column is treated as holding, FOR LABEL PLACEMENT ONLY.
    //
    // windowBase is floor(hourPos), so it steps through every intermediate hour of
    // a pan. With the 2-hourly rule that flips which columns are labelled on each
    // one, and the labels blinked on and off several times per notch. Detail zoom
    // never showed it because stride 1 labels every column, so nothing can flip.
    //
    // Resolving against the pan's DESTINATION instead means the labelled columns are
    // chosen once, when the scroll starts, and then hold still while their values
    // morph — which is precisely what makes Detail zoom read as smooth. A drag holds
    // the parity it began with, for the same reason.
    property int dragLabelBase: 0
    readonly property int labelBase: {
        if (posAnim.running)   return Math.round(posAnim.to);
        if (flickAnim.running) return Math.round(flickAnim.to);
        if (dragging)          return dragLabelBase;
        return windowBase;
    }

    // Whether each sample gets a temperature label: the axis hours plus the day's
    // uncovered extremes (see tempExtremes). Worked out once per data/zoom change over
    // the whole series, never per scroll, so a label's presence stays fixed to its hour.
    //
    // At 48 hours a column is only about as wide as a label, so two extra rules keep
    // labels from printing over each other there (at 12 and 24 hours they have room,
    // and nothing changes):
    //  • a run of consecutive hours at the same extreme gets ONE label, in its middle,
    //    instead of one per hour;
    //  • an extreme outranks an axis-hour label in the column next to it — the high or
    //    low is the reading worth keeping.
    readonly property var tempLabelMap: {
        var n = samples ? samples.length : 0, on = [], ext = [], i, j, k, s, e, v;
        for (i = 0; i < n; ++i) {
            s = samples[i];
            on.push(isLabelled(i) && !isNaN(s.temp));
            e = isNaN(s.temp) ? null : tempExtremes[s.date];
            v = isNaN(s.temp) ? NaN : Math.round(s.temp);
            ext.push(!!e && ((!e.hiCovered && v === e.hi) || (!e.loCovered && v === e.lo)));
        }
        if (labelStride >= 4) {
            for (i = 0; i < n; i = j + 1) {
                j = i;
                if (!ext[i]) continue;
                v = Math.round(samples[i].temp);
                while (j + 1 < n && ext[j + 1] && samples[j + 1].date === samples[i].date
                       && Math.round(samples[j + 1].temp) === v) ++j;
                var mid = Math.floor((i + j) / 2);
                for (k = i; k <= j; ++k) ext[k] = (k === mid);
            }
            for (i = 0; i < n; ++i) {
                if (!ext[i]) continue;
                if (i > 0 && !ext[i - 1]) on[i - 1] = false;
                if (i + 1 < n && !ext[i + 1]) on[i + 1] = false;
            }
        }
        for (i = 0; i < n; ++i) on[i] = on[i] || ext[i];
        return on;
    }
    function showTempLabel(g) {
        return g >= 0 && g < tempLabelMap.length && tempLabelMap[g];
    }

    // ── which hours get a precipitation readout ──────────────────────────
    // An hour qualifies when it has snow, a measurable amount, or a published chance
    // of at least pctLabelMin (_readoutWanted) — the same test at every zoom and for
    // every provider. A SPELL is a run of consecutive qualifying hours, unbroken.
    //
    // At 12 hours every qualifying hour is labelled. At 24 and 48 hours that reads
    // too densely (the 12-hour view is there for the full detail), so each spell is
    // thinned to:
    //   • its first hour, and every second hour after that;
    //   • plus its wettest hour, judged on the AMOUNT alone (and only when some hour
    //     in the spell actually has one) — and the hours either side of that peak
    //     give way to it.
    //
    // Then, at EVERY zoom: consecutive hours that would print the very same readout
    // are one reading, not several, so a run of them keeps a single label at its
    // middle. That is what a 6-hour block looks like once it is spread over the
    // hourly grid — the same split amount on every hour — and what a flat stretch of
    // one chance looks like. A run only keeps its label if the step above labelled
    // some hour of it; for an even-length run the middle hour already labelled is
    // preferred, so at 24 and 48 hours no two labels ever end up on neighbouring hours.
    //
    // Worked out once per forecast, zoom and readout setting — never per scroll — so
    // a label belongs to its hour.
    function _readoutWanted(s) {
        if (!s || !weatherRoot) return false;
        if (snowCm(s) >= 0.1) return true;
        if (weatherRoot.hasPrecipAmt(precipMm(s))) return true;
        return weatherRoot.hasPrecipChance(s) && s.precip >= pctLabelMin;
    }
    // What an hour's readout would print, as one string: two hours with the same key
    // show the same label. Only the halves the readout setting lets through count,
    // so hiding the chance lets hours that differ only in their chance merge.
    function _readoutKey(s) {
        var sn = snowCm(s), amt = precipMm(s);
        var slot = !showPrecipAmt ? ""
                 : sn >= 0.1 ? weatherRoot.snowfallStr(sn, true)
                 : weatherRoot.precipAmtStr(amt);
        // the chance prints at pctLabelMin and up, or alongside any rain amount
        var pct = (showPrecipPct && weatherRoot.hasPrecipChance(s)
                   && (s.precip >= pctLabelMin || (sn < 0.1 && weatherRoot.hasPrecipAmt(amt))))
                  ? Math.round(s.precip) + "%" : "";
        return slot + "|" + pct;
    }
    readonly property var readoutPlan: {
        // _readoutKey consults these; reading them here too makes the plan rebuild
        // when the readout setting or the units change, the same belt-and-braces
        // readoutRowsByHour uses
        if (!samples || !samples.length || !weatherRoot || !weatherRoot.units) return null;
        if (showPrecipAmt === undefined || showPrecipPct === undefined) return null;
        var n = samples.length, shown = [], i, j, k;
        var thin = labelStride >= 2;   // 24 and 48 hours
        for (i = 0; i < n; ++i) shown.push(false);
        for (i = 0; i < n; i = j + 1) {
            j = i;
            if (!_readoutWanted(samples[i])) continue;
            while (j + 1 < n && _readoutWanted(samples[j + 1])) ++j;
            if (!thin) {
                for (k = i; k <= j; ++k) shown[k] = true;
            } else {
                // the spell's first hour, then every second hour of it
                for (k = i; k <= j; k += 2) shown[k] = true;
                // and its wettest hour — `top` starts at 0, so a spell that is all
                // chance and no measurable rain adds nothing here
                var top = 0, pick = -1;
                for (k = i; k <= j; ++k) {
                    var amt = precipMm(samples[k]);
                    if (amt > top) { top = amt; pick = k; }
                }
                if (pick >= 0) {
                    shown[pick] = true;
                    // The peak outranks the every-second-hour rule on either side of
                    // it: whatever that rule picked immediately before or after gives
                    // way, so the wettest hour is never crowded by a neighbour.
                    if (pick - 1 >= i) shown[pick - 1] = false;
                    if (pick + 1 <= j) shown[pick + 1] = false;
                }
            }
            // runs of identical readouts inside the spell keep one label, mid-run
            var keys = [];
            for (k = i; k <= j; ++k) keys.push(_readoutKey(samples[k]));
            for (var a = i, b; a <= j; a = b + 1) {
                b = a;
                while (b + 1 <= j && keys[b + 1 - i] === keys[a - i]) ++b;
                if (b === a) continue;
                var any = false;
                for (k = a; k <= b; ++k) if (shown[k]) { any = true; break; }
                if (!any) continue;
                var lo = Math.floor((a + b) / 2), hi = Math.ceil((a + b) / 2);
                var mid = (shown[hi] && !shown[lo]) ? hi : lo;
                for (k = a; k <= b; ++k) shown[k] = false;
                shown[mid] = true;
            }
        }
        return shown;
    }
    function readoutShownAt(g) {
        if (!readoutPlan) return true;
        return g >= 0 && g < readoutPlan.length && readoutPlan[g];
    }

    // Which rows a precipitation readout prints, as a bit mask — roGroup decides
    // the same way, so what the markers below dodge is exactly what is drawn:
    //   1 = the snow / rain-amount slot row
    //   2 = the chance %
    //   4 = the chance row takes up height (the hour publishes a chance at all;
    //       the row collapses to nothing when it doesn't)
    // 0 = nothing is printed. Split from its callers because the two markers feed
    // it from different places: the sun marker from the live morphing columns it
    // floats over, the new-day marker from the hours it travels with (see below).
    function readoutRows(pv, sv, av, cOn, shown) {
        if (!shown) return 0;                                   // thinned out, or merged into a neighbour
        var snowShown = sv >= 0.1;
        var amtShown  = !snowShown && weatherRoot && weatherRoot.hasPrecipAmt(av);
        // the chance also shows whenever an amount is present, even below pctLabelMin
        var bits = (snowShown || amtShown ? 1 : 0)
                 | (cOn && (pv >= pctLabelMin || amtShown) ? 2 : 0)
                 | (cOn ? 4 : 0);
        // a row the readout setting hides is not on screen to be dodged
        return bits & ((showPrecipAmt ? 1 : 0) | (showPrecipPct ? 6 : 0));
    }
    // …from the live column values, for a marker that floats over the columns.
    function readoutRowsAt(c, g) {
        if (c < 0 || c >= nPts) return 0;
        return readoutRows(c < curPrecip.length    ? curPrecip[c]    : 0,
                           c < curSnow.length      ? curSnow[c]      : 0,
                           c < curPrecipAmt.length ? curPrecipAmt[c] : 0,
                           c < curChanceOn.length  ? curChanceOn[c]  : 0,
                           readoutShownAt(g));
    }
    // …from each hour's own data, for a marker pinned to an hour. Worked out once
    // per data load / zoom rather than per frame: markerLift asks about a dozen
    // hours every time the graph repaints. Reading `units` here is deliberate —
    // hasPrecipAmt answers by it, so the list has to be rebuilt when it changes.
    readonly property var readoutRowsByHour: {
        var out = [];
        if (!weatherRoot || !weatherRoot.units || !samples) return out;
        for (var h = 0; h < samples.length; ++h) {
            var s = samples[h];
            out.push(readoutRows(s.precip, snowCm(s), precipMm(s),
                                 weatherRoot.hasPrecipChance(s), readoutShownAt(h)));
        }
        return out;
    }
    function readoutRowsForHour(h) {
        return (h >= 0 && h < readoutRowsByHour.length) ? readoutRowsByHour[h] : 0;
    }
    // Air a readout keeps above the temperature curve before it gives up on riding
    // the rain curve and goes over the temperature LABEL instead.
    readonly property int readoutTempClear: Math.round(graphReadoutFontSize * 0.6)
    // Screen y of a precipitation readout's TOP edge, for a column whose
    // temperature curve is at tY and precipitation curve at pY, given the group's
    // height h.
    //
    // It rides just above the RAIN curve wherever that runs — including well under
    // the temperature curve, which is where rain usually sits and reads far more
    // naturally than parking every readout along the top of the graph. Only when
    // the two curves close up, and the group would no longer clear the temperature
    // curve there, does it fall back to its old place above the temperature label.
    function readoutTopFor(tY, pY, h) {
        var onPrecip = pY - 14;
        if (onPrecip - h >= tY + readoutTempClear) return onPrecip - h;
        var tempLabelH = (weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13) * 1.4;
        return Math.min(tY - tempLabelH - Kirigami.Units.smallSpacing - 3, onPrecip) - h;
    }
    // How far a marker whose bottom edge sits at `bottom` must rise to keep
    // markerClearGap above hour `h`'s readout; 0 when that hour prints nothing or
    // already sits clear. It asks readoutTopFor where the group actually lands, so
    // the marker clears the real text rather than a guessed line count.
    //
    // The curve is read from the HOUR's own temperature and rain, not from the
    // morphing column the readout currently sits in. That keeps this steady while
    // the window slides — the column's value sweeps between two hours and its
    // assigned hour swaps at every half hour, and a marker chasing that would
    // shiver. Steady here means steady on screen: the lift is subtracted from the
    // marker's own curve-tracking y, so once a readout is being dodged the marker
    // parks just above it instead of riding the curve.
    function readoutNeed(h, bottom) {
        var rows = readoutRowsForHour(h);
        if (!rows) return 0;
        var s = samples[h];
        var slotH = showPrecipAmt ? readoutRowH : 0;
        var hgt = slotH + 1 + ((rows & 4) ? readoutRowH : 0);
        var top = Math.max(0, readoutTopFor(tempY(s.temp),
                                            precipY(weatherRoot ? weatherRoot.precipWashPct(s) : 0),
                                            hgt));
        // an empty slot row is transparent space, so when only the chance prints,
        // the highest thing actually drawn is the row below it
        if (!(rows & 1)) top += slotH + 1;
        // a readout riding the rain curve is below the marker, so this comes out 0
        return Math.max(0, bottom - top + markerClearGap);
    }

    // How long a temperature label takes to dissolve in or out when the window
    // moves off (or onto) its hour. Short enough to be over well before the slide
    // lands, so the new set is settled by the time the curve arrives.
    readonly property int lblFadeDur: 250
    readonly property int lblMorphDelay: 220   // numbers hold this long before ticking
    property int lblMorphDur: 600              // then morph over this (set per gesture)
    // The value labels get a SHORTER settle tail than the curve (morphSettleTail) so the
    // numbers finish ticking a touch sooner. Stays ≥ (morphSettleTail − lblMorphDelay) or
    // the lblMorphActive→curTemps handoff would snap (curTemps isn't at morphTo yet).
    readonly property int lblSettleTail: 200
    // sunrise + sunset instants across the forecast days: {ms, rise}. Drives both
    // the warm bloom the temp line picks up at a crossing AND the glyph pinned above
    // it. Local-time ISO strings parse the same way the sample times do
    // (timezone=auto), so they share an x-axis.
    readonly property var sunMarkerModel: {
        var out = [], dd = weatherRoot ? weatherRoot.dailyData : null;
        if (!dd) return out;
        for (var i = 0; i < dd.length; ++i) {
            if (dd[i].sunrise) out.push({ ms: new Date(dd[i].sunrise).getTime(), rise: true });
            if (dd[i].sunset)  out.push({ ms: new Date(dd[i].sunset).getTime(),  rise: false });
        }
        return out;
    }
    // curve-space x for a time instant, matching sunBloomPeaks's mapping so a glyph
    // sits exactly over the bloom: fractional sample index gFrac=(t−s0)/step, then
    // column (gFrac − hourPos) → screen x. NaN until the sample grid exists.
    // sample-grid origin + step (ms), cached per data load — xAtTime / sunMarkerLift /
    // sunBloomPeaks read these instead of re-parsing two Date strings on every call
    // (each runs per sun marker per frame during a drag). Spacing is uniform (1 h / 2 h).
    readonly property real sampleT0Ms:   (samples && samples.length)     ? new Date(samples[0].time).getTime() : NaN
    readonly property real sampleStepMs: (samples && samples.length > 1)
        ? (new Date(samples[1].time).getTime() - sampleT0Ms) : NaN
    function xAtTime(ms) {
        if (isNaN(sampleT0Ms) || isNaN(sampleStepMs) || sampleStepMs <= 0 || nPts < 1) return NaN;
        return ((ms - sampleT0Ms) / sampleStepMs - hourPos + 0.5) * (plotW / nPts);
    }
    // compact sun-event time, matching the hour axis: "6:18a" / "7:48p" (12h) or
    // "6:18" / "19:48" (24h)
    function sunTimeLabel(ms) {
        var d = new Date(ms), h = d.getHours(), m = d.getMinutes();
        var mm = (m < 10 ? "0" + m : m);
        if (weatherRoot && weatherRoot.use24Hour) return h + ":" + mm;
        var h12 = h % 12; if (h12 === 0) h12 = 12;
        return h12 + ":" + mm + (h < 12 ? "a" : "p");
    }
    // Extra height to lift a sun marker so it clears the per-hour precip/snow/amount
    // readouts that sit above the temp number — a sun glyph straddles up to a couple
    // of columns, so a readout there would otherwise jumble with its time. Returns
    // the tallest readout (in lines) among the marker's neighbouring columns, ×0,
    // so dry columns keep the marker tight to the temp number.
    function sunMarkerLift(px, mh) {
        // off-plot markers aren't drawn, so their lift is irrelevant — skip the
        // 3-column scan entirely for markers outside the plot.
        if (nPts < 1 || isNaN(px) || px < 0 || px > plotW) return 0;
        var tempLabelH = (weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13) * 1.4;
        // where the marker would sit with no lift at all — the box the readouts
        // below are tested against. Working from the UNLIFTED position keeps this
        // out of a circle with the delegate's own y.
        var baseTop = curveYAtX(px) - tempLabelH - mh - sunMarkGap;
        var col = Math.round(px / (plotW / nPts) - 0.5), lift = 0;
        for (var c = col - 1; c <= col + 1; ++c) {
            var g = Math.round(hourPos) + c;
            var rows = readoutRowsAt(c, g);
            if (!rows) continue;
            var gh = (showPrecipAmt ? readoutRowH : 0) + 1 + ((rows & 4) ? readoutRowH : 0);
            var rTop = Math.max(0, readoutTopFor(curTempY(c), curPrecipY(c), gh));
            // only a readout whose box actually meets the marker's is in the way —
            // one riding the rain curve well below it is not, and neither is one
            // stacked high above it
            if (rTop + gh <= baseTop || rTop >= baseTop + mh) continue;
            var need = baseTop + mh - rTop + markerClearGap;
            if (need > lift) lift = need;
        }
        return lift;
    }
    readonly property int nPts: curTemps.length

    readonly property real plotW:      Math.max(1, graphArea.width)
    readonly property real inset:      Kirigami.Units.gridUnit * 0.7   // edge breathing room
    // plotH grows with topReserve so the temp curve keeps the same pixel
    // amplitude (range = 0.68·plotH − topReserve) — the extra room is purely
    // headroom for the new-day marker above a peak, the curve is not flattened.
    readonly property real plotH:      Kirigami.Units.gridUnit * 14.0
    readonly property real topReserve: Kirigami.Units.gridUnit * 4.1   // room for temp labels + the new-day marker above the peak
    readonly property real precipBandH: plotH * 0.13                   // bottom margin the temp curve keeps clear (smaller → taller, more dramatic temp curve)
    readonly property real precipMaxFrac: 0.70                         // precip fill rises to this fraction of plotH at 100% chance — high chances overlap the temp curve, low ones stay a sliver near the floor
    readonly property real markerGap:   Kirigami.Units.gridUnit * 1.9  // base gap between a new-day marker and the temp curve/label
    // The new-day line's dash pattern, and a run long enough to reach the floor
    // from the highest a marker can sit. Fixed so the Repeater never rebuilds its
    // delegates mid-scroll — the run is cut to length by the clip around it.
    readonly property int dayLineDash: 3
    readonly property int dayLineGap:  4
    readonly property int dayLineDashes: Math.ceil(plotH / (dayLineDash + dayLineGap)) + 1
    readonly property real markerClearGap: Kirigami.Units.smallSpacing   // air left between a marker and a readout it dodges
    readonly property real sunMarkGap:     Kirigami.Units.smallSpacing * 3   // sun marker's own gap above the temp label
    readonly property real markerRamp:     Kirigami.Units.gridUnit       // how far out a marker starts easing over a readout
    // A new-day marker is icon + date WIDE — several columns at 48 hours — and it
    // is centred on its midnight line, so it reaches well past its own column.
    // Measured once from a representative date: every marker reads
    // "<short weekday>, <date>" (or the weekday alone, per the option), and
    // markerClearGap absorbs the few pixels one weekday name differs from another.
    TextMetrics {
        id: dayMarkerMetrics
        font.bold: true
        font.pixelSize: weatherRoot ? weatherRoot.simpleDayMarkerFontSize : 12
        text: (weatherRoot && samples.length) ? weatherRoot.dayMarkerText(samples[0].date) : ""
    }
    readonly property real dayMarkerHalfW: {
        var iconW = weatherRoot ? Math.round(weatherRoot.simpleDayMarkerFontSize * 2.25) : 27;
        return (iconW + Kirigami.Units.smallSpacing + dayMarkerMetrics.width) / 2;
    }
    // Where a new-day marker `w` wide sits for a line at `lx`: centred on it, but
    // held dayMarkerEdge inside the plot for as long as the line is, so the edge
    // never cuts off its icon or date. Near an edge the marker stops and the line
    // walks on across under it; when the line reaches the marker's outer side it
    // takes the marker off the plot with it. Continuous at every hand-over, so a
    // scroll never makes the marker jump.
    readonly property real dayMarkerEdge: Kirigami.Units.smallSpacing
    function dayMarkerX(lx, w) {
        var e = dayMarkerEdge;
        return Math.min(Math.max(lx - w / 2, Math.min(lx, e)),
                        Math.max(lx - w, plotW - e - w));
    }
    // How far a new-day marker rises above the temp curve — the dashed line and
    // the icon + date share this lift, so the line always meets the label.
    // markerGap alone keeps it off the temperature label; on top of that it
    // clears any precipitation readout standing where it wants to be, the way the
    // sun markers do. It looks either side of its own midnight, not just at it:
    // the marker is icon + date WIDE and centred on its line, so the "2.0 mm" it
    // used to land on belongs to a neighbouring hour. `shift` is how far the
    // marker's centre sits off its line — non-zero only while a plot edge holds
    // it in (dayMarkerX) — and the hours it covers shift with it.
    function markerLift(g, shift) {
        var lift = markerGap;
        if (nPts < 1) return lift;
        var colW = plotW / nPts;
        var tLabelH = (weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13) * 1.4;
        // where the marker's bottom edge would sit with no lift at all
        var bottom = markerCurveY(g, hourX(g)) - tLabelH;
        // half the width of the two boxes that must not meet: the marker, and a
        // readout label (~3.4 character-widths, the same estimate readoutPlan
        // stacks by). markerRamp softens the cutoff, so an hour just out of reach
        // asks for part of the clearance rather than none.
        var span = dayMarkerHalfW + graphReadoutFontSize * 1.7;
        var off = shift || 0;
        // Walk the HOURS either side of the marker. They travel with the marker, so
        // both what they print and how far away they are stay put through a scroll
        // and the lift never hops — only the curve underneath it moves, and that
        // moves smoothly. The exception is a marker held in at an edge: the hours
        // slide under it there, and the ramp below eases each one in and out.
        var lo = Math.floor(g + (off - span - markerRamp) / colW);
        var hi = Math.ceil(g + (off + span + markerRamp) / colW);
        for (var h = lo; h <= hi; ++h) {
            var sep = Math.abs((h - g) * colW - off) - span;   // ≤ 0 → the boxes overlap
            if (sep >= markerRamp) continue;
            var need = readoutNeed(h, bottom);
            if (need <= lift) continue;
            // ease only the part that goes BEYOND the base gap, so a marker with
            // nothing to dodge keeps sitting exactly where it always did
            var eased = markerGap + (need - markerGap) * (sep <= 0 ? 1 : 1 - sep / markerRamp);
            if (eased > lift) lift = eased;
        }
        return lift;
    }
    readonly property real iconRowH: (weatherRoot ? weatherRoot.simpleHourlyIconSize : 24)
                                     + Kirigami.Units.smallSpacing * 2
    // grows with the configurable hour-axis font so a larger size never clips
    readonly property real timeRowH: Math.max(Math.round(Kirigami.Units.gridUnit * 1.2),
                                              Math.round((weatherRoot ? weatherRoot.simpleHourFontSize : 11) * 1.5))
    // font for the per-hour readout labels on the graph (precip % + snow amount)
    readonly property int graphReadoutFontSize: 13
    // how long a precip/snow readout takes to fade as it crosses its visibility
    // threshold while scrolling. Asymmetric: a quick fade IN, a slower lingering fade
    // OUT. Each Behavior picks via its own on-flag — at fade start the flag already
    // holds the target state (on → in, off → out).
    readonly property int  readoutFadeDur:    150   // fade IN
    readonly property int  readoutFadeOutDur: 500   // fade OUT

    // one readout line — the height of both the amount/snow slot and the chance row
    readonly property int readoutRowH: Math.round(graphReadoutFontSize * 1.4)

    // y-scale tracks the interpolated values, so the vertical range eases too. One
    // pass over curTemps per frame (it re-allocates each frame) yields BOTH bounds;
    // tmin/tmax read the cached pair instead of walking the array twice.
    readonly property var tRange: {
        var a = curTemps; if (!a.length) return [0, 1];
        var lo = 1e9, hi = -1e9;
        for (var i = 0; i < a.length; ++i) { var v = a[i]; if (v < lo) lo = v; if (v > hi) hi = v; }
        return [lo, hi];
    }
    readonly property real tmin: tRange[0]
    readonly property real tmax: tRange[1]

    // x for point `i` when a day fills the width as `count` equal cells, the
    // point centered in its cell. Cell-centering makes consecutive days in the
    // sliding filmstrip tile seamlessly (uniform spacing across day seams).
    function xAtFor(i, count) { return count > 0 ? (i + 0.5) * (plotW / count) : 0; }
    // curve column x: the curve is `nPts` columns wide (24 hourly / 12 every-2h).
    function xAt(i) { return xAtFor(i, nPts); }
    // entrance reveal factor: 0 = curves flat on the baseline, 1 = full shape.
    // Baked into the y-mappings so the canvas, value labels and new-day markers
    // all rise from the ground together.
    property real reveal: 1
    function tempY(t) {
        var hi = topReserve, lo = plotH - precipBandH;
        var y = (tmax === tmin) ? (hi + lo) / 2
                                : hi + (tmax - t) / (tmax - tmin) * (lo - hi);
        return plotH + (y - plotH) * reveal;
    }
    // height tracks the ABSOLUTE chance (0-100), not the window max, so a high
    // chance genuinely rises into the temp zone (overlap) while a dry window stays
    // a low sliver. Capped at precipMaxFrac of plotH at 100%.
    function precipY(p) {
        var frac = Math.max(0, Math.min(1, (isNaN(p) ? 0 : p) / 100));
        return plotH - frac * precipMaxFrac * plotH * reveal;
    }
    function curTempY(i)   { return tempY(curTemps[i]); }
    function curPrecipY(i) { return precipY(curPrecip[i]); }
    // y of the UPPER silhouette (temp or precip, whichever is higher) at an
    // arbitrary plot x (linear between points) — lets the new-day marker ride
    // just above whatever peaks there, dodging both a high temp curve and a tall
    // precip wash as they morph/slide during a scroll.
    function silY(i) { return Math.min(curTempY(i), curPrecipY(i)); }
    // linear-interpolate a per-column curve y at an arbitrary plot x. kind:
    // 0 = temp curve, 1 = precip curve, else = upper silhouette (min of the two).
    // Lets the sliding filmstrip overlays (new-day marker, precip/snow readouts)
    // ride whatever the morphing curve is doing at their panned x.
    function colYAtX(px, kind) {
        var n = nPts;
        if (n === 0) return topReserve;
        function yAt(i) { return kind === 0 ? curTempY(i) : kind === 1 ? curPrecipY(i) : silY(i); }
        if (px <= xAt(0))     return yAt(0);
        if (px >= xAt(n - 1)) return yAt(n - 1);
        for (var i = 0; i < n - 1; ++i) {
            var x0 = xAt(i), x1 = xAt(i + 1);
            if (px >= x0 && px <= x1) {
                var f = (px - x0) / Math.max(1e-6, x1 - x0);
                return yAt(i) + (yAt(i + 1) - yAt(i)) * f;
            }
        }
        return yAt(n - 1);
    }
    function curveYAtX(px) { return colYAtX(px, 2); }
    // The curve under new-day line `g` at x `lx`. Between the outer columns that
    // is the drawn curve. Past them colYAtX pins to the edge column, and that
    // column reshapes by a whole hour's change for every column of scroll — so a
    // marker reading it would bob, and now that a marker stays partly on screen
    // while its line carries it off the plot, the bob would show. Out there the
    // line's own hour is used instead: it is exactly what the edge column holds
    // at the moment the line crosses it, so the hand-over is seamless, and it
    // holds still while the marker leaves.
    function markerCurveY(g, lx) {
        if (nPts < 1 || dayMorphT < 1 || (lx >= xAt(0) && lx <= xAt(nPts - 1))
                || g < 0 || g >= samples.length)
            return curveYAtX(lx);
        var s = samples[g];
        return Math.min(tempY(s.temp), precipY(weatherRoot ? weatherRoot.precipWashPct(s) : 0));
    }
    // A precip-% readout shows on any column whose chance is at least this. It's a
    // STABLE threshold, not a moving-peak test: a column keeps its label while rain
    // is present there and the value just MORPHS as you scroll (like the temp
    // numbers), instead of blinking as a peak slides across fixed columns. Snow
    // labels use a fixed cm floor (0.1) the same way. A column's % is shown when its
    // hour's chance is at/above this; the seam between a wet and dry hour is handled
    // by OR-ing both endpoint hours (see pctOn), not by a hysteresis release point.
    readonly property int pctLabelMin:  20

    readonly property bool scrolling: posAnim.running || flickAnim.running || dragging

    // Fixed [min,max] across all configured days so a given temperature maps to
    // the same colour on every tab (honest colours, not per-day relative).
    readonly property var tempDomain: {
        var a = samples, lo = 1e9, hi = -1e9;
        for (var i = 0; i < a.length; ++i) {
            var t = a[i].temp;
            if (t < lo) lo = t;
            if (t > hi) hi = t;
        }
        return lo <= hi ? [lo, hi] : [0, 1];
    }
    function tempNorm(t) {
        var d = tempDomain, span = Math.max(1, d[1] - d[0]);
        return (t - d[0]) / span;
    }
    // normalized temp (0..1) → "rgba(...)" via the ramp
    function rampColor(t, alpha) {
        var ramp = tempRamp, x = Math.max(0, Math.min(1, t));
        var lo = ramp[0], hi = ramp[ramp.length - 1];
        for (var i = 0; i < ramp.length - 1; ++i) {
            if (x >= ramp[i][0] && x <= ramp[i + 1][0]) { lo = ramp[i]; hi = ramp[i + 1]; break; }
        }
        var f = (x - lo[0]) / Math.max(1e-6, hi[0] - lo[0]);
        var r = Math.round(lo[1][0] + (hi[1][0] - lo[1][0]) * f);
        var g = Math.round(lo[1][1] + (hi[1][1] - lo[1][1]) * f);
        var b = Math.round(lo[1][2] + (hi[1][2] - lo[1][2]) * f);
        return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
    }

    function rgbaArr(c, a) { return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + a.toFixed(3) + ")"; }

    // Sun events currently on (or just off) screen, as {off, rise}. `off` is the
    // fractional curve-column offset (0 = leftmost column, 1 = rightmost): a sun
    // instant maps to fractional sample index gFrac = (t − s0)/step, and column i
    // tracks global index (hourPos + i), so off = (gFrac − hourPos)/(nPts−1).
    // `step` is read from the data (1h or 2h modes). Margin = the bloom half-width
    // so a glow whose centre is just off-screen still bleeds in. Drives drawSunBloom.
    function sunBloomPeaks() {
        var evs = sunMarkerModel;
        if (!evs.length || nPts < 2 || !samples || samples.length < 2) return [];
        var s0 = sampleT0Ms, step = sampleStepMs;
        if (isNaN(s0) || isNaN(step) || step <= 0) return [];
        var denom = nPts - 1, hw = sunGlowHalfCols / denom, out = [];
        for (var i = 0; i < evs.length; ++i) {
            var off = ((evs[i].ms - s0) / step - hourPos) / denom;
            if (off > -hw && off < 1 + hw) out.push({ off: off, rise: evs[i].rise });
        }
        return out;
    }

    // Paint the radial sun bloom + line streak for every on-screen sun event.
    // Drawn straight onto the chart canvas (after the fills, before the crisp temp
    // line) so the line sits on top of its own glow. xs/ty are the live (morphing)
    // curve columns; gx0/gx1 the horizontal span shared with the gradients. Each
    // event: a tall radial ellipse (core on the line, fading up, clipped above the
    // curve) plus a soft horizontal streak laid along the line itself.
    function drawSunBloom(ctx, xs, ty, gx0, gx1, w) {
        var peaks = sunBloomPeaks();
        if (!peaks.length) return;
        var n = xs.length, spanX = gx1 - gx0;
        if (n < 2 || spanX <= 0) return;
        var denom = nPts - 1;
        var colW = spanX / denom;                 // px per curve column
        var rx = sunGlowHalfCols * colW;          // horizontal radius
        // upward reach measured in sun-glyph heights, so the glow never overshoots
        // the icon pinned above the line (icon = hourlyInfoFontSize * 3.1, see marker delegate).
        var iconSz = weatherRoot ? weatherRoot.hourlyInfoFontSize * 3.1 : 34;
        var ry = iconSz * sunGlowRiseIcons;       // upward reach
        if (rx <= 0 || ry <= 0) return;

        // clip to the area ABOVE the temp curve (the whole trick from the design):
        // trace the curve, then close up-and-over the top so the glow can't spill below.
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(0, ty[0]);
        ctx.lineTo(xs[0], ty[0]);
        smooth(ctx, xs, ty);
        ctx.lineTo(w, ty[n - 1]);
        ctx.lineTo(w, 0);
        ctx.lineTo(0, 0);
        ctx.closePath();
        ctx.clip();

        for (var p = 0; p < peaks.length; ++p) {
            var off = peaks[p].off;
            var cx = gx0 + off * spanX;
            // line y at the (fractional) event column, so the core sits on the curve
            var colF = Math.max(0, Math.min(denom, off * denom));
            var i0 = Math.min(n - 2, Math.floor(colF)), fr = colF - i0;
            var cy = ty[i0] + (ty[i0 + 1] - ty[i0]) * fr;
            var pal = peaks[p].rise ? sunGlow.rise : sunGlow.set;
            // local slope of the curve at the event: the chord between the bracketing
            // columns. The bloom is rotated by this so its wide axis lies ALONG the
            // line and the rise is perpendicular to it — on a steep section it follows
            // the curve instead of floating as a flat horizontal lens.
            var slopeAngle = Math.atan2(ty[i0 + 1] - ty[i0], xs[i0 + 1] - xs[i0]);

            // radial ellipse: a circle in a rotated, y-scaled frame → a feathered lens
            // that hugs the line at its local angle. Gaussian falloff (many stops) so the
            // rim dissolves smoothly; colour eases core→mid across the inner third;
            // alpha follows coreA·exp(−feather·r²), the last stop forced transparent.
            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate(slopeAngle);
            ctx.scale(1, ry / rx);
            var g = ctx.createRadialGradient(0, 0, 0, 0, 0, rx);
            var GSTOPS = 8;
            for (var gs = 0; gs <= GSTOPS; ++gs) {
                var gt = gs / GSTOPS;
                var cmix = Math.min(1, gt / 0.33);
                var gcol = [Math.round(pal.core[0] + (pal.mid[0] - pal.core[0]) * cmix),
                            Math.round(pal.core[1] + (pal.mid[1] - pal.core[1]) * cmix),
                            Math.round(pal.core[2] + (pal.mid[2] - pal.core[2]) * cmix)];
                var ga = gs === GSTOPS ? 0 : sunGlowCoreA * Math.exp(-sunGlowFeather * gt * gt);
                g.addColorStop(gt, rgbaArr(gcol, ga));
            }
            ctx.fillStyle = g;
            ctx.beginPath();
            ctx.arc(0, 0, rx, 0, 2 * Math.PI);
            ctx.fill();
            ctx.restore();
        }
        ctx.restore();   // drop the above-line clip

        // soft glowing streak along the line at each event: a horizontal gradient
        // that's transparent except a bump of `streak` colour around each peak,
        // stroked wide+faint then narrow+brighter to fake a blurred glow (Canvas
        // has no feGaussianBlur). Drawn unclipped — it rides the line, not above it.
        if (sunStreakHalfCols <= 0) return;   // streak off — nothing left to draw
        var denom2 = nPts - 1, shw = sunStreakHalfCols / denom2;
        var sg = ctx.createLinearGradient(gx0, 0, gx1, 0);
        sg.addColorStop(0, rgbaArr(peaks[0].rise ? sunGlow.rise.streak : sunGlow.set.streak, 0));
        for (var q = 0; q < peaks.length; ++q) {
            var e = peaks[q].off, sc = peaks[q].rise ? sunGlow.rise.streak : sunGlow.set.streak;
            // feathered bell ALONG the line: gaussian alpha across ±shw (same exp(−feather·u²)
            // profile as the radial) so the warm width fades smoothly instead of as a hard
            // triangle. Stops outside [0,1] (event scrolled near/off the edge) are dropped —
            // an out-of-range addColorStop throws and aborts the whole paint; the 0/1 anchor
            // stops still fade it cleanly.
            var SSTOPS = 6;
            for (var ss = -SSTOPS; ss <= SSTOPS; ++ss) {
                var su = ss / SSTOPS;                          // −1..1 across the streak
                var so = e + su * shw;
                if (so <= 0 || so >= 1) continue;
                var sa = Math.abs(ss) === SSTOPS ? 0
                       : sunGlowStreakA * Math.exp(-sunGlowFeather * su * su);
                sg.addColorStop(so, rgbaArr(sc, sa));
            }
        }
        sg.addColorStop(1, rgbaArr(peaks[peaks.length - 1].rise ? sunGlow.rise.streak : sunGlow.set.streak, 0));
        ctx.save();
        ctx.lineCap = "round";
        ctx.strokeStyle = sg;
        var passes = [[16, 0.32], [8, 0.62], [3.5, 1.0]];   // [width, alpha-scale]: wide+faint halo → mid → tight core, faking a blurred glow
        for (var s = 0; s < passes.length; ++s) {
            ctx.globalAlpha = passes[s][1];
            ctx.lineWidth = passes[s][0];
            ctx.beginPath();
            ctx.moveTo(0, ty[0]);
            ctx.lineTo(xs[0], ty[0]);
            smooth(ctx, xs, ty);
            ctx.lineTo(w, ty[n - 1]);
            ctx.stroke();
        }
        ctx.restore();
    }

    // Precip colour is CONSISTENT — a fixed rain-blue independent of the chance
    // (the chance is conveyed by the fill HEIGHT, not its colour). Snowiness is
    // the only thing that shifts it: rain-blue → white in proportion to amount.
    readonly property var snowRGB:   [245, 250, 255]  // bright snow white
    readonly property var precipRGB: [66, 165, 245]   // rain blue (#42a5f5)
    // Opacity of the band's TOP edge (config precipBandOpacity, a percentage); it
    // still fades toward the floor from there. 0 leaves the curve as a bare line.
    readonly property real precipBandA: (weatherRoot ? weatherRoot.precipBandOpacity : 30) / 100
    readonly property real precipLineA: 0.95          // consistent stroke opacity
    readonly property real precipFadeFloor: 0.18      // band alpha kept at the floor; the fill is dense at its top edge and fades down to this (vertical wash)
    readonly property real precipFadeExp:   1.4       // >1 = fade harder toward the floor while the top edge keeps full opacity
    // colour for one column: fixed blue, only snow shifts it toward white.
    function precipColorAt(snow, chance, isLine) {
        var s = Math.max(0, Math.min(1, snow));
        var r = Math.round(precipRGB[0] + (snowRGB[0] - precipRGB[0]) * s);
        var g = Math.round(precipRGB[1] + (snowRGB[1] - precipRGB[1]) * s);
        var b = Math.round(precipRGB[2] + (snowRGB[2] - precipRGB[2]) * s);
        var a = (isLine ? precipLineA : precipBandA);
        // a band turned all the way down means a bare line, snow included — without
        // this the snow boost below would keep painting one
        if (!isLine && a <= 0) return "rgba(" + r + "," + g + "," + b + ",0)";
        a = a + (1 - a) * s * 0.32;                   // snow reads a bit more opaque than rain
        return "rgba(" + r + "," + g + "," + b + "," + a.toFixed(3) + ")";
    }

    // canvas-side helpers
    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255)
             + "," + Math.round(c.b * 255) + "," + a + ")";
    }
    // Monotone cubic (Steffen, 1990) → bezier, for the PRECIPITATION curve.
    //
    // smooth() above is Catmull-Rom, which is right for temperature but wrong for rain:
    // next to a flat run its control points pull the curve past the data, so a curve
    // about to climb out of a dry spell first dips BELOW the axis — by about a sixth of
    // the height it is climbing to, 10 px below the floor ahead of a 2 mm peak — and
    // vanishes there. Rain has a hard floor at zero, so the curve must never cross it.
    //
    // Steffen limits each tangent to at most twice either neighbouring secant and to
    // the average secant, and sets it level wherever the data turns or runs flat. That
    // keeps every segment between its own two endpoints: flat stretches stay exactly
    // flat, a rise leaves the floor with a level tangent, and a peak tops out at its
    // real value instead of overshooting. The ends are level too, so the curve meets
    // the flat extension drawn out to the plot edges without a corner.
    function smoothMonotone(ctx, xs, ys) {
        var n = xs.length;
        if (n < 2) return;
        var h = [], d = [], i;
        for (i = 0; i < n - 1; ++i) {
            h.push(xs[i + 1] - xs[i]);
            d.push(h[i] !== 0 ? (ys[i + 1] - ys[i]) / h[i] : 0);
        }
        var m = [0];
        for (i = 1; i < n - 1; ++i) {
            if (d[i - 1] * d[i] <= 0) { m.push(0); continue; }   // turning point or flat
            var p = (d[i - 1] * h[i] + d[i] * h[i - 1]) / (h[i - 1] + h[i]);
            m.push((d[i] > 0 ? 1 : -1)
                   * Math.min(2 * Math.abs(d[i - 1]), 2 * Math.abs(d[i]), Math.abs(p)));
        }
        m.push(0);
        for (i = 0; i < n - 1; ++i) {
            var t = h[i] / 3;
            ctx.bezierCurveTo(xs[i] + t,     ys[i] + m[i] * t,
                              xs[i + 1] - t, ys[i + 1] - m[i + 1] * t,
                              xs[i + 1],     ys[i + 1]);
        }
    }

    function smooth(ctx, xs, ys) {   // Catmull-Rom → bezier
        for (var i = 0; i < xs.length - 1; ++i) {
            var x0 = i > 0 ? xs[i - 1] : xs[i], y0 = i > 0 ? ys[i - 1] : ys[i];
            var x1 = xs[i], y1 = ys[i], x2 = xs[i + 1], y2 = ys[i + 1];
            var x3 = i + 2 < xs.length ? xs[i + 2] : x2, y3 = i + 2 < xs.length ? ys[i + 2] : y2;
            ctx.bezierCurveTo(x1 + (x2 - x0) / 6, y1 + (y2 - y0) / 6,
                              x2 - (x3 - x1) / 6, y2 - (y3 - y1) / 6, x2, y2);
        }
    }

    function clampPos(p) { return Math.max(0, Math.min(dayCount - 1, p)); }

    // Day stepping for the pill wheel. selectedDay only catches up once the pan
    // animation has moved hourPos, so stepping straight off it would swallow the
    // second and third notch of a fast scroll. pendingDay remembers where we are
    // headed and chains from there instead; it clears when the pan settles.
    property int pendingDay: -1
    function stepDay(delta) {
        var from = (pendingDay >= 0) ? pendingDay : selectedDay;
        var to = clampPos(from + delta);
        if (to === from) return;
        pendingDay = to;
        goToDay(to);
    }

    // entrance animation: the curves rise from the baseline into shape (no
    // day-scrolling). Plays when the view is created (layout switch recreates
    // it via the Loader) and again every time the popup is opened (the view
    // survives a close, so watch `expanded`).
    NumberAnimation {
        id: revealAnim
        target: simple
        property: "reveal"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.OutCubic
    }
    function entranceReveal() {
        posAnim.stop(); flickAnim.stop();
        hourPos = 0;   // always reopen on today
        chosenDay = -1;
        revealAnim.restart();
        if (!iconsLive) iconsLiveTimer.restart();
    }
    Component.onCompleted: entranceReveal()

    // Top of the header row, in view coordinates (the content's top margin). The header
    // content is positioned from the shared geometry in WeatherToolbar, which is in view
    // coordinates too; this converts between the two.
    readonly property int headerY: Math.round(pad * 1.0)
    // False while the popup is closed. Plasma keeps the view alive (and `visible`)
    // behind a hidden popup, so an animated icon gated on `visible` alone keeps
    // decoding frames for a window nobody can see.
    readonly property bool onScreen: Window.visibility !== Window.Hidden
    // kept warm across layout switches now, so replay the curve reveal when the
    // view is shown again rather than relying on recreation
    onVisibleChanged: if (visible) entranceReveal()
    Connections {
        target: simple.weatherRoot
        function onExpandedChanged() {
            if (simple.weatherRoot.expanded) simple.entranceReveal();
        }
    }

    implicitWidth:  Math.max(Kirigami.Units.gridUnit * 34, content.implicitWidth + pad * 2)
    implicitHeight: content.implicitHeight + pad + Math.round(pad * 1.0)
    // the card layout's minimum (FullView), so both layouts squeeze to the same width
    Layout.minimumWidth: Kirigami.Units.gridUnit * 32 + pad * 2

    // animations drive the window position (hourPos)
    NumberAnimation {
        id: posAnim
        target: simple
        property: "hourPos"
        duration: 600
        easing.type: Easing.InOutQuad
        onFinished: simple.pendingDay = -1   // chain closed; resume from selectedDay
    }
    NumberAnimation {
        id: flickAnim
        target: simple
        property: "hourPos"
        easing.type: Easing.OutCubic
    }
    // Paired with flickAnim for the FLING MORPH: cross-fades the curve (dayMorphT 0→1)
    // to the landing window while flickAnim pans the strip there. Given the SAME
    // per-fling duration as flickAnim so both finish together — dayMorphT hits 1 exactly
    // as hourPos reaches the target, so the cross-fade → windowAt() handoff doesn't snap.
    // Slow drag / touchpad stay 1:1 slides (they don't touch this); only a flick morphs.
    NumberAnimation {
        id: flickMorphAnim
        target: simple
        property: "dayMorphT"
        easing.type: Easing.OutQuart   // match morphAnim so readout digits settle in sync on a fling too
    }
    // Delayed VALUE-label morph: hold the numbers for lblMorphDelay, then tick them to
    // the new values over lblMorphDur (set per gesture ≥ the curve span, so when the
    // label morph ends curTemps is already at morphTo and the handoff doesn't jump).
    SequentialAnimation {
        id: lblMorphAnim
        PauseAnimation { duration: simple.lblMorphDelay }
        NumberAnimation { target: simple; property: "lblMorphT"; from: 0; to: 1
                          duration: simple.lblMorphDur; easing.type: Easing.OutCubic }
    }
    // The curve cross-fade outlasts the strip pan by this many ms, so the curve keeps
    // settling IN PLACE after the timeline has already reached the target — a slow,
    // decelerating finish (OutCubic). ⚠️ Must be ≥ 0: if the morph finished BEFORE the
    // pan, dayMorphT would hit 1 while hourPos≠target and snap curTemps from morphTo
    // back to windowAt(). Bump it for a longer lingering settle.
    readonly property int morphSettleTail: 450
    function clampHour(p) { return Math.max(0, Math.min(maxHourPos, p)); }
    function dayFirstSampleIndex(idx) {
        if (!weatherRoot || !weatherRoot.dailyData || !weatherRoot.dailyData[idx]) return 0;
        var date = weatherRoot.dailyData[idx].date;
        for (var i = 0; i < samples.length; ++i) if (samples[i].date === date) return i;
        return 0;
    }
    // day-tab click: the in-place curve morph (current → target day)
    NumberAnimation {
        id: morphAnim
        target: simple
        property: "dayMorphT"
        duration: 600   // overridden per tap in goToDay → pan + morphSettleTail (the settle tail)
        // Front-loaded (OutQuart) so most of each number's value travel happens
        // early and it settles into its final rounded digit sooner. With a
        // back-loaded/symmetric curve (e.g. InOutQuad) a big-delta readout keeps
        // ticking through digits deep into the slow tail while a small-delta one
        // settled long ago, so they read as out of sync — this compresses that
        // gap. Matches flickMorphAnim's decelerating feel.
        easing.type: Easing.OutQuart
    }
    // any free scroll (drag / wheel) abandons an in-flight curve morph (pill tap OR
    // fling) and its paired pan, returning the curve to following the window directly
    function cancelDayMorph() { morphAnim.stop(); flickMorphAnim.stop(); flickAnim.stop(); lblMorphAnim.stop(); simple.dayMorphT = 1; simple.lblMorphT = 1; }
    function flickTo(velocity) {                 // velocity in sample-index units/s
        // Sample-index units, so every one of these scales with the density — at the
        // same finger speed an hourly curve produces twice the index velocity of a
        // 2-hourly one. Scaled, a fling covers the same span of TIME either way.
        var maxVh = 42 * densityScale, decelh = 60 * densityScale;
        var vh = Math.max(-maxVh, Math.min(maxVh, velocity));
        if (Math.abs(vh) < 1.5 * densityScale) return;
        var dh = (vh < 0 ? -1 : 1) * (vh * vh) / (2 * decelh);
        var th = clampHour(simple.hourPos + dh);
        if (Math.abs(th - simple.hourPos) < 0.5 * densityScale) return;
        // land on a WHOLE hour so the fling morph hands off seamlessly to windowAt()
        var targetW = Math.round(th);
        if (targetW === Math.round(simple.hourPos)) return;
        var dur = Math.min(1000, Math.max(180, Math.abs(vh) / decelh * 1000));
        // FLING MORPH: cross-fade the curve in place to the landing window while the
        // strip pans there. The curve morph runs LONGER than the pan (dur +
        // morphSettleTail) so it keeps settling after the strip has arrived; it must
        // not be SHORTER than the pan or the morphTo → windowAt() handoff would snap.
        _snapMorph(targetW);
        flickAnim.stop(); flickAnim.from = simple.hourPos; flickAnim.to = targetW;
        flickAnim.duration = dur; flickAnim.start();
        flickMorphAnim.stop(); flickMorphAnim.from = 0; flickMorphAnim.to = 1;
        flickMorphAnim.duration = dur + morphSettleTail; flickMorphAnim.start();
        simple.lblMorphT = 0; lblMorphAnim.stop();
        lblMorphDur = dur + lblSettleTail; lblMorphAnim.start();
    }
    // Snapshot the current curve columns as the morph SOURCE and the window at targetW
    // as the morph TARGET, then arm dayMorphT at 0. Shared by the day-pill morph
    // (goToDay) and the fling morph (flickTo). targetW must be a whole sample index so
    // the morph hands off cleanly to windowAt(targetW) when dayMorphT reaches 1.
    function _snapMorph(targetW) {
        var win = windowAt(targetW);
        morphFromBase = Math.round(hourPos);
        morphToBase = targetW;
        morphFromT = curTemps.slice();
        morphFromP = curPrecip.slice();
        morphFromS = curSnow.slice();
        morphFromA = curPrecipAmt.slice();
        morphFromC = curChanceOn.slice();
        morphToT = win.map(function(s) { return s.temp; });
        morphToP = win.map(function(s) { return weatherRoot ? weatherRoot.precipWashPct(s) : 0; });
        morphToC = win.map(function(s) { return weatherRoot && weatherRoot.hasPrecipChance(s) ? 1 : 0; });
        morphToS = win.map(function(s) { return simple.snowCm(s); });
        morphToA = win.map(function(s) { return simple.precipMm(s); });
        simple.dayMorphT = 0;
    }
    function goToDay(idx) {
        // Cancel any in-flight pan/morph (a fling, a wheel notch, or a prior tap):
        // morphAnim and flickMorphAnim BOTH drive dayMorphT, so a leftover flick
        // morph would fight this one. (The old version only stopped posAnim.)
        idx = clampPos(idx);
        // Picked, so it stays highlighted even where the window cannot start on it
        // (the last day at 48 hours): the window then goes as far as it can.
        chosenDay = idx;
        var targetW = Math.round(clampHour(dayFirstSampleIndex(idx)));
        // Already there — nothing to pan or morph, only the highlight moves.
        if (targetW === Math.round(hourPos) && !posAnim.running && !flickAnim.running) return;
        posAnim.stop(); flickAnim.stop(); morphAnim.stop(); flickMorphAnim.stop(); lblMorphAnim.stop();
        _snapMorph(targetW);
        // Pan the strip to the target day...
        posAnim.from = simple.hourPos; posAnim.to = targetW; posAnim.start();
        // ...while the curve cross-fade and the held-then-ticked value labels outlast
        // the pan by morphSettleTail — the SAME lingering settle as a wheel/fling
        // morph (notchMorph), so a pill tap finishes the way a scroll does instead of
        // stopping dead with the strip.
        morphAnim.from = 0; morphAnim.to = 1;
        morphAnim.duration = posAnim.duration + morphSettleTail; morphAnim.start();
        simple.lblMorphT = 0;
        lblMorphDur = posAnim.duration + lblSettleTail; lblMorphAnim.start();
    }
    // A mouse-wheel notch is a DISCRETE jump (fixed target), so like a flick it can
    // morph: cross-fade the curve in place to targetW while flickAnim pans the strip
    // there. Repeated notches (a fast scroll) chain via the in-flight flickAnim target.
    // Touchpad pixel-scroll stays a 1:1 slide — it's continuous, so it can't morph.
    function notchMorph(targetW) {
        morphAnim.stop(); posAnim.stop();
        _snapMorph(targetW);
        var dur = simple.slideMs;
        flickAnim.stop(); flickAnim.from = simple.hourPos; flickAnim.to = targetW;
        flickAnim.duration = dur; flickAnim.start();
        flickMorphAnim.stop(); flickMorphAnim.from = 0; flickMorphAnim.to = 1;
        flickMorphAnim.duration = dur + morphSettleTail; flickMorphAnim.start();
        simple.lblMorphT = 0; lblMorphAnim.stop();
        lblMorphDur = dur + lblSettleTail; lblMorphAnim.start();
    }

    // toolbar buttons floated at the very top-right corner (mirrors FullView)
    WeatherToolbar {
        id: toolbar
        pad: simple.pad
        switchTooltip: i18n("Switch to card layout")
        switchIcon: "view-cards"
        showZoom: true
        root: weatherRoot
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: simple.pad
        anchors.rightMargin: simple.pad
        anchors.bottomMargin: simple.pad
        anchors.topMargin: simple.headerY
        spacing: Kirigami.Units.smallSpacing

        // ── Header ────────────────────────────────────────────────────────
        // Placed from the shared header geometry in WeatherToolbar (view coordinates,
        // converted here via headerY), so everything lands in the same spots as in the
        // card layout.
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            // Pinned to the top of its cell. A popup taller than the content gets the
            // spare height spread between the rows (which gives the rows below their
            // breathing room), and a centred header would drift down with it, away
            // from where the other layout shows the same icon and location.
            Layout.alignment: Qt.AlignTop
            spacing: Kirigami.Units.largeSpacing

            // Icon, temperature, condition and Weather Elements — the same block as the
            // card layout's (see HeaderHero); only what differs is handed in here.
            HeaderHero {
                id: heroRow
                Layout.alignment: Qt.AlignTop
                Layout.leftMargin: toolbar.heroRowX - simple.pad
                Layout.topMargin: toolbar.heroRowY - simple.headerY
                weatherRoot: simple.weatherRoot
                toolbar: toolbar
                metrics: simple.weatherRoot ? simple.weatherRoot.simpleHeaderMetrics : []
                selectedDay: simple.selectedDay
                // the hour under the pointer, else the one the graph is focused on
                sample: simple.hoveredSample || simple.focusedSample
                // what the header can be handed: any hour of the graph, any day button
                readingHours: simple.samples
                readingDays: simple.dayCount
                animate: simple.weatherRoot ? simple.weatherRoot.simpleHeaderAnim : false
                animCanBuild: simple.iconsLive
                animPlaying: simple.onScreen
            }

            Item { Layout.fillWidth: true }

            // Location, day pills and weather source — shared with the card layout, so
            // they hold the same spots in both (see HeaderRightBlock).
            HeaderRightBlock {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
                Layout.topMargin: toolbar.buttonCenterY - simple.headerY - capCenter
                Layout.rightMargin: toolbar.rightInset - simple.pad
                weatherRoot: simple.weatherRoot
                toolbar: toolbar
                originX: content.x + headerRow.x
                // The location line is above the Weather Elements, so it may run over
                // them; it only has to stay clear of the temperature.
                leftBound: content.x + headerRow.x + heroRow.x + heroRow.heroTempWidth + Kirigami.Units.largeSpacing * 2
                locationFontSize: weatherRoot ? weatherRoot.locationFontSize : 26
                providerFontSize: weatherRoot ? weatherRoot.providerFontSize : 16
                pillCount: weatherRoot ? weatherRoot.graphDays : 0
                selectedDay: simple.selectedDay
                onDayClicked: (index) => simple.goToDay(index)
                onDayStepped: (delta) => simple.stepDay(delta)
            }
        }

        // ── Graph: morphing curve + sliding icon/time filmstrip ────────────
        Item {
            id: graphArea
            Layout.fillWidth: true
            // pull the graph wider than the padded content column so it
            // stretches closer to the panel edges
            Layout.leftMargin: -simple.pad
            Layout.rightMargin: -simple.pad
            Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 0.6)   // lift the whole graph (curve + icon/time rows) up slightly
            Layout.preferredHeight: simple.plotH + simple.iconRowH + simple.timeRowH
                                    + Kirigami.Units.smallSpacing * 2
                                    + Kirigami.Units.gridUnit * 0.5
            clip: true

            // wheel scroll: touchpad pixels = 1:1 slide; mouse notch = discrete jump that morphs
            WheelHandler {
                id: graphWheel
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                // leftover angle delta between notches — a touchpad sends many small
                // ones, and they must add up to a notch rather than each firing a
                // fractional step. Named `acc` because Wheel.step() writes it.
                property real acc: 0
                onWheel: (wheel) => {
                    wheel.accepted = true;
                    var pd = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x
                           : wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : 0;
                    if (pd !== 0) {
                        // touchpad: 1:1 pixels, position follows the gesture (slides);
                        // continuous, so it can't morph (same as a slow finger-drag)
                        simple.cancelDayMorph();
                        posAnim.stop();
                        var hourW = simple.plotW / simple.pointsVisible;
                        var slid = simple.clampHour(simple.hourPos - pd / hourW);
                        if (slid !== simple.hourPos) simple.chosenDay = -1;
                        simple.hourPos = slid;
                    } else {
                        // mouse notch: a discrete jump → MORPH the curve in place to the
                        // target while the strip pans there (see notchMorph).
                        var adh = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                        // One step per event, and step from a WHOLE hour. hourPos is a
                        // real — a drag leaves it fractional, and a pan in flight is
                        // fractional by definition — so rounding the RESULT made one
                        // notch travel 2 hours one way and 1 the other. Rounding the
                        // BASE first makes every notch exactly `notch` hours.
                        var steps = Wheel.step(graphWheel, adh);
                        if (steps === 0) return;
                        // chain off whichever pan is in flight so rapid notches stack
                        var baseh = flickAnim.running ? flickAnim.to
                                  : posAnim.running   ? posAnim.to
                                  : simple.hourPos;
                        var targetW = simple.clampHour(Math.round(baseh) + steps * simple.scrollHours);
                        if (targetW === Math.round(simple.hourPos) && !flickAnim.running && !posAnim.running) return;
                        simple.chosenDay = -1;
                        simple.notchMorph(targetW);
                    }
                }
            }
            // free, pixel-sensitive horizontal drag with a momentum flick on release
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                property real startPos: 0
                property real startX: 0
                property real velocity: 0   // sample-index units / second, for the flick
                property real lastT: 0
                onPressed: (m) => {
                    posAnim.stop(); flickAnim.stop(); simple.cancelDayMorph();
                    // freeze the labelled columns for the duration of the drag
                    simple.dragLabelBase = Math.round(simple.hourPos);
                    startPos = simple.hourPos;
                    startX = m.x;
                    velocity = 0; lastT = Date.now();
                    simple.dragging = true;
                }
                onPositionChanged: (m) => {
                    if (!simple.dragging) return;
                    var now = Date.now(), dt = Math.max(1, now - lastT);
                    var hourW = simple.plotW / simple.pointsVisible;
                    var newH = simple.clampHour(startPos - (m.x - startX) / hourW);
                    velocity = 0.6 * velocity + 0.4 * ((newH - simple.hourPos) / dt * 1000);
                    if (newH !== simple.hourPos) simple.chosenDay = -1;   // a click alone keeps it
                    simple.hourPos = newH;
                    lastT = now;
                }
                onReleased: () => { simple.dragging = false; simple.flickTo(velocity); }
                onCanceled: () => { simple.dragging = false; }
            }

            Column {
                id: gcol
                width: graphArea.width
                spacing: Kirigami.Units.smallSpacing

                // ── plot (morphing canvas + value labels, in place) ──
                Item {
                    id: plot
                    width: gcol.width
                    height: simple.plotH

                    Canvas {
                        id: chart
                        anchors.fill: parent
                        // GPU-render the curve (FBO) so a full-width repaint every
                        // drag frame doesn't rasterise on the CPU — the main
                        // hourly-scroll cost. Threaded keeps the paint off the GUI
                        // thread (noticeably smoother during a continuous drag than
                        // Cooperative); risk is a rare threaded-GL driver glitch,
                        // which surfaces visually, not as a crash.
                        renderTarget: Canvas.FramebufferObject
                        renderStrategy: Canvas.Threaded
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Connections {
                            target: simple
                            function onCurTempsChanged()  { chart.requestPaint(); }
                            function onCurPrecipChanged() { chart.requestPaint(); }
                            function onCurSnowChanged()   { chart.requestPaint(); }
                            function onColorModeChanged()  { chart.requestPaint(); }
                            function onRevealChanged()     { chart.requestPaint(); }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var ct = simple.curTemps, cp = simple.curPrecip;
                            var n = ct.length;
                            if (n === 0) return;

                            var xs = [], ty = [], py = [];
                            for (var i = 0; i < n; ++i) {
                                xs.push(simple.xAt(i));
                                ty.push(simple.tempY(ct[i]));
                                py.push(simple.precipY(cp[i]));
                            }
                            var tCol = Kirigami.Theme.textColor;
                            // temperature fill + line: when colouring is on, a
                            // horizontal temp-colour gradient (cold blue → hot
                            // red), one stop per column, consistent across days
                            // via simple.tempDomain and lerping through the morph.
                            // When off, fall back to the flat neutral grey fade.
                            // horizontal gradient span (shared by temp + precip)
                            var gx0 = xs[0], gx1 = xs[n - 1];
                            if (gx1 <= gx0) gx1 = gx0 + 1;   // guard single point
                            // Start from the flat neutral pair, then colour whichever
                            // of the two the mode asks for — they are independent, so
                            // "Temperature curve & precipitation" can warm the line
                            // while the wash behind it stays grey.
                            var gray = ctx.createLinearGradient(0, simple.topReserve, 0, height);
                            gray.addColorStop(0, simple.rgba(tCol, 0.22));
                            gray.addColorStop(1, simple.rgba(tCol, 0.02));
                            var tBandStyle = gray;
                            // flat neutral line — the sun warmth now comes from the
                            // separate radial bloom pass (drawSunBloom), not a recolor.
                            var tLineStyle = simple.rgba(tCol, 0.85);
                            if (simple.colorTempLine || simple.colorTempBand) {
                                var bandGrad = ctx.createLinearGradient(gx0, 0, gx1, 0);
                                var lineGrad = ctx.createLinearGradient(gx0, 0, gx1, 0);
                                // sample the colour ramp at a fixed few stops (not
                                // one per column) — the gradient is smooth, so this
                                // looks identical but halves the per-frame work
                                var STOPS = Math.min(n, 7);
                                for (var k = 0; k < STOPS; ++k) {
                                    var off = STOPS === 1 ? 0 : k / (STOPS - 1);
                                    var tn = simple.tempNorm(ct[Math.round(off * (n - 1))]);
                                    bandGrad.addColorStop(off, simple.rampColor(tn, simple.bandAlpha));
                                    lineGrad.addColorStop(off, simple.rampColor(tn, 1));
                                }
                                if (simple.colorTempBand) tBandStyle = bandGrad;
                                if (simple.colorTempLine) tLineStyle = lineGrad;
                            }

                            // Draw order matters here. The precip/snow band is
                            // painted FIRST so a vertical opacity fade can be masked
                            // onto it ALONE (destination-in) — dense at its top edge,
                            // melting toward the floor — without touching the temp
                            // fill. The temp area is then laid in BEHIND the faded
                            // band (destination-over), so the temp wash shows through
                            // the band's lower, fainter reaches.

                            // precip fill/line: a horizontal gradient that tints
                            // white where the forecast precipitation is snow
                            // (per-point curSnow), rain-blue otherwise. Falls back
                            // to flat neutral grey when precip colouring is off.
                            var cs = simple.curSnow;
                            var pBandStyle, pLineStyle;
                            if (simple.colorPrecip) {
                                var pBand = ctx.createLinearGradient(gx0, 0, gx1, 0);
                                var pLine = ctx.createLinearGradient(gx0, 0, gx1, 0);
                                // one stop per column so a sharp snow/rain change
                                // between hours stays crisp instead of averaged away.
                                for (var pk = 0; pk < n; ++pk) {
                                    var poff = n === 1 ? 0 : pk / (n - 1);
                                    var sv = pk < cs.length ? simple.snowiness(cs[pk]) : 0;
                                    var pv = pk < cp.length ? cp[pk] : 0;
                                    pBand.addColorStop(poff, simple.precipColorAt(sv, pv, false));
                                    pLine.addColorStop(poff, simple.precipColorAt(sv, pv, true));
                                }
                                pBandStyle = pBand;
                                pLineStyle = pLine;
                            } else {
                                pBandStyle = simple.rgba(tCol, 0.16);
                                pLineStyle = simple.rgba(tCol, 0.5);
                            }

                            // precipitation area (flat-extended to both edges) — the
                            // shaded band beneath the rain curve, as dense as
                            // precipBandA asks for (0 = nothing but the line).
                            ctx.beginPath();
                            ctx.moveTo(0, py[0]);
                            ctx.lineTo(xs[0], py[0]);
                            simple.smoothMonotone(ctx, xs, py);
                            ctx.lineTo(width, py[n - 1]);
                            ctx.lineTo(width, height);
                            ctx.lineTo(0, height);
                            ctx.closePath();
                            ctx.fillStyle = pBandStyle;
                            ctx.fill();

                            // vertical wash: multiply the band's alpha by a top→floor
                            // ramp so it's dense at its top edge (the crisp precip
                            // line) and fades to precipFadeFloor at the floor. The
                            // canvas holds nothing but the band yet, so destination-in
                            // fades ONLY the band. Anchored screen-space from the
                            // band's highest point down — same y reads the same alpha.
                            var pTopY = Math.min.apply(null, py);
                            if (pTopY < height - 0.5) {
                                var vFade = ctx.createLinearGradient(0, pTopY, 0, height);
                                // shape the falloff: full at the top edge, then drop
                                // away steeply (precipFadeExp) so the lower band thins
                                // out fast instead of staying opaque down to the floor.
                                var FADE_STOPS = 6;
                                for (var fi = 0; fi <= FADE_STOPS; ++fi) {
                                    var ft = fi / FADE_STOPS;
                                    var fa = simple.precipFadeFloor
                                           + (1 - simple.precipFadeFloor) * Math.pow(1 - ft, simple.precipFadeExp);
                                    vFade.addColorStop(ft, "rgba(0,0,0," + fa.toFixed(3) + ")");
                                }
                                ctx.globalCompositeOperation = "destination-in";
                                ctx.fillStyle = vFade;
                                ctx.fillRect(0, 0, width, height);
                                ctx.globalCompositeOperation = "source-over";
                            }

                            // temperature area (flat-extended to both edges), laid in
                            // BEHIND the faded band via destination-over so the temp
                            // wash shows through where the band has thinned out.
                            ctx.beginPath();
                            ctx.moveTo(0, ty[0]);
                            ctx.lineTo(xs[0], ty[0]);
                            simple.smooth(ctx, xs, ty);
                            ctx.lineTo(width, ty[n - 1]);
                            ctx.lineTo(width, height);
                            ctx.lineTo(0, height);
                            ctx.closePath();
                            ctx.globalCompositeOperation = "destination-over";
                            ctx.fillStyle = tBandStyle;
                            ctx.fill();
                            ctx.globalCompositeOperation = "source-over";

                            // precipitation line
                            ctx.beginPath();
                            ctx.moveTo(0, py[0]);
                            ctx.lineTo(xs[0], py[0]);
                            simple.smoothMonotone(ctx, xs, py);
                            ctx.lineTo(width, py[n - 1]);
                            ctx.lineWidth = 2;
                            ctx.strokeStyle = pLineStyle;
                            ctx.stroke();

                            // sun bloom: the warm radial glow + line streak at each
                            // sunrise/sunset, under the crisp line so the line tops its glow.
                            simple.drawSunBloom(ctx, xs, ty, gx0, gx1, width);

                            // temperature line — drawn LAST so the temp curve always
                            // stays on top of the precip wash, even at 100% precip.
                            ctx.beginPath();
                            ctx.moveTo(0, ty[0]);
                            ctx.lineTo(xs[0], ty[0]);
                            simple.smooth(ctx, xs, ty);
                            ctx.lineTo(width, ty[n - 1]);
                            ctx.lineWidth = simple.colorTempLine ? 2.2 : 2;
                            ctx.strokeStyle = tLineStyle;
                            ctx.stroke();
                        }
                    }

                    // temperature value labels — one per curve column, shown on the
                    // hours showTempLabel() picks (axis hours + the day's extremes).
                    // The x of each is fixed by its column, so a label never slides.
                    //
                    // Which columns are labelled changes when the window moves, and it
                    // changes by a lot in the 48-hour view: a notch there replaces up to
                    // half the window, so around eight of the ~14 labels on screen belong
                    // to hours that have just arrived or just left. Flipping `visible`
                    // made those eight blink in and out at the moment the slide started;
                    // fading them dissolves one set into the other while the curve
                    // travels. The 12- and 24-hour views flip nothing at their default
                    // steps, so this costs them nothing.
                    Repeater {
                        model: simple.nPts
                        delegate: Label {
                            required property int index
                            readonly property bool labelled: simple.showTempLabel(simple.labelBase + index)
                            // tempStr prints a whole degree, so bind the text to the
                            // rounded value: it is recomputed every frame either way,
                            // but only signals a change when the digit actually turns —
                            // which is when the text needs building again.
                            readonly property real degree: Math.round(simple.lblTemps[index])
                            opacity: labelled ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: simple.lblFadeDur; easing.type: Easing.InOutQuad } }
                            x: simple.xAt(index) - width / 2
                            y: simple.curTempY(index) - height - Kirigami.Units.smallSpacing
                            text: weatherRoot ? weatherRoot.tempStr(degree) : ""
                            font.bold: true
                            font.pixelSize: weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13
                            color: Kirigami.Theme.textColor
                        }
                    }
                    // precip-% + snow readouts at FIXED curve columns, like the temp
                    // value labels above: each rides curPrecipY/curTempY and its VALUE
                    // MORPHS live as you scroll/day-morph (curPrecip/curSnow interpolate),
                    // so the number animates in place. Visibility is a STABLE threshold
                    // (chance ≥ pctLabelMin / snow ≥ 0.1 cm), not a moving-peak test —
                    // a column keeps its label while precip/snow is present there and
                    // only fades at the edges of a wet/snowy stretch, instead of blinking
                    // as a peak slides across columns. Top→bottom: snow, rain
                    // amount, chance (snow and rain amount are mutually exclusive).
                    Repeater {
                        model: simple.nPts
                        delegate: Column {
                            id: roGroup
                            required property int  index
                            readonly property real pVal: index < simple.curPrecip.length ? simple.curPrecip[index] : 0
                            // printed rounded, so bind the label to the rounded value
                            readonly property int  pInt: Math.round(pVal)
                            readonly property bool chanceOn: index < simple.curChanceOn.length && simple.curChanceOn[index] === 1
                            readonly property real sVal: index < simple.curSnow.length   ? simple.curSnow[index]   : 0
                            // The hour this column shows (the nearest one mid-scroll, the
                            // nearer snapshot mid-morph), and whether the readout plan
                            // labels it.
                            readonly property int nearG: simple.dayMorphT < 1
                                ? (simple.dayMorphT < 0.5 ? simple.morphFromBase : simple.morphToBase) + index
                                : (simple.curFrac < 0.5 ? simple.hourFloor : simple.hourCeil) + index
                            readonly property bool planned: simple.readoutShownAt(nearG)
                            // Precip % shows on EVERY hour above the threshold, including
                            // repeated flat runs (a steady 90% stretch is labelled every
                            // hour, not just at its start). It ALSO shows whenever this
                            // hour has an amount label (amtOn) — even below the threshold —
                            // so a shown amount always carries its chance alongside it.
                            // Snow shows on EVERY snowy hour too — a repeated amount
                            // is fresh accumulation (½in + ½in = 1in), not a repeat.
                            readonly property string sText:  (weatherRoot && sVal >= 0.1) ? weatherRoot.snowfallStr(sVal, true) : ""
                            // % visibility is a DETERMINISTIC function of the hour(s) this column
                            // represents — chance ≥ pctLabelMin OR a real amount — with NO sticky
                            // history. (The old hysteresis bled a wet hour's "on" onto dry
                            // neighbours: the fixed delegate slots get reused across hours while
                            // scrolling, so the same hour showed or hid depending on scroll path.)
                            // Mid-slide a column morphs between two hours, so OR both endpoints —
                            // a wet hour stays labelled across its one-hour transition and the
                            // label clears only once BOTH neighbours are dry. Settled (lo == hi)
                            // it reduces to the one real hour, so a given hour always reads the same.
                            function _onAt(arr, i) {
                                var s = i < arr.length ? arr[i] : null;
                                if (!s) return false;
                                // no chance published for this hour → nothing to print, even
                                // with an amount (that used to come out as "0%")
                                if (!weatherRoot || !weatherRoot.hasPrecipChance(s)) return false;
                                if (s.precip >= simple.pctLabelMin) return true;
                                return weatherRoot && weatherRoot.hasPrecipAmt(simple.precipMm(s));
                            }
                            readonly property bool pctOn: {
                                // Visibility tracks the NEAREST real hour to this slot, not an OR
                                // of both endpoints. OR kept a label lit over the gap between a wet
                                // and a dry hour, so a dry slot briefly showed a number mid-scroll
                                // then cleared on settle. Nearest flips once at the midpoint: the
                                // label travels with a wet hour and clears as a dry one becomes
                                // nearest. Settled (curFrac 0) it's the slot's own real hour.
                                if (!planned) return false;
                                if (simple.dayMorphT < 1)   // day-pill / fling: nearest morph snapshot
                                    return (simple.dayMorphT < 0.5 ? _pctOnAt(simple.morphFromP, simple.morphFromA, simple.morphFromC, index)
                                                                   : _pctOnAt(simple.morphToP,   simple.morphToA,   simple.morphToC,   index)) === 1;
                                return _onAt(simple.curFrac < 0.5 ? simple.loSamples : simple.hiSamples, index);
                            }
                            // Is the % label on for snapshot column i? — same rule as the
                            // settled state: chance over threshold, OR a real amount this hour.
                            function _pctOnAt(pArr, aArr, cArr, i) {
                                if (!(i < cArr.length && cArr[i])) return 0;   // no chance → no %
                                var p = i < pArr.length ? pArr[i] : 0;
                                if (p >= simple.pctLabelMin) return 1;
                                var a = i < aArr.length ? aArr[i] : 0;
                                return (weatherRoot && weatherRoot.hasPrecipAmt(a)) ? 1 : 0;
                            }
                            // Morph-tracked fade ONLY for a day-pill cross-fade (morphAnim): the
                            // % fades across the whole morph from its source-day to target-day
                            // visibility, so it finishes as the curve lands. A FLICK/wheel also
                            // drives dayMorphT but PANS the window, so a screen column maps to
                            // unrelated hours start vs end — there (and on scroll/settle) the
                            // plain on-flag + Behavior fade is correct.
                            readonly property real pctOpacity: {
                                if (!simple.showPrecipPct) return 0;   // hidden by the readout setting
                                if (morphAnim.running) {
                                    var fromOn = _pctOnAt(simple.morphFromP, simple.morphFromA, simple.morphFromC, index)
                                                 * (simple.readoutShownAt(simple.morphFromBase + index) ? 1 : 0);
                                    var toOn   = _pctOnAt(simple.morphToP,   simple.morphToA,   simple.morphToC,   index)
                                                 * (simple.readoutShownAt(simple.morphToBase + index) ? 1 : 0);
                                    return fromOn + (toOn - fromOn) * simple.dayMorphT;
                                }
                                return pctOn ? 1 : 0;
                            }
                            // Snow/amount visibility uses the NEAREST real hour (same rule as the
                            // chance %, see pctOn), so all three readout parts appear/clear together
                            // as you scroll instead of each flipping on its own interpolated
                            // threshold. The shown VALUE still morphs (sText/aText); only the
                            // show/hide point is unified.
                            function _nearSnow() {
                                if (simple.dayMorphT < 1) {
                                    var a = simple.dayMorphT < 0.5 ? simple.morphFromS : simple.morphToS;
                                    return index < a.length ? a[index] : 0;
                                }
                                var arr = simple.curFrac < 0.5 ? simple.loSamples : simple.hiSamples;
                                return index < arr.length ? simple.snowCm(arr[index]) : 0;
                            }
                            function _nearAmt() {
                                if (simple.dayMorphT < 1) {
                                    var a = simple.dayMorphT < 0.5 ? simple.morphFromA : simple.morphToA;
                                    return index < a.length ? a[index] : 0;
                                }
                                var arr = simple.curFrac < 0.5 ? simple.loSamples : simple.hiSamples;
                                return index < arr.length ? simple.precipMm(arr[index]) : 0;
                            }
                            readonly property bool   snowOn: planned && _nearSnow() >= 0.1
                            // Snow fades ACROSS a day-pill cross-fade (morphAnim) like the %,
                            // rather than popping at its 0.1in threshold partway through the
                            // morph. Scroll/settle keep the on-flag + Behavior fade.
                            readonly property real snowOpacity: {
                                if (!simple.showPrecipAmt) return 0;   // hidden by the readout setting
                                if (morphAnim.running) {
                                    var f = (index < simple.morphFromS.length ? simple.morphFromS[index] : 0) >= 0.1
                                            && simple.readoutShownAt(simple.morphFromBase + index) ? 1 : 0;
                                    var t = (index < simple.morphToS.length   ? simple.morphToS[index]   : 0) >= 0.1
                                            && simple.readoutShownAt(simple.morphToBase + index) ? 1 : 0;
                                    return f + (t - f) * simple.dayMorphT;
                                }
                                return snowOn ? 1 : 0;
                            }
                            // Liquid precip AMOUNT, shown on every wet hour like snow
                            // (each hour's rain is fresh, not a repeat). Gated on the
                            // FORMATTED value so a trace that rounds to "0.00 in" is
                            // hidden, and suppressed while it's snowing — the snow row
                            // above already carries that hour's accumulation.
                            readonly property real   aVal:   index < simple.curPrecipAmt.length ? simple.curPrecipAmt[index] : 0
                            // aVal morphs every frame of a scroll; aQ is the same number
                            // rounded to what actually gets printed, so the formatting
                            // below runs when the text changes rather than every frame.
                            readonly property real   aQ:     weatherRoot ? weatherRoot.precipAmtQ(aVal) : 0
                            readonly property string aText:  weatherRoot ? weatherRoot.precipAmtStr(aQ) : ""
                            // (the snow check reads the amount itself, not snowOn, which the
                            // readout plan can switch off for an hour it doesn't label)
                            readonly property bool   amtOn:  planned && _nearSnow() < 0.1 && weatherRoot
                                                             && weatherRoot.hasPrecipAmt(_nearAmt())
                            // Amount fades across a day-pill morph like the % and snow. On at a
                            // snapshot column = a real amount AND not snowing there (snow's label
                            // carries that hour instead). Scroll/settle keep the Behavior fade.
                            function _amtOnAt(sArr, aArr, i) {
                                if ((i < sArr.length ? sArr[i] : 0) >= 0.1) return 0;   // snowing → snow owns the slot
                                var a = i < aArr.length ? aArr[i] : 0;
                                return (weatherRoot && weatherRoot.hasPrecipAmt(a)) ? 1 : 0;
                            }
                            readonly property real amtOpacity: {
                                if (!simple.showPrecipAmt) return 0;   // hidden by the readout setting
                                if (morphAnim.running) {
                                    var f = _amtOnAt(simple.morphFromS, simple.morphFromA, index)
                                            * (simple.readoutShownAt(simple.morphFromBase + index) ? 1 : 0);
                                    var t = _amtOnAt(simple.morphToS,   simple.morphToA,   index)
                                            * (simple.readoutShownAt(simple.morphToBase + index) ? 1 : 0);
                                    return (f + (t - f) * simple.dayMorphT) * 0.9;
                                }
                                return amtOn ? 0.9 : 0;
                            }
                            // each readout fades itself (below) so a value crossing its
                            // threshold while scrolling animates in/out instead of popping.
                            // BUT sText/aText blank EXACTLY when snowOn/amtOn flip false,
                            // so the fade-OUT would have an empty string to fade (= an
                            // instant vanish, not a fade). Latch the last non-empty text in
                            // sShown/aShown so the label keeps something visible while it
                            // fades out, then catches the new value on the way back in. (The
                            // chance label needs no latch — its "NN%" text is always set.)
                            property string sShown: ""
                            property string aShown: ""
                            onSTextChanged: if (sText.length > 0) sShown = sText
                            onATextChanged: if (aText.length > 0) aShown = aText
                            spacing: 1
                            x: Math.max(0, simple.xAt(index) - width / 2)
                            y: Math.max(0, simple.readoutTopFor(simple.curTempY(index),
                                                               simple.curPrecipY(index), height))
                            // Snow + rain-amount share ONE fixed-height slot above the
                            // chance. They're mutually exclusive, so one cross-fades into
                            // the other IN PLACE; and because the slot's height is FIXED
                            // (never collapses), toggling either never reflows the group —
                            // it's a pure opacity fade, no vertical "slide". An empty slot
                            // is just transparent space over the graph (invisible), and the
                            // group is at most 2 lines (slot + chance), same as before.
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.max(snowLbl.implicitWidth, amtLbl.implicitWidth)
                                height: simple.showPrecipAmt ? simple.readoutRowH : 0
                                Label {
                                    id: snowLbl
                                    anchors.centerIn: parent
                                    opacity: roGroup.snowOpacity
                                    // disabled during a day-pill morph: snowOpacity rides
                                    // dayMorphT directly, so the Behavior would fight it.
                                    Behavior on opacity { enabled: !morphAnim.running; NumberAnimation { duration: roGroup.snowOn ? simple.readoutFadeDur : simple.readoutFadeOutDur; easing.type: Easing.InOutQuad } }
                                    text: roGroup.sShown
                                    color: simple.snowLabelColor
                                    font.bold: true
                                    font.pixelSize: simple.graphReadoutFontSize
                                }
                                // amount is a finer, lighter detail so the % stays prominent
                                Label {
                                    id: amtLbl
                                    anchors.centerIn: parent
                                    opacity: roGroup.amtOpacity   // 0.9 = its lighter "detail" base
                                    Behavior on opacity { enabled: !morphAnim.running; NumberAnimation { duration: roGroup.amtOn ? simple.readoutFadeDur : simple.readoutFadeOutDur; easing.type: Easing.InOutQuad } }
                                    text: roGroup.aShown
                                    color: simple.colorPrecip ? simple.precipColor : Kirigami.Theme.textColor
                                    font.pixelSize: Math.round(simple.graphReadoutFontSize * 0.85)
                                }
                            }
                            // chance % — the bottom readout row. Collapses to nothing for an
                            // hour with no published chance, so the amount above sits where
                            // the % would have been rather than over an empty row. Chance
                            // availability doesn't change while scrolling a single provider's
                            // data, so this never reflows mid-gesture.
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: pctLbl.implicitWidth
                                height: (roGroup.chanceOn && simple.showPrecipPct) ? simple.readoutRowH : 0
                                Label {
                                    id: pctLbl
                                    anchors.centerIn: parent
                                    opacity: roGroup.pctOpacity
                                    visible: opacity > 0
                                    // disabled only during a day-pill morph: morphAnim drives
                                    // pctOpacity frame-by-frame, so the Behavior would fight it.
                                    // Enabled for flick/scroll/settle so those still fade normally.
                                    Behavior on opacity { enabled: !morphAnim.running; NumberAnimation { duration: roGroup.pctOn ? simple.readoutFadeDur : simple.readoutFadeOutDur; easing.type: Easing.InOutQuad } }
                                    text: roGroup.pInt + "%"
                                    color: simple.colorPrecip ? simple.precipColor : Kirigami.Theme.textColor
                                    font.bold: true
                                    font.pixelSize: simple.graphReadoutFontSize
                                }
                            }
                        }
                    }
                    // New-day markers: moon + date over a dashed line down to the
                    // floor, at any fixed column whose hour is 00:00 (it snaps column
                    // to column as you scroll, in keeping with the reshape-in-place
                    // columns).
                    Repeater {
                        model: simple.dayStartsInWindow
                        delegate: Item {
                            id: dayMarker
                            required property var modelData        // the midnight's global sample index
                            readonly property int g: modelData
                            readonly property var sample: (g >= 0 && g < simple.samples.length) ? simple.samples[g] : null
                            readonly property real lineX: simple.hourX(g)
                            // day-representative forecast entry (matches the Card day
                            // tab), keyed by the marker's date rather than the 00:00 code
                            readonly property var dayEntry: (weatherRoot && sample)
                                ? weatherRoot.dailyData[weatherRoot.dayIndexForDate(sample.date)] : null
                            visible: sample !== null
                                     && lineX > -width && lineX < plot.width + width
                            width: markerRow.width
                            height: markerRow.height
                            // centred on the line, but never cut off by a plot edge
                            // while the line is on screen (see dayMarkerX)
                            x: simple.dayMarkerX(lineX, width)
                            y: {
                                var cy = simple.markerCurveY(g, lineX);
                                var tLabelH = (weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13) * 1.4;
                                return Math.max(0, cy - tLabelH - height
                                                   - simple.markerLift(g, x + width / 2 - lineX));
                            }
                            Row {
                                id: markerRow
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    // new-day marker icon — a touch larger than the row text, and
                                    // scaled with the day label's font so the two stay in proportion
                                    width: weatherRoot ? Math.round(weatherRoot.simpleDayMarkerFontSize * 2.25) : 27
                                    height: width
                                    roundToIconSize: false   // render at the exact size; don't snap to 22/32
                                    anchors.verticalCenter: parent.verticalCenter
                                    // the monochrome pack is drawn in the theme's text colour
                                    isMask: weatherRoot ? weatherRoot.iconPackIsMask : false
                                    color: Kirigami.Theme.textColor
                                    source: (weatherRoot && dayMarker.dayEntry)
                                            ? weatherRoot.conditionIcon(dayMarker.dayEntry.code, 1)
                                            : "weather-clear-night"
                                }
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    // weekday + day and month in the system's date format,
                                    // or the weekday alone
                                    text: (weatherRoot && dayMarker.sample) ? weatherRoot.dayMarkerText(dayMarker.sample.date) : ""
                                    font.bold: true
                                    opacity: 0.8
                                    font.pixelSize: weatherRoot ? weatherRoot.simpleDayMarkerFontSize : 12
                                }
                            }
                            // The dashed line, from the marker's own bottom edge down to
                            // the floor of the graph. Plain rectangles, not a Canvas: a
                            // Canvas spanning the plot has to re-rasterise on the CPU
                            // every frame the curve moves under it, while these are
                            // scene-graph nodes the renderer only translates. Being part
                            // of the marker also means the line cannot drift from it —
                            // they share one y instead of recomputing the same lift twice.
                            // It stays on the midnight itself when an edge holds the
                            // marker off-centre, so it can hang from anywhere under it.
                            Item {
                                x: Math.round(dayMarker.lineX - dayMarker.x)
                                y: dayMarker.height
                                width: 1
                                height: Math.max(0, plot.height - dayMarker.y - dayMarker.height)
                                clip: true   // the dash run is cut to length here
                                Column {
                                    spacing: simple.dayLineGap
                                    Repeater {
                                        model: simple.dayLineDashes
                                        delegate: Rectangle {
                                            width: 1
                                            height: simple.dayLineDash
                                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                                           Kirigami.Theme.textColor.b, 0.45)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // sunrise / sunset glyph + time, pinned above the temp label at the
                    // curve x where the line picks up its warm bloom (same xAtTime
                    // mapping, so glyph and bloom stay aligned through scroll/morph).
                    // High z keeps the whole marker ABOVE every other graph label
                    // (temp numbers, precip %/amount) when columns crowd together.
                    Repeater {
                        model: simple.sunMarkerModel
                        delegate: Column {
                            required property var modelData
                            readonly property real mx: simple.xAtTime(modelData.ms)
                            readonly property real sz: weatherRoot ? Math.round(weatherRoot.hourlyInfoFontSize * 3.1) : 34
                            z: 50
                            spacing: -Math.round(sz * 0.22)   // pull the time up under the icon's empty bottom margin
                            visible: !isNaN(mx) && mx > -sz && mx < plot.width + sz
                            x: mx - width / 2
                            // above the temp number when there's headroom; when the curve
                            // rides high (no room for the icon+time+readout stack) drop
                            // BELOW the line, where nothing else is drawn. Instead of
                            // SKIPPING between the two, animate the flip: belowF eases 0↔1
                            // and y lerps between the above/below anchors. Both anchors
                            // track the live curve, so only the FLIP animates — continuous
                            // curve-tracking stays lag-free (belowF holds at 0 or 1).
                            readonly property real markGap: simple.sunMarkGap
                            readonly property real cyV: simple.curveYAtX(mx)
                            readonly property real aboveY: cyV
                                - ((weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13) * 1.4)
                                - height - markGap - simple.sunMarkerLift(mx, height)
                            readonly property real belowY: cyV + markGap
                            readonly property bool wantBelow: aboveY < 2
                            property real belowF: wantBelow ? 1 : 0
                            Behavior on belowF { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                            y: aboveY + (belowY - aboveY) * belowF
                            Kirigami.Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.sz; height: parent.sz
                                roundToIconSize: false   // exact size; don't snap to 22/32
                                // sunset glyph recoloured to match its time label (sunGold);
                                // the full-colour SVG needs isMask to accept a flat tint.
                                // sunrise keeps its natural artwork (isMask false → colour ignored).
                                isMask: !parent.modelData.rise
                                color: simple.sunGold
                                source: weatherRoot
                                        ? weatherRoot.sunEventIcon(parent.modelData.rise)
                                        : ""
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: weatherRoot ? simple.sunTimeLabel(parent.modelData.ms) : ""
                                // each time matches its own glyph: sunrise the icon's gold, sunset sunGold
                                color: parent.modelData.rise ? simple.sunRiseColor : simple.sunGold
                                font.bold: true
                                font.pixelSize: weatherRoot ? weatherRoot.hourlyInfoFontSize : 11
                            }
                        }
                    }
                }

                // small gap between the graph and the icon row (the icon + time
                // rows below sit just under the graph)
                Item { width: 1; height: Kirigami.Units.gridUnit * 0.1 }

                // ── hour icons ──
                Item {
                    width: gcol.width
                    height: simple.iconRowH
                    clip: true
                    // A sliding pool of icons — stable delegates that pan via
                    // hourX and recycle their hour once per window shift.
                    Repeater {
                        model: simple.filmCount
                        delegate: Item {
                            id: hrIconC
                            required property int index
                            readonly property int g: simple.filmG(index)
                            readonly property var modelData: (g >= 0 && g < simple.samples.length) ? simple.samples[g] : null
                            readonly property real cx: simple.hourX(g)
                            // Only labelled hours get an icon — at day width the curve
                            // has 24 points and 24 icons would overlap into a smear.
                            visible: shown && cx > -width && cx < gcol.width + width
                            width: weatherRoot ? weatherRoot.simpleHourlyIconSize : 24
                            height: width
                            x: cx - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            // the pool only holds labelled hours now (see filmBase), so this
                            // is just "is there a sample here"
                            readonly property bool shown: modelData !== null
                            ConditionIcon {
                                anchors.fill: parent
                                weatherRoot: simple.weatherRoot
                                // probability-aware code: a likely-rain hour shows rain even if the code reads cloudy
                                code: (weatherRoot && hrIconC.modelData)
                                    ? weatherRoot.precipAwareCode(hrIconC.modelData.code, hrIconC.modelData.precip,
                                                                  hrIconC.modelData.precipAmt, hrIconC.modelData.snow,
                                                                  hrIconC.modelData.temp) : -1
                                day: hrIconC.modelData ? hrIconC.modelData.day : 1
                                cloud: hrIconC.modelData ? hrIconC.modelData.cloud : NaN
                                animate: weatherRoot ? weatherRoot.simpleAnimatedIcons : false
                                // These slots are recycled: mid-scroll a slot takes a new hour at
                                // every step. A condition already on screen switches at once (the
                                // animation is shared); one never built waits for the graph to rest.
                                canBuild: simple.iconsLive && !simple.scrolling
                                playing: simple.onScreen && !simple.scrolling
                            }
                        }
                    }
                }

                // ── time axis ──
                Item {
                    width: gcol.width
                    height: simple.timeRowH
                    clip: true
                    // A sliding pool of hour labels that pan with the scroll
                    Repeater {
                        model: simple.filmCount
                        delegate: Label {
                            required property int index
                            readonly property int g: simple.filmG(index)
                            readonly property var modelData: (g >= 0 && g < simple.samples.length) ? simple.samples[g] : null
                            readonly property real cx: simple.hourX(g)
                            visible: modelData !== null
                                     && cx > -width && cx < gcol.width + width
                            x: cx - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData ? new Date(modelData.time).toLocaleTimeString(Qt.locale(), weatherRoot && weatherRoot.use24Hour ? "H:mm" : "h AP") : ""
                            font.pixelSize: weatherRoot ? weatherRoot.simpleHourFontSize : 11
                        }
                    }
                }
            }

            // ── hover scrubbing ──
            // Topmost on purpose, ABOVE the labels. The drag MouseArea underneath
            // used to do this, but hover events go to the frontmost item that wants
            // them and do not fall through — so the moment the pointer crossed an
            // hour, temperature or day label the drag area stopped seeing it, the
            // hovered hour cleared, and the readouts snapped back to the current
            // hour. Sitting on top means nothing in the graph can shadow it.
            //
            // acceptedButtons: NoButton keeps it hover-only: presses, drags and
            // flicks pass straight through to the MouseArea below, so scrolling is
            // untouched.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onPositionChanged: (m) => { simple.hoveredSample = simple.sampleAtX(m.x); }
                onExited: simple.hoveredSample = null
                onContainsMouseChanged: if (!containsMouse) simple.hoveredSample = null
            }
        }
    }
}
