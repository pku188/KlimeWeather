.pragma library
// How bold the widget draws the Meteocons icons it keeps as SVG text
// (contents/icons/meteocons/readings/*.js and weather.js): how many units (of the
// icons' 128-unit box) wider each of their lines is drawn, by style and by where they
// show. Meteocons' 2–4 unit lines came out under a pixel wide at the widget's sizes.
//   small    — the reading icons in the header, the hourly cards, the panel and the
//              graph's sunrise and sunset
//   detailed — the reading icons in the Detailed view, which are larger
//   panel    — the panel's weather icon
// The flat style's icons are solid and drawn as they are.
// Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later

var weight = {
    // small: at 5 the details clogged; detailed: 3 looked too heavy there
    monochrome: { small: 2, detailed: 0, panel: 1 },
    // small: the humidity drop's "%" and the snowflake's branches are the first to run
    // together as it grows; at 2 they still read apart
    line:       { small: 2, detailed: 0, panel: 2 }
    // panel: at 1 the weather icon read hardly bolder than the files at a panel's size
};

// `svg` drawn at `weight`: its stroke widths written "+N" (the lines that grow, marked
// by tools/icon-pipeline/meteocons_packs.py) become N + weight. A filled shape grows by
// a "+0" stroke of its own colour round it, so its outline is as much wider.
function weighted(svg, weight) {
    return svg.replace(/stroke-width="\+([0-9.]+)"/g, function (m, base) {
        return 'stroke-width="' + Math.round((parseFloat(base) + weight) * 1000) / 1000 + '"';
    });
}
