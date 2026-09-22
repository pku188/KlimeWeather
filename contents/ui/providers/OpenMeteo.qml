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
 *     current: { temperature, weatherCode, apparentTemp, humidity, isDay,
 *                uvIndex, precipRate, windSpeed, windGust, cloudCover, pressure },
 *     daily:  [ { date, code, hi, lo, snowSum, precipSum, sunrise, sunset } ],
 *     hourly: [ { time, date, spanHours, temp, feels, code, day, humidity, uv,
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

    function buildUrl(ctx) {
        return "https://api.open-meteo.com/v1/forecast"
             + "?latitude=" + ctx.lat
             + "&longitude=" + ctx.lon
             + "&current=temperature_2m,weather_code,apparent_temperature,relative_humidity_2m,is_day,uv_index,precipitation,wind_speed_10m,wind_gusts_10m,cloud_cover,pressure_msl"
             + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,snowfall_sum,sunrise,sunset"
             + "&hourly=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,uv_index,precipitation_probability,precipitation,snowfall,wind_speed_10m,wind_direction_10m,wind_gusts_10m,cloud_cover,pressure_msl"
             + "&forecast_days=" + ctx.forecastDays
             + "&timezone=auto"
             // the contract's fixed units; main.qml converts to the user's
             + "&wind_speed_unit=kmh"
             + "&temperature_unit=celsius";
    }

    function parse(text, ctx) {
        var data = JSON.parse(text);
        var out = {
            utcOffsetSeconds: (data.utc_offset_seconds !== undefined) ? data.utc_offset_seconds : NaN,
            current: null,
            daily: [],
            hourly: []
        };

        // Open-Meteo already speaks WMO codes and the contract's units (asked for in
        // the query), so "mapping" here is a straight field rename — the adapter earns
        // its keep on other APIs.
        var c = data.current;
        if (c) {
            out.current = {
                temperature:  c.temperature_2m,
                weatherCode:  c.weather_code,
                apparentTemp: c.apparent_temperature,
                humidity:     c.relative_humidity_2m,
                isDay:        c.is_day,
                uvIndex:      c.uv_index,
                precipRate:   (c.precipitation   !== undefined) ? c.precipitation   : NaN,
                windSpeed:    (c.wind_speed_10m  !== undefined) ? c.wind_speed_10m  : NaN,
                windGust:     (c.wind_gusts_10m  !== undefined) ? c.wind_gusts_10m  : NaN,
                cloudCover:   (c.cloud_cover     !== undefined) ? c.cloud_cover     : NaN,
                // hPa at sea level — the contract's unit, and Open-Meteo's own
                pressure:     (c.pressure_msl    !== undefined) ? c.pressure_msl    : NaN
            };
        }

        if (data.daily && data.daily.time) {
            var dd = data.daily;
            for (var di = 0; di < dd.time.length; ++di)
                out.daily.push({
                    date: dd.time[di],
                    code: dd.weather_code[di],
                    hi:   dd.temperature_2m_max[di],
                    lo:   dd.temperature_2m_min[di],
                    snowSum:   (dd.snowfall_sum      && di < dd.snowfall_sum.length)      ? dd.snowfall_sum[di]      : NaN,
                    precipSum: (dd.precipitation_sum && di < dd.precipitation_sum.length) ? dd.precipitation_sum[di] : NaN,
                    // local-time ISO strings ("2026-06-16T06:18") — timezone=auto
                    sunrise:   (dd.sunrise && di < dd.sunrise.length) ? dd.sunrise[di] : "",
                    sunset:    (dd.sunset  && di < dd.sunset.length)  ? dd.sunset[di]  : "",
                    // today's headline numbers ride along on day 0 — main.qml lifts
                    // them off dailyData[0] rather than the provider passing them twice
                    precipChanceMax: (dd.precipitation_probability_max && di < dd.precipitation_probability_max.length)
                                     ? dd.precipitation_probability_max[di] : NaN
                });
        }

        if (data.hourly && data.hourly.time) {
            var hh = data.hourly;
            for (var hi = 0; hi < hh.time.length; ++hi)
                out.hourly.push({
                    time:    hh.time[hi],
                    date:    hh.time[hi].substring(0, 10),
                    spanHours: 1,   // Open-Meteo is hourly the whole way out
                    temp:    hh.temperature_2m[hi],
                    feels:   hh.apparent_temperature ? hh.apparent_temperature[hi] : NaN,
                    code:    hh.weather_code[hi],
                    day:     hh.is_day[hi],
                    humidity: hh.relative_humidity_2m ? hh.relative_humidity_2m[hi] : NaN,
                    uv:       hh.uv_index ? hh.uv_index[hi] : NaN,
                    precip:  hh.precipitation_probability ? hh.precipitation_probability[hi] : NaN,
                    precipAmt: hh.precipitation ? hh.precipitation[hi] : NaN,   // mm this hour
                    snow:    hh.snowfall ? hh.snowfall[hi] : NaN,   // cm in that hour
                    cloud:   hh.cloud_cover ? hh.cloud_cover[hi] : NaN,   // % cover, for overcast-snow icon
                    wind:    hh.wind_speed_10m ? hh.wind_speed_10m[hi] : NaN,
                    gust:    hh.wind_gusts_10m ? hh.wind_gusts_10m[hi] : NaN,
                    windDir: hh.wind_direction_10m ? hh.wind_direction_10m[hi] : 0,
                    pressure: hh.pressure_msl ? hh.pressure_msl[hi] : NaN   // hPa at sea level
                });
        }

        return out;
    }
}
