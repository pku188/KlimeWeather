/*
 * Open-Meteo provider adapter.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Weather data from Open-Meteo (https://open-meteo.com), a free, no-key public API.
 *
 * ── The provider contract ────────────────────────────────────────────────
 * A provider turns ONE HTTP GET into the normalized model the rest of the
 * widget reads. It owns the API's URL shape and its response format — and
 * NOTHING else. The request lifecycle (abort, timeout, watchdog, boot probe)
 * lives in main.qml's fetchWeather, so every provider inherits the same
 * boot-resilience behaviour for free.
 *
 *   buildUrl(ctx)      → the request URL
 *   requestHeaders     → [[name, value], …] applied before send (may be empty)
 *   parse(text, ctx)   → the normalized model below, or throws
 *
 * ctx = { lat, lon, forecastDays, utcOffsetSeconds }
 *   lat/lon are ALREADY coarsened (see coarseCoord in main.qml) — a provider
 *   must never see the full-precision coordinate.
 *   utcOffsetSeconds is the location's offset as main.qml resolved it, for a
 *   provider whose API has no timezone; one that reports its own may ignore it.
 *
 * UNITS are fixed, whatever the user picked: temperatures in °C, wind in km/h,
 * precipitation in mm, snowfall in cm, air pressure in hPa (at sea level). main.qml converts to the user's units once,
 * for every provider (convertUnits) — so no provider converts on its own, and
 * switching °C/°F re-applies the data already held instead of fetching again.
 *
 * The normalized model — the ONLY shape the views know about:
 *   {
 *     utcOffsetSeconds: Number|NaN,   // of the LOCATION, not the viewer
 *     current: { temperature, weatherCode, apparentTemp, humidity, dewPoint, isDay,
 *                uvIndex, precipRate, windSpeed, windGust, cloudCover, pressure },
 *     daily:  [ { date, code, hi, lo, snowSum, precipSum, sunrise, sunset } ],
 *     hourly: [ { time, date, spanHours, temp, feels, code, day, humidity, dew, uv,
 *                 precip, precipAmt, snow, cloud, wind, gust, windDir, pressure } ]
 *   }
 * `code` is a WMO weather code in BOTH arrays — the icon packs, conditionText,
 * conditionStem and precipAwareCode are all keyed on it, so a provider whose
 * API speaks another vocabulary maps INTO WMO here rather than teaching the
 * rest of the widget a second one.
 * `time` is a LOCAL naive ISO string ("2026-06-16T14:00") and `date` its
 * "YYYY-MM-DD" prefix — timeline() and the hourly grid compare dates lexically
 * and parse times in the location's wall clock via locNow().
 * `spanHours` is how many hours a sample covers — 1 for a true hourly forecast,
 * 6 for the coarse blocks met.no falls back to past ~54 h. The views read it to
 * decide whether to draw an hour or a block.
 * A sample covers the hours that START at its `time`: its amounts (precipAmt, snow),
 * chance (precip), gust, UV index and condition (code) are over those hours, the
 * rest are readings at `time`. isCurrentSample and the graph's rain curve read it
 * so, and so does met.no publish; an API that stamps a span with its END moves it
 * here (see Open-Meteo's parse).
 * Missing values are NaN (never undefined) so the isNaN() guards downstream hold.
 *
 * A provider also declares one capability the fetch lifecycle acts on:
 *   conditional     — send If-Modified-Since and honour 304 (met.no requires it)
 */
import QtQuick

QtObject {
    readonly property string providerId:     "openmeteo"
    readonly property string displayName:    "Open-Meteo"
    readonly property string attribution:    i18n("Weather data by Open-Meteo.com")
    readonly property string attributionUrl: "https://open-meteo.com"
    // Header source button: logo mark under contents/icons/providers/, and its
    // width:height, so the mark can be laid out at a set height without distortion.
    readonly property string logo:           "openmeteo.svg"
    readonly property real   logoAspect:     1

    // Open-Meteo needs no identifying header (contrast met.no, whose terms
    // require one) — the lifecycle in main.qml applies whatever is listed here.
    readonly property var requestHeaders: []

    // No conditional-request obligation.
    readonly property bool conditional: false

    // ── The forecast model ──
    // Which of Open-Meteo's models to forecast with (Settings → General), by its
    // models= name. best_match is Open-Meteo's own pick for the location: the
    // default, asked for with no models= at all, so its requests stay as they always
    // were. A name not in the list below (a hand-edited config) counts as best_match,
    // as Open-Meteo turns away a request naming a model it doesn't know.
    property string forecastModel: "best_match"
    // The models offered: Open-Meteo's pick, ECMWF's worldwide model, then the
    // national weather services', by country. Most national ones are "seamless": the
    // service's fine model in and around its country, blended with a global one
    // beyond its area and past its range.
    readonly property var models: [
        { id: "best_match",                 text: i18n("Best match") },
        { id: "ecmwf_ifs",                  text: modelLabel("ECMWF", i18n("worldwide")) },
        { id: "geosphere_seamless",         text: modelLabel("GeoSphere", i18n("Austria")) },
        { id: "gem_seamless",               text: modelLabel("GEM", i18n("Canada")) },
        { id: "cma_grapes_global",          text: modelLabel("CMA", i18n("China")) },
        { id: "chmi_aladin_seamless",       text: modelLabel("CHMI", i18n("Czechia")) },
        { id: "dmi_seamless",               text: modelLabel("DMI", i18n("Denmark")) },
        { id: "meteofrance_seamless",       text: modelLabel("Météo-France", i18n("France")) },
        { id: "dwd_icon_seamless",          text: modelLabel("DWD ICON", i18n("Germany")) },
        { id: "italia_meteo_arpae_icon_2i", text: modelLabel("ItaliaMeteo", i18n("Italy")) },
        { id: "jma_seamless",               text: modelLabel("JMA", i18n("Japan")) },
        { id: "knmi_seamless",              text: modelLabel("KNMI", i18n("Netherlands")) },
        { id: "metno_seamless",             text: modelLabel("MET Norway", i18n("Nordic countries")) },
        { id: "meteoswiss_icon_seamless",   text: modelLabel("MeteoSwiss", i18n("Switzerland")) },
        { id: "ukmo_seamless",              text: modelLabel("Met Office", i18n("United Kingdom")) },
        { id: "ncep_gfs_seamless",          text: modelLabel("NOAA GFS", i18n("United States")) }
    ]
    function modelLabel(service, area) {
        return i18nc("@item:inlistbox a weather service, then the area its forecast model is made for",
                     "%1 (%2)", service, area);
    }
    // the model to ask for by name; "" for Open-Meteo's own pick
    readonly property string chosenModel: {
        if (forecastModel === "best_match") return "";
        for (var i = 0; i < models.length; ++i)
            if (models[i].id === forecastModel) return forecastModel;
        return "";
    }

    function buildUrl(ctx) {
        return "https://api.open-meteo.com/v1/forecast"
             + "?latitude=" + ctx.lat
             + "&longitude=" + ctx.lon
             + "&current=temperature_2m,weather_code,apparent_temperature,relative_humidity_2m,dew_point_2m,is_day,uv_index,precipitation,wind_speed_10m,wind_gusts_10m,cloud_cover,pressure_msl"
             + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,snowfall_sum,sunrise,sunset"
             + "&hourly=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,dew_point_2m,uv_index,precipitation_probability,precipitation,snowfall,wind_speed_10m,wind_direction_10m,wind_gusts_10m,cloud_cover,pressure_msl"
             // a chosen model, and best_match to fill in what it leaves out (see parse)
             + (chosenModel ? "&models=" + chosenModel + ",best_match" : "")
             + "&forecast_days=" + ctx.forecastDays
             + "&timezone=auto"
             // the contract's fixed units; main.qml converts to the user's
             + "&wind_speed_unit=kmh"
             + "&temperature_unit=celsius";
    }

    // ── Reading the response ──
    // With a model chosen, the request names it and best_match (see buildUrl), and
    // every hourly and daily variable comes twice, named after its model
    // ("temperature_2m_geosphere_seamless", "temperature_2m_best_match"); without one
    // the names are plain. Each value the chosen model lacks (null) is filled from
    // best_match's: most models forecast no UV index, several stop days short of the
    // week, and outside its area a national model can have nothing at all.
    function parse(text, ctx) {
        var data = JSON.parse(text);
        var out = {
            utcOffsetSeconds: (data.utc_offset_seconds !== undefined) ? data.utc_offset_seconds : NaN,
            current: null,
            daily: [],
            hourly: []
        };
        // the chosen model as the response names it, read off the response itself
        // (not forecastModel), so a cached one parses as it was asked for
        var chosen = chosenIn(data.hourly);
        var hh = data.hourly, dd = data.daily;

        // Open-Meteo already speaks WMO codes and the contract's units (asked for in
        // the query), so "mapping" here is a straight field rename — the adapter earns
        // its keep on other APIs.
        var c = data.current;
        if (c) {
            // The current conditions are the chosen model's alone (the first one asked
            // for); a value it lacks is best_match's at the hour nearest to now.
            var near = -1;
            if (chosen && hh && hh.time && c.time) {
                near = hh.time.indexOf(c.time.substring(0, 13) + ":00");
                if (near >= 0 && near + 1 < hh.time.length && parseInt(c.time.substring(14, 16), 10) >= 30)
                    ++near;
            }
            var now = function (name, missing) {
                var v = c[name];
                if (v !== null && v !== undefined) return v;
                return valueAt(near >= 0 ? hh[name + "_best_match"] : null, near, missing);
            };
            out.current = {
                temperature:  now("temperature_2m"),
                weatherCode:  now("weather_code", -1),
                apparentTemp: now("apparent_temperature"),
                humidity:     now("relative_humidity_2m"),
                dewPoint:     now("dew_point_2m"),
                isDay:        now("is_day", 1),
                uvIndex:      now("uv_index"),
                // mm/h: the current precipitation is the sum over the response's
                // interval (15 minutes); a fallback from the hourly data, over an hour
                precipRate:   (c.precipitation !== null && c.precipitation !== undefined)
                              ? c.precipitation * 3600 / (c.interval > 0 ? c.interval : 3600)
                              : now("precipitation"),
                windSpeed:    now("wind_speed_10m"),
                windGust:     now("wind_gusts_10m"),
                cloudCover:   now("cloud_cover"),
                // hPa at sea level — the contract's unit, and Open-Meteo's own
                pressure:     now("pressure_msl")
            };
        }

        if (dd && dd.time) {
            var dCode = column(dd, "weather_code", chosen),
                dHi = column(dd, "temperature_2m_max", chosen),
                dLo = column(dd, "temperature_2m_min", chosen),
                dSnow = column(dd, "snowfall_sum", chosen),
                dPrecip = column(dd, "precipitation_sum", chosen),
                dRise = column(dd, "sunrise", chosen),
                dSet = column(dd, "sunset", chosen),
                dChance = column(dd, "precipitation_probability_max", chosen);
            for (var di = 0; di < dd.time.length; ++di)
                out.daily.push({
                    date: dd.time[di],
                    code: valueAt(dCode, di, -1),
                    hi:   valueAt(dHi, di),
                    lo:   valueAt(dLo, di),
                    snowSum:   valueAt(dSnow, di),
                    precipSum: valueAt(dPrecip, di),
                    // local-time ISO strings ("2026-06-16T06:18") — timezone=auto
                    sunrise:   valueAt(dRise, di, ""),
                    sunset:    valueAt(dSet, di, ""),
                    // today's headline numbers ride along on day 0 — main.qml lifts
                    // them off dailyData[0] rather than the provider passing them twice
                    precipChanceMax: valueAt(dChance, di)
                });
        }

        if (hh && hh.time) {
            // Open-Meteo stamps its sums, means, maxima and chances with the hour they
            // END at (its "preceding hour" values: precipitation, snowfall, chance, UV,
            // gusts), and its weather code follows that past hour's precipitation. A
            // sample covers the hour that STARTS at its time (see the contract above),
            // so those come from the next stamp: the 14:00 sample's rain is the one
            // Open-Meteo stamps 15:00. The instant readings stay. The last hour has no
            // next stamp, so it is left out.
            var ahead = function (values) { return values ? values.slice(1) : null; };
            var hTemp = column(hh, "temperature_2m", chosen),
                hFeels = column(hh, "apparent_temperature", chosen),
                hCode = ahead(column(hh, "weather_code", chosen)),
                hDay = column(hh, "is_day", chosen),
                hHumidity = column(hh, "relative_humidity_2m", chosen),
                hDew = column(hh, "dew_point_2m", chosen),
                hUv = ahead(column(hh, "uv_index", chosen)),
                hChance = ahead(column(hh, "precipitation_probability", chosen)),
                hPrecip = ahead(column(hh, "precipitation", chosen)),
                hSnow = ahead(column(hh, "snowfall", chosen)),
                hCloud = column(hh, "cloud_cover", chosen),
                hWind = column(hh, "wind_speed_10m", chosen),
                hGust = ahead(column(hh, "wind_gusts_10m", chosen)),
                hWindDir = column(hh, "wind_direction_10m", chosen),
                hPressure = column(hh, "pressure_msl", chosen);
            for (var hi = 0; hi < hh.time.length - 1; ++hi)
                out.hourly.push({
                    time:    hh.time[hi],
                    date:    hh.time[hi].substring(0, 10),
                    spanHours: 1,   // Open-Meteo is hourly the whole way out
                    temp:    valueAt(hTemp, hi),
                    feels:   valueAt(hFeels, hi),
                    code:    valueAt(hCode, hi, -1),
                    day:     valueAt(hDay, hi, 1),
                    humidity: valueAt(hHumidity, hi),
                    dew:      valueAt(hDew, hi),
                    uv:       valueAt(hUv, hi),
                    precip:  valueAt(hChance, hi),
                    precipAmt: valueAt(hPrecip, hi),   // mm this hour
                    snow:    valueAt(hSnow, hi),   // cm in that hour
                    cloud:   valueAt(hCloud, hi),   // % cover, for overcast-snow icon
                    wind:    valueAt(hWind, hi),
                    gust:    valueAt(hGust, hi),
                    windDir: valueAt(hWindDir, hi, 0),
                    pressure: valueAt(hPressure, hi)   // hPa at sea level
                });

            // Open-Meteo's daily code, precipitation, snowfall and chance are those
            // same past-hour values over the stamps 00:00 to 23:00 (the highest code,
            // the sums, the highest chance), so they run from 23:00 the day before.
            // Taken from the samples above, they cover the day itself and agree with
            // its hours. High and low are instant readings and stay. The last day, its
            // last hour left out, keeps Open-Meteo's own.
            var lastDate = hh.time[hh.time.length - 1].substring(0, 10), byDate = {};
            out.hourly.forEach(function (s) {
                var a = byDate[s.date] || (byDate[s.date] = { code: -1, precipSum: NaN, snowSum: NaN, chance: NaN });
                a.code = Math.max(a.code, s.code);
                if (!isNaN(s.precipAmt)) a.precipSum = (isNaN(a.precipSum) ? 0 : a.precipSum) + s.precipAmt;
                if (!isNaN(s.snow))      a.snowSum   = (isNaN(a.snowSum)   ? 0 : a.snowSum)   + s.snow;
                if (!isNaN(s.precip) && (isNaN(a.chance) || s.precip > a.chance)) a.chance = s.precip;
            });
            out.daily.forEach(function (d) {
                var a = byDate[d.date];
                if (!a || d.date === lastDate) return;
                if (a.code >= 0) d.code = a.code;
                // (the hourly amounts come in tenths: round off the float sum's dust)
                if (!isNaN(a.precipSum)) d.precipSum = Math.round(a.precipSum * 100) / 100;
                if (!isNaN(a.snowSum))   d.snowSum   = Math.round(a.snowSum * 100) / 100;
                if (!isNaN(a.chance))    d.precipChanceMax = a.chance;
            });
        }

        return out;
    }

    // The chosen model, as a response with two of them names it: the
    // "temperature_2m_<model>" beside "temperature_2m_best_match". "" for a response
    // with one model, whose names are plain.
    function chosenIn(block) {
        if (!block || block.temperature_2m_best_match === undefined) return "";
        for (var k in block)
            if (k.indexOf("temperature_2m_") === 0 && k !== "temperature_2m_best_match")
                return k.substring("temperature_2m_".length);
        return "";
    }
    // One variable's values for the whole response: the chosen model's, each one it
    // lacks taken from best_match's. null when the response has none.
    function column(block, name, chosen) {
        if (!block) return null;
        if (!chosen) return block[name] || null;
        var a = block[name + "_" + chosen], b = block[name + "_best_match"];
        if (!a || !b) return a || b || null;
        return a.map(function (v, i) { return (v === null || v === undefined) ? b[i] : v; });
    }
    // The i-th value of a column, or `missing` where it has none: NaN unless given
    // (the contract's missing value; codes use -1).
    function valueAt(values, i, missing) {
        var v = (values && i >= 0 && i < values.length) ? values[i] : null;
        if (v !== null && v !== undefined) return v;
        return missing === undefined ? NaN : missing;
    }
}
