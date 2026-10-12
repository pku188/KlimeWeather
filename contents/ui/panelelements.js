/*
 * The panel's elements (Appearance → Panel → Panel Elements): what the panel shows and
 * in which order, each { id, shown }, stored as JSON in panelElements. Shared by the
 * panel (main.qml) and the settings page, which also lists the ones not on the panel.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
.pragma library

// The readings, in the order of the older panelSecondLine values (0–11).
var readings = ["hiLo", "precipRate", "wind", "feelsLike", "humidity", "precipSum",
                "uv", "pressure", "sun", "dewPoint", "snowSum", "cloud"];
// Every element: the weather icon, the temperature, the location's name, the
// condition's, and the readings.
var all = ["icon", "temp", "location", "condition"].concat(readings);

// The stored list, without unknown or repeated ids. Never edited (empty): what the
// older "Panel display" showed — `display` its mode (-1 never chosen: `detailed`, the
// older checkbox, decides) and `secondLine` the detailed view's reading. The icon and
// the temperature stay in the list where that display left one out, only hidden.
function parse(json, display, detailed, secondLine) {
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
    var m = display >= 0 ? Math.min(4, display) : (detailed ? 3 : 0);
    var legacy = [{ id: "icon", shown: m !== 2 }, { id: "temp", shown: m !== 1 }];
    if (m === 3) legacy.push({ id: readings[secondLine] || "hiLo", shown: true });
    if (m === 4) legacy.push({ id: "condition", shown: true });
    return legacy;
}

// The list as stored.
function stringify(list) {
    return JSON.stringify(list.map(function (el) { return { id: el.id, shown: el.shown !== false }; }));
}
