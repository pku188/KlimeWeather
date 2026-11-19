/*
 * The forecasts the widget can show, the ones General settings offer for the default
 * and the alternative forecast, which the header's source button switches between:
 * Open-Meteo's models (OpenMeteo.qml), and MET Norway's own forecast (MetNo.qml),
 * listed after Open-Meteo's copy of it. The two aren't the same: in the Nordic
 * countries they agree for the first two or three days only, and elsewhere
 * Open-Meteo's is ECMWF's model as it is, while MET Norway's is its own forecast,
 * made from ECMWF's.
 *
 * Each is { id, provider, name, text }: the id the settings store (an Open-Meteo
 * models= name, or "metno"), the provider that fetches it (a key of main.qml's
 * `providers`), the name the source button shows and the name the settings list.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
.pragma library

// Open-Meteo's models, with MET Norway's own forecast after its copy of it.
function list(models, metNo) {
    var out = [];
    for (var i = 0; i < models.length; ++i) {
        out.push(Object.assign({ provider: "openmeteo" }, models[i]));
        if (models[i].id === "metno_seamless") out.push(metNo);
    }
    if (out.indexOf(metNo) < 0) out.push(metNo);
    return out;
}

// The forecast with this id, or null.
function find(list, id) {
    for (var i = 0; i < list.length; ++i)
        if (list[i].id === id) return list[i];
    return null;
}
