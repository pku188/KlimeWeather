/*
 * The Detailed view's elements (Appearance → Detailed view → Detailed view Elements):
 * what the view shows and in which order, each { id, shown }, stored as JSON in
 * detailedViewElements, three to a row. Shared by the view (main.qml) and its
 * settings page.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
.pragma library

// Every element, in the order the view starts with: the sun, the date and the moon
// on the first row, then the hour's weather and temperature ("weather"), then the
// rest of the Weather Elements.
var all = ["sun", "date", "moon", "weather", "feelsLike", "hiLo", "wind", "precipRate", "precipSum", "pressure",
           "uv", "cloud", "dewPoint", "humidity", "snowSum"];

// The stored list, without unknown or repeated ids; never edited (empty): all of them,
// in the order above.
function parse(json) {
    if (json) {
        var list;
        try { list = JSON.parse(json); } catch (e) { list = null; }
        if (Array.isArray(list)) {
            var seen = {}, out = [];
            for (var i = 0; i < list.length; ++i) {
                var el = list[i];
                if (!el || all.indexOf(el.id) < 0 || seen[el.id]) continue;
                seen[el.id] = true;
                out.push({ id: el.id, shown: el.shown !== false });
            }
            return out;
        }
    }
    return all.map(function (id) { return { id: id, shown: true }; });
}

// The list as stored.
function stringify(list) {
    return JSON.stringify(list.map(function (el) { return { id: el.id, shown: el.shown !== false }; }));
}

// Rows of the shown ids, three to a row.
function rows(list) {
    var ids = list.filter(function (el) { return el.shown; }).map(function (el) { return el.id; });
    var out = [];
    for (var i = 0; i < ids.length; i += 3) out.push(ids.slice(i, i + 3));
    return out;
}
