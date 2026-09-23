/*
 * Weather — a simple weather widget for KDE Plasma 6
 * Copyright 2026  pku188, bvlthvzvr
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Original work. Weather data comes from a pluggable provider — see
 * providers/ for the adapters and the model contract they implement.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import QtQuick.LocalStorage
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "providers"
import "providers/grid.js" as Grid

PlasmoidItem {
    id: root

    readonly property bool keepOpen: Plasmoid.configuration.keepOpen || false
    function setKeepOpen(v) { Plasmoid.configuration.keepOpen = v; }
    function toggleLayout() { Plasmoid.configuration.simpleLayout = !simpleLayout; }
    // Graph zoom: a whole day on screen (2-hour labels) or half a day (hourly
    // labels). Both draw the same hourly curve — see SimpleView's pointsVisible.
    // Also reachable from Appearance → Graph; this is the in-place shortcut.
    // Graph zoom, one step at a time: 0 = 12 hours, 1 = 24 hours, 2 = 48 hours.
    function zoomGraphIn()  { if (graphZoom > 0) Plasmoid.configuration.graphZoom = graphZoom - 1; }
    function zoomGraphOut() { if (graphZoom < 2) Plasmoid.configuration.graphZoom = graphZoom + 1; }
    hideOnWindowDeactivate: !keepOpen
    // Build the popup's content in the background when the widget loads, instead of
    // on the first click. Without it the first open had to construct the whole view
    // (and every hourly card) while you waited; Plasma already knows how to do this
    // lazily and off the interaction path. Costs nothing extra over a session: once
    // opened, the popup content is kept anyway.
    preloadFullRepresentation: true

    // Transparent on the desktop by default — the widget paints its own content
    // and looks better floating frameless over the wallpaper. ConfigurableBackground
    // keeps the "Show background" toggle in settings, so the standard applet frame
    // is one click away for anyone who wants it. No-op on the panel.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    // On the desktop (not the panel) the full rep is embedded directly — its size
    // is the applet box, not a popup window. The popup machinery below no-ops here.
    readonly property bool planar: Plasmoid.formFactor === PlasmaCore.Types.Planar

    // ── Live weather state ────────────────────────────────────────────────
    property real temperature: NaN
    property int  weatherCode: -1
    property real cloudCover: NaN     // %, drives the overcast-snow icon
    property real pressure:   NaN     // hPa at sea level (both providers report it there)
    property bool loading: false
    // The most recent weather request failed (network down, HTTP error, unreadable
    // body). Cleared by the next success. With no data at all, the popup says so.
    property bool fetchFailing: false

    readonly property string locationName: Plasmoid.configuration.locationName || "—"
    // just the city/region for the header — drop the ", Region, Country" that
    // geocoding tacks on (the saved-locations list shows that part by the coords)
    readonly property string locationShortName: {
        var c = locationName.indexOf(",");
        return c >= 0 ? locationName.substring(0, c).trim() : locationName;
    }
    // false until the user sets a location (any method); gates fetching and drives
    // the "no location" empty state. Out of the box there is no default city.
    readonly property bool   hasLocation:  Plasmoid.configuration.locationConfigured
    readonly property string units: Plasmoid.configuration.temperatureUnit || "celsius"
    readonly property int    dailyDays:      Plasmoid.configuration.dailyDays      || 5
    // Days the graph spans, today included: 3 by default, up to 5 (Appearance →
    // Graph). Three is what BOTH providers can draw at hourly resolution — met.no's
    // hourly data runs out around hour 54 and only 6-hour blocks follow, so its later
    // days are stretched blocks (which read acceptably once identical readouts merge,
    // see SimpleView's readoutPlan). Open-Meteo stays hourly the whole way. The CARD
    // layout keeps its own day count (dailyDays); it renders blocks as blocks.
    readonly property int    graphDays: Math.max(3, Math.min(5, Plasmoid.configuration.simpleDailyDays || 3))
    readonly property int    graphZoom:       Math.max(0, Math.min(2, Plasmoid.configuration.graphZoom ?? 1))
    readonly property int    refreshMinutes: Plasmoid.configuration.refreshInterval || 15
    readonly property int    heroIconSize:   Plasmoid.configuration.heroIconSize   || 88
    readonly property int    tempFontSize:   Plasmoid.configuration.tempFontSize   || 88
    readonly property int    dailyIconSize:  Plasmoid.configuration.dailyIconSize  || 36
    readonly property int    dailyTempFontSize: Plasmoid.configuration.dailyTempFontSize || 15
    // Pixel size of the wind-direction arrow, wherever it is drawn (hourly cards and
    // both headers' Wind element). Its own setting because the glyph reads much smaller
    // than text at the same size — the arrow sits inside a circle that eats most of it.
    readonly property int    windArrowSize:     Plasmoid.configuration.windArrowSize || 21
    readonly property bool   showDayDate:       Plasmoid.configuration.showDayDate ?? true
    readonly property int    hourlyIconSize:     Plasmoid.configuration.hourlyIconSize     || 38
    readonly property int    hourlyInfoFontSize: Plasmoid.configuration.hourlyInfoFontSize || 11
    // Detailed hourly-card element font (time + per-hour readouts/glyphs); SimpleView
    // keeps hourlyInfoFontSize, so this control only affects the Detailed cards.
    readonly property int    hourlyCardFontSize:  Plasmoid.configuration.hourlyCardFontSize  || 13
    readonly property int    hourlyTempFontSize: Plasmoid.configuration.hourlyTempFontSize || 15
    // hour a non-today day opens at in the Detailed timeline (6 = 6 AM, 0 = midnight).
    // Read directly — NOT `|| 6` — since 0 (midnight) is a valid value `||` would clobber.
    readonly property int    detailDayStartHour:  Plasmoid.configuration.detailDayStartHour
    readonly property int    cardDealDurationPercent: Plasmoid.configuration.cardDealDurationPercent ?? 60
    readonly property int    cardsPerScroll:      Math.max(1, Plasmoid.configuration.cardsPerScroll || 1)
    readonly property int    graphScrollHoursDay:    Math.max(1, Plasmoid.configuration.graphScrollHoursDay    || 6)
    readonly property int    graphScrollHoursDetail: Math.max(1, Plasmoid.configuration.graphScrollHoursDetail || 3)
    readonly property int    graphScrollHoursWide:   Math.max(1, Plasmoid.configuration.graphScrollHoursWide   || 12)
    // How long that notch takes to slide, per zoom. `??` rather than `||`: 0 is a
    // valid setting here, meaning jump with no slide at all.
    readonly property int    graphSlideMsDetail:    Math.max(0, Plasmoid.configuration.graphSlideMsDetail ?? 350)
    readonly property int    graphSlideMsDay:       Math.max(0, Plasmoid.configuration.graphSlideMsDay    ?? 450)
    readonly property int    graphSlideMsWide:      Math.max(0, Plasmoid.configuration.graphSlideMsWide   ?? 800)
    readonly property int    conditionFontSize:   Plasmoid.configuration.conditionFontSize   || 28
    readonly property int    locationFontSize:    Plasmoid.configuration.locationFontSize    || 28
    readonly property int    providerFontSize:    Plasmoid.configuration.providerFontSize    || 16
    readonly property bool   animatedDailyIcons:  Plasmoid.configuration.animatedDailyIcons  ?? true
    readonly property bool   animatedHourlyIcons: Plasmoid.configuration.animatedHourlyIcons ?? true
    readonly property bool   simpleLayout:         Plasmoid.configuration.simpleLayout         || false
    readonly property int    simpleHourlyIconSize: Plasmoid.configuration.simpleHourlyIconSize || 34
    readonly property bool   simpleAnimatedIcons:  Plasmoid.configuration.simpleAnimatedIcons  || false
    readonly property bool   simpleHeaderAnim:     Plasmoid.configuration.simpleHeaderAnim     ?? true
    // regular-layout header (hero) icon animates unless forecast animation is None
    readonly property bool   fullHeaderAnim:       animatedDailyIcons || animatedHourlyIcons
    readonly property int    graphColorMode:       Plasmoid.configuration.graphColorMode       ?? 2
    readonly property int    precipBandOpacity:    Math.max(0, Math.min(90, Plasmoid.configuration.precipBandOpacity ?? 30))
    readonly property int    precipLabelMode:      Math.max(0, Math.min(3, Plasmoid.configuration.precipLabelMode ?? 3))
    readonly property bool   showDayMarkerDate:    Plasmoid.configuration.showDayMarkerDate    ?? true
    readonly property int    panelIconPercent:   Plasmoid.configuration.panelIconPercent   || 130
    readonly property int    panelFontPercent:   Plasmoid.configuration.panelFontPercent   || 48
    readonly property bool   panelColorIcon:     Plasmoid.configuration.panelColorIcon === true
    readonly property bool   panelDetailed:      Plasmoid.configuration.panelDetailed === true
    readonly property int    panelSecondLine:    Plasmoid.configuration.panelSecondLine ?? 0
    // Detailed-panel font sizes, % of panel height: the bold condition word and
    // the second line chosen by panelSecondLine.
    readonly property int    panelConditionPercent:  Plasmoid.configuration.panelConditionPercent  || 40
    readonly property int    panelSecondLinePercent: Plasmoid.configuration.panelSecondLinePercent || 37

    // Wind speed unit. "auto" follows the temperature unit (mph with °F, kmh
    // with °C) — what the widget always did; "kmh"/"mph"/"ms" pin it instead.
    // windUnitApi is the unit wind speeds are converted to (convertUnits);
    // windUnitLabel is what the UI prints.
    readonly property string windUnit:    Plasmoid.configuration.windUnit || "auto"
    readonly property string windUnitApi: (windUnit !== "auto") ? windUnit
                                        : (units === "fahrenheit" ? "mph" : "kmh")
    readonly property string windUnitLabel: (windUnitApi === "mph") ? "mph"
                                          : (windUnitApi === "ms")  ? "m/s" : "kmh"
    // Air pressure unit, the same shape as the wind one: "auto" follows the temperature
    // unit (inHg is the customary unit wherever °F is), hPa or inHg pin it.
    readonly property string pressureUnit:    Plasmoid.configuration.pressureUnit || "auto"
    readonly property string pressureUnitApi: (pressureUnit !== "auto") ? pressureUnit
                                            : (units === "fahrenheit" ? "inHg" : "hPa")

    property real apparentTemp: NaN
    property real humidity:     NaN
    property real uvIndex:      NaN
    property real precipRate:   NaN   // current precipitation, mm/h
    property real windSpeed:    NaN   // current wind speed (unit = windUnitApi)
    property real windGust:     NaN   // current wind gust (same unit as windSpeed)
    property real precipSumToday: NaN // today's total precipitation, mm
    property real precipChanceToday: NaN // today's max chance of precipitation, %
    property real snowSumToday:   NaN // today's total snowfall, cm
    property real highTemp:     NaN
    property real lowTemp:      NaN

    // ── Stale-data signal ─────────────────────────────────────────────────
    // fetchWeather keeps the last-good values on failure (so a blip doesn't blank
    // the widget), but that means an outage shows hours-old weather as if current —
    // a fast storm over a frozen "sunny" reads as WRONG, not stale. Track the last
    // success time and flag data that has aged past the threshold; the panel shows a
    // small dot so "can't refresh" is visible instead of silently misleading.
    property double lastGoodFetch: 0        // wall-clock ms of last success (0 = none yet)
    property double _nowMs: 0               // ticked each minute by staleClock
    // Floor 30 min, but scale with the refresh interval so a long-refresh user isn't
    // flagged mid-cycle — ~2 missed fetches before we call it stale.
    readonly property int staleThresholdMs: Math.max(30, refreshMinutes * 2) * 60000
    // Only once we HAVE data that has since gone stale — never on first load
    // (weatherCode < 0) or before the clock's first tick.
    readonly property bool weatherStale: weatherCode >= 0 && lastGoodFetch > 0
                                         && _nowMs - lastGoodFetch > staleThresholdMs
    // "Updated Xh ago" for the full/simple header stale marker (panel uses a dot —
    // no room for text). Empty until we've had a successful fetch.
    function staleAgeText() {
        if (lastGoodFetch <= 0) return "";
        var mins = Math.floor((_nowMs - lastGoodFetch) / 60000);
        if (mins < 60) return i18n("Updated %1m ago", mins);
        var hrs = Math.floor(mins / 60);
        if (hrs < 24) return i18n("Updated %1h ago", hrs);
        return i18n("Updated %1d ago", Math.floor(hrs / 24));
    }

    // ── Severe-weather alerts (KDE FOSS Public Alert Server, worldwide) ────
    readonly property bool showAlerts: Plasmoid.configuration.showAlerts
    property var weatherAlerts: []    // [{ event, severity, headline, ends, expires, description, instruction }]
    property int _alertGen: 0         // bumped per fetch; stale responses are dropped
    function alertRank(sev) {
        return sev === "Extreme" ? 4 : sev === "Severe" ? 3
             : sev === "Moderate" ? 2 : sev === "Minor" ? 1 : 0;
    }
    // minimum severity to show (user-set in General settings): 1 Minor, 2 Moderate,
    // 3 Severe, 4 Extreme. Default 2 = Moderate+ (Minor/Unknown filtered). Applied
    // at DISPLAY time (see displayAlerts) so changing it re-filters instantly.
    readonly property int minAlertRank: Plasmoid.configuration.minAlertSeverity || 2
    function alertColor(sev) {
        return sev === "Extreme" ? "#d32f2f" : sev === "Severe" ? "#e53935"
             : sev === "Moderate" ? "#fb8c00" : "#fbc02d";   // Minor / Unknown → amber
    }
    // alerts at or above the user's minimum severity — the filtered view that
    // drives the banner + tooltip. weatherAlerts holds the FULL fetched set, so
    // changing minAlertRank re-filters live without waiting for the next fetch.
    readonly property var displayAlerts: weatherAlerts.filter(function (a) {
        if (alertRank(a.severity) < minAlertRank) return false;
        // Drop alerts already past their CAP <expires> so a stale record from the
        // beta server (or one that lapses between the 15-min fetches) doesn't linger.
        // Filter on the REAL expires only (not the onset fallback `ends` uses), and
        // keep alerts with no/unparseable expiry — absent expiry means "still active".
        if (a.expires) {
            var exp = new Date(a.expires).getTime();
            if (!isNaN(exp) && exp < Date.now()) return false;
        }
        return true;
    })
    // drives the header banner
    readonly property var topAlert: {
        if (!displayAlerts.length) return null;
        var best = displayAlerts[0];
        for (var i = 1; i < displayAlerts.length; ++i)
            if (alertRank(displayAlerts[i].severity) > alertRank(best.severity)) best = displayAlerts[i];
        return best;
    }
    // short text: "Heat Advisory until Fri 8:00 PM"
    function alertText(a) {
        if (!a) return "";
        var t = a.event;
        if (a.ends) {
            var d = new Date(a.ends);
            if (!isNaN(d.getTime())) t += " " + i18n("until %1", d.toLocaleString(Qt.locale(), use24Hour ? "ddd H:mm" : "ddd h:mm AP"));
        }
        return t;
    }
    // NWS descriptions are hard-wrapped at ~65 cols; every wrap is a \n. Join those
    // continuation lines back into flowing text (the Label wraps it), but keep "*"/"-"
    // bullet lines on their own line. Other agencies' single-line text passes through.
    function _flowAlert(t) {
        var out = "", lines = t.replace(/\r/g, "").split("\n");
        for (var i = 0; i < lines.length; ++i) {
            var ln = lines[i].trim();
            if (!ln) continue;
            out += (out ? (/^[*\-]/.test(ln) ? "\n" : " ") : "") + ln;
        }
        return out;
    }
    // full alert text for the hover tooltip: top alert's headline + description +
    // instruction, then every other active alert as a one-liner. No caps — the
    // point-in-polygon filter keeps the set small (only alerts covering us).
    function alertDetail() {
        if (!displayAlerts.length) return "";
        var top = topAlert;
        var s = top.headline;
        if (top.description) s += "\n\n" + _flowAlert(top.description);
        if (top.instruction) s += "\n\n" + _flowAlert(top.instruction);
        if (displayAlerts.length > 1) {
            s += "\n\n" + i18n("Also active:");
            for (var i = 0; i < displayAlerts.length; ++i)
                if (displayAlerts[i] !== top) s += "\n• " + alertText(displayAlerts[i]);
        }
        return s;
    }

    // Weather Elements: up to 4 user-selected metric lines beside the temperature.
    // Each layout picks its own list (`headerMetrics` for the cards, the `simple*` one
    // for the graph); the font size and weight are shared (Appearance → Common).
    readonly property int headerInfoFontSize: Plasmoid.configuration.headerInfoFontSize || 14
    // Weight of the Weather Elements text: 400 Regular, 600 SemiBold (the default)
    // or 700 Bold. No fallback of our own: font matching settles on the NEAREST face
    // the family has, so a font without a SemiBold draws its Bold instead — which is
    // the order we want (SemiBold, else Bold).
    readonly property int headerInfoFontWeight: {
        var w = Plasmoid.configuration.headerInfoFontWeight;
        return (w === 400 || w === 600 || w === 700) ? w : 600;
    }
    // Simple-layout graph hour-axis label font (the "6 PM 7 PM …" row)
    readonly property int simpleHourFontSize: Plasmoid.configuration.simpleHourFontSize || 13
    readonly property bool use24Hour: Plasmoid.configuration.use24Hour
    // Simple-layout graph per-point temperature label font (the "41° 40° …");
    // decoupled from the Detailed cards' hourlyTempFontSize.
    readonly property int simpleGraphTempFontSize: Plasmoid.configuration.simpleGraphTempFontSize || 16
    readonly property int simpleDayMarkerFontSize: Plasmoid.configuration.simpleDayMarkerFontSize || 12
    readonly property var headerMetrics: [
        Plasmoid.configuration.headerMetric1 || "feelsLike",
        Plasmoid.configuration.headerMetric2 || "humidity",
        Plasmoid.configuration.headerMetric3 || "uv",
        Plasmoid.configuration.headerMetric4 || "none"
    ]
    readonly property var simpleHeaderMetrics: [
        Plasmoid.configuration.simpleHeaderMetric1 || "feelsLike",
        Plasmoid.configuration.simpleHeaderMetric2 || "humidity",
        Plasmoid.configuration.simpleHeaderMetric3 || "uv",
        Plasmoid.configuration.simpleHeaderMetric4 || "none"
    ]
    // The two configurable readouts at the bottom of each Detailed hourly card.
    // Each slot has a primary metric id and a chain of fallbacks, tried in order
    // when the primary has no value for an hour (e.g. snow → precip chance → wind
    // on a dry hour). See hourlyReadout().
    readonly property var hourlyMetrics: [
        { id: Plasmoid.configuration.hourlyMetric1 || "wind",
          fallbacks: [ Plasmoid.configuration.hourlyMetric1Fallback  || "none",
                       Plasmoid.configuration.hourlyMetric1Fallback2 || "none" ] },
        { id: Plasmoid.configuration.hourlyMetric2 || "precip",
          fallbacks: [ Plasmoid.configuration.hourlyMetric2Fallback  || "none",
                       Plasmoid.configuration.hourlyMetric2Fallback2 || "none" ] }
    ]
    // Resolve a readout slot for hour `m` to { id, val }: the primary's value, or
    // the first fallback in the chain that has one. `id` is whichever metric
    // actually produced the text (so the card picks the right icon/glyph); `val`
    // is "" when nothing in the chain has anything to show.
    function hourlyReadout(slot, m) {
        var ids = [slot.id].concat(slot.fallbacks || []);
        for (var i = 0; i < ids.length; ++i) {
            if (!ids[i] || ids[i] === "none") continue;
            var v = hourlyMetricValue(ids[i], m);
            if (v.length > 0) return { id: ids[i], val: v };
        }
        return { id: slot.id, val: "" };
    }
    // Per-hour card metric (id) → display value for the hour sample `m`. Returns
    // "" to hide the row. Mirrors the header metric ids but reads PER-HOUR fields.
    function hourlyMetricValue(id, m) {
        if (!m) return "";
        switch (id) {
        case "wind":      return isNaN(m.wind) ? "" : windLabel(m.wind);
        // "Wind + gust" → compact "5G10" (sustained-Gust, whole numbers, no unit — cards
        // are tight, and the trailing direction arrow marks it as wind). Falls back to the
        // plain speed when no gust rounds higher than sustained (a steady-wind hour).
        case "windGust":  return isNaN(m.wind) ? "" :
                              ((!isNaN(m.gust) && Math.round(m.gust) > Math.round(m.wind))
                                  ? (Math.round(m.wind) + "G" + Math.round(m.gust))
                                  : ("" + Math.round(m.wind)));
        // At/under precipDisplayFloor counts as nothing-to-show on dry-coded hours
        // so a fallback can take over. But on actual precip-coded hours (WMO 51+)
        // always show the chance — suppressing it while the card shows a rain icon
        // is more confusing than a low number.
        case "precip": {
            if (isNaN(m.precip)) return "";
            var isPrecipCode = (m.code >= 51 && m.code <= 82) || m.code >= 95;
            return (m.precip <= precipDisplayFloor && !isPrecipCode) ? "" : (Math.round(m.precip) + "%");
        }
        case "precipAmt":
            // precipAmtStr renders every real amount as a number (traces at extra
            // precision). A true-zero hour has no number to show, so it blanks and the
            // slot's fallback (if any) takes over.
            return precipAmtStr(m.precipAmt);
        case "snow": {
            var s = snowfallStr(m.snow, true);
            if (s.length > 0) return s;
            // Snow-coded hour but sub-0.1 cm: the card shows a snow ICON (gated on
            // precipAwareCode), so the readout must say snow too — else it blanks
            // and the fallback paints a raindrop over a snowing hour. "light" is
            // the honest floor (same wording snowfallStr uses for tiny amounts).
            var c = precipAwareCode(m.code, m.precip, m.precipAmt, m.snow, m.temp);
            if ((c >= 71 && c <= 77) || c === 85 || c === 86) return i18n("light");
            return "";
        }
        case "humidity":  return isNaN(m.humidity) ? "" : (Math.round(m.humidity) + "%");
        case "uv":        return isNaN(m.uv) ? "" : ("UV " + Math.round(m.uv));
        case "feelsLike": return isNaN(m.feels) ? "" : tempStr(m.feels);
        case "cloud":     return (isNaN(m.cloud) || m.cloud < 10) ? "" : (Math.round(m.cloud) + "%");
        case "pressure":  return isNaN(m.pressure) ? "" : pressureStr(m.pressure);
        }
        return "";   // "none" / unknown
    }
    // Leading glyph (a char in the BUNDLED weather-icons font, wiFont) for a
    // readout metric — so the icon is identical for every user regardless of
    // their system icon theme (named theme icons like weather-showers-symbolic
    // render differently per theme, or not at all). "" = no glyph: wind has its
    // own trailing direction arrow; "none"/unknown get nothing. Codepoints are
    // PUA, verified against the bundled .ttf cmap.
    function hourlyMetricGlyph(id) {
        switch (id) {
        case "cloud":     return "\uf041";   // wi-cloud (U+F041) — escape form, not the literal PUA char the others use
        case "pressure":  return "\uf079";   // wi-barometer (U+F079)
        case "precip":    return "";   // wi-umbrella (U+F084) — precip *chance* (vs wi-raindrop below = precip amount)
        case "precipAmt": return "";   // wi-raindrop
        case "snow":      return "";   // wi-snowflake-cold
        case "humidity":  return "";   // wi-humidity
        case "uv":        return "";   // wi-day-sunny
        case "feelsLike": return "";   // wi-thermometer
        }
        return "";
    }
    // Per-glyph size multiplier (× the readout font) for the leading glyph. The
    // sun / thermometer / humidity glyphs render visually larger than the rain &
    // snow ones at the same pixel size, so they're nudged down slightly to look
    // balanced against the text. Rain/snow (and anything else) use the base 1.5×.
    function hourlyMetricGlyphScale(id) {
        switch (id) {
        case "uv":
        case "humidity":
        case "feelsLike":
        case "precip":    return 1.25;   // wi-umbrella reads a touch large at base — nudge down to match sun/humidity
        case "pressure":  return 1.25;   // the barometer dial reads large at base, like those
        }
        return 1.5;
    }
    // Air pressure → "1013 hPa" / "29.92 inHg". Both providers publish it at sea level
    // in hPa (the contract's unit), converted here like precipitation and snowfall are —
    // nothing plots pressure, so the model keeps the contract's unit throughout.
    // hPa is rounded whole: a tenth is below what a forecast can mean, and the extra
    // digit only makes the readout harder to scan. inHg keeps the two decimals it is
    // always quoted with (a whole inHg would be a 34 hPa step).
    function pressureStr(hPa) {
        if (isNaN(hPa)) return "";
        if (pressureUnitApi === "inHg") return i18n("%1 inHg", (hPa * 0.02952998).toFixed(2));
        return i18n("%1 hPa", Math.round(hPa));
    }
    // per-hour precipitation amount → "1.2 mm" / "0.05 in" (imperial follows °F).
    // A real-but-sub-display amount (would round to "0.00 in" / "0.0 mm" at the normal
    // precision) is shown at EXTRA precision instead, so a trace reads as a real small
    // number (e.g. "0.004 in") rather than a meaningless zero. Only a TRUE zero
    // (mm <= 0) — or a value that rounds away even at the extra precision — blanks.
    // Every non-empty return is a positive number, so callers gate visibility on `!== ""`.
    // Formats the value precipAmtQ rounds to, rather than rounding again in toFixed:
    // one rounding rule for every precipitation amount the widget prints. toFixed
    // on its own rounds the BINARY value, so an hour of a 0.9 mm six-hour block —
    // 0.15, stored as 0.1499… — printed "0.1 mm" while anything using precipAmtQ
    // printed "0.2 mm", and the graph could label two different readings alike.
    // Now both halves round the decimal value half-up, and agree by construction.
    function precipAmtStr(mm) {
        var q = precipAmtQ(mm);
        if (q <= 0) return "";                                   // rounds away → blank
        if (units === "fahrenheit") {
            var inch = q / 25.4;
            return (inch >= 0.005 ? inch.toFixed(2)              // normal: 2 dp
                                  : inch.toFixed(3)) + " in";    // trace: 3 dp so it isn't "0.00 in"
        }
        return (q >= 0.05 ? q.toFixed(1)                         // normal: 1 dp
                          : q.toFixed(2)) + " mm";               // trace: 2 dp
    }
    // Is there an amount for precipAmtStr to print? The same answer, without building
    // the string to compare it against "". The graph asks this per column per frame
    // while it scrolls, so the string was pure waste there. Thresholds mirror the
    // blanking rules above: metric rounds away below 0.005 mm, imperial below
    // 0.0005 in.
    function hasPrecipAmt(mm) {
        if (isNaN(mm) || mm <= 0) return false;
        return (units === "fahrenheit") ? (mm / 25.4 >= 0.0005) : (mm >= 0.005);
    }
    // The amount precipAmtStr will actually PRINT, rounded half-up to the step it
    // prints at — and clamped inside its own branch, so rounding can never promote a
    // trace reading into a normal one. precipAmtStr formats exactly this value, and
    // it is idempotent, so binding a label to precipAmtStr(precipAmtQ(v)) prints the
    // same string as precipAmtStr(v) while only CHANGING when that string would —
    // the formatting stops running on every frame of a value morphing between two
    // hours.
    function precipAmtQ(mm) {
        if (isNaN(mm) || mm <= 0) return 0;
        if (units === "fahrenheit") {
            var inch = mm / 25.4;
            return 25.4 * (inch >= 0.005 ? Math.round(inch * 100) / 100
                                         : Math.min(0.00499, Math.round(inch * 1000) / 1000));
        }
        return mm >= 0.05 ? Math.round(mm * 10) / 10
                          : Math.min(0.0499, Math.round(mm * 100) / 100);
    }
    // header precipitation amount (mm) → display string in the active unit; imperial
    // (°F) → inches (2 dp), else mm (1 dp). `perHour` adds "/h" for a rate. Unlike
    // precipAmtStr (card readouts, which blank a 0), this keeps 0 visible so the
    // header reads "0 in" / "0 mm" rather than going empty.
    function precipUnitStr(mm, perHour) {
        if (isNaN(mm)) return "";
        var imperial = (units === "fahrenheit");
        var v = imperial ? (mm / 25.4) : mm;
        var num = imperial ? v.toFixed(2) : ("" + (Math.round(v * 10) / 10));
        return num + (imperial ? " in" : " mm") + (perHour ? "/h" : "");
    }
    // Snowfall (cm) → an HONEST, coarse label. Snow depth is a ballpark: it's
    // derived from water with a FIXED snow:liquid ratio while real ratios swing
    // 5:1–20:1 (see DEVELOPMENT), so a tenths digit is fake precision. Three
    // tiers: ~0 → "0", a real-but-tiny amount → "light", else round to the
    // nearest half-unit. Imperial follows the °F unit (½-inch buckets: "½ in").
    function snowfallStr(cm, blankZero) {
        if (isNaN(cm)) return "";
        var imperial = (units === "fahrenheit");
        var unit = imperial ? " in" : " cm";
        // Below the "is it snowing" floor (0.1 cm — same gate SimpleView uses to
        // decide which columns get a snow label) there's effectively no snow. The
        // header shows "0"; the graph passes blankZero=true so a column morphing
        // through ~0 as it fades out blanks instead of flashing "0 in".
        if (cm < 0.1) return blankZero ? "" : ("0" + unit);
        var v = imperial ? (cm / 2.54) : cm;          // value in display units
        if (v < 0.25) return i18n("light");           // real but too little to quantify honestly
        var r = Math.round(v * 2) / 2;                // nearest 0.5
        if (imperial) {                               // ½-inch buckets: "½ in", "1½ in"
            var whole = Math.floor(r);
            var half  = (r - whole) >= 0.5;
            return (whole > 0 ? whole : "") + (half ? "½" : "") + unit;
        }
        return (r % 1 === 0 ? r.toFixed(0) : r.toFixed(1)) + unit;  // metric: "1 cm", "1.5 cm"
    }
    // rich-text "Label: value" for a metric id (or "" when unavailable / none).
    // dayIdx (optional) selects the day for the daily-total metrics (snowSum /
    // precipSum) so a scrolling view shows the day in focus. hourSample (optional)
    // is the focused hour's data, letting an instantaneous metric (humidity) sync
    // to the scrolled hour; without it, it falls back to current conditions.
    // Defaults to today / now.
    function metricText(id, dayIdx, hourSample) {
        var day = (dayIdx !== undefined && dayIdx >= 0 && dayIdx < dailyData.length) ? dailyData[dayIdx] : null;
        // word for the daily-total labels: "today" for day 0 / unset, else the
        // focused day's name (so a scrolled view reads e.g. "Snowfall Sun: …")
        var whenWord = (dayIdx !== undefined && dayIdx > 0) ? dayName(dayIdx) : i18n("Today");
        if (id === "feelsLike") {
            var ft = (hourSample && !isNaN(hourSample.feels)) ? hourSample.feels : apparentTemp;
            return isNaN(ft) ? "" : i18n("Feels like: %1",
                "<font color=\"" + feelsColor(ft) + "\">" + tempStr(ft) + "</font>");
        }
        if (id === "humidity") {
            var hum = (hourSample && !isNaN(hourSample.humidity)) ? hourSample.humidity : humidity;
            return isNaN(hum) ? "" : i18n("Humidity: %1",
                "<font color=\"" + humidityColor(hum) + "\">" + Math.round(hum) + "%</font>");
        }
        if (id === "uv") {
            var uv = (hourSample && !isNaN(hourSample.uv)) ? hourSample.uv : uvIndex;
            return isNaN(uv) ? "" : i18n("UV Index: %1",
                "<font color=\"" + uvColor(uv) + "\">" + uvIndexText(uv) + "</font>");
        }
        if (id === "precipRate") {
            var pr = (hourSample && !isNaN(hourSample.precipAmt)) ? hourSample.precipAmt : precipRate;
            return isNaN(pr) ? "" : i18n("Precipitation: %1",
                "<font color=\"" + precipColor + "\">" + precipUnitStr(pr, true) + "</font>");
        }
        if (id === "precipSum") {
            var ps = day ? day.precipSum : precipSumToday;
            return isNaN(ps) ? "" : i18n("Precip. %1: %2", whenWord,
                "<font color=\"" + precipColor + "\">" + precipUnitStr(ps, false) + "</font>");
        }
        if (id === "wind") {
            var ws = (hourSample && !isNaN(hourSample.wind)) ? hourSample.wind : windSpeed;
            if (isNaN(ws)) return "";
            // show the gust whenever it rounds higher than the sustained wind — the SAME
            // rule as the hourly cards, so header and cards never disagree (no "5G10" on a
            // card while the header hides it). Skips a redundant "5 G5" on calm hours.
            var gs = (hourSample && !isNaN(hourSample.gust)) ? hourSample.gust : windGust;
            // Sustained wind with its unit, then the gust in brackets: "11.2 kmh (G24)".
            // The gust is a peak, so it is rounded; keeping it outside the unit also
            // stops it reading as a second measurement of the same thing. Whether to
            // show it is still decided on rounded values, so a steady hour doesn't
            // get a redundant "(G11)" after "11.2 kmh".
            var windBody = (!isNaN(gs) && Math.round(gs) > Math.round(ws))
                ? (windLabel(ws) + " (G" + Math.round(gs) + ")")
                : windLabel(ws);
            return i18n("Wind: %1", windBody);
        }
        if (id === "cloud") {
            var cc = (hourSample && !isNaN(hourSample.cloud)) ? hourSample.cloud : cloudCover;
            return isNaN(cc) ? "" : i18n("Cloud cover: %1", Math.round(cc) + "%");
        }
        if (id === "pressure") {
            var pr = (hourSample && !isNaN(hourSample.pressure)) ? hourSample.pressure : pressure;
            return isNaN(pr) ? "" : i18n("Pressure: %1", pressureStr(pr));
        }
        if (id === "snowSum") {
            var ss = day ? day.snowSum : snowSumToday;
            return isNaN(ss) ? "" : i18n("Snowfall %1: %2", whenWord,
                "<font color=\"" + precipColor + "\">" + snowfallStr(ss) + "</font>");
        }
        // Combined sunrise/sunset, offered in both layouts' Weather Elements.
        // One compact line "↑ 5:23a  ↓ 8:23p"; falls back to today
        // (dailyData[0]) when no day is focused. The old "sunrise"/"sunset" ids are
        // kept as aliases so a previously-saved value still renders.
        if (id === "sun" || id === "sunrise" || id === "sunset") {
            var d0 = day ? day : (dailyData.length ? dailyData[0] : null);
            if (!d0 || !d0.sunrise || !d0.sunset) return "";
            var rise = _sunClock(d0.sunrise), set = _sunClock(d0.sunset);
            if (!rise || !set) return "";
            var up = "<font color=\"" + sunColor + "\">↑</font>";
            var dn = "<font color=\"" + sunColor + "\">↓</font>";
            return up + " " + rise + "&#160;&#160;" + dn + " " + set;
        }
        return "";
    }
    readonly property string precipColor: "#42a5f5"
    readonly property string sunColor:    "#ffb74d"
    property int  isDay:        1
    property var  dailyData:    []   // [{ date, code, hi, lo }] — up to 7 days
    property var  allHourly:    []   // [{ time, date, temp, code, day, precip }] — all hours

    readonly property string temperatureText: tempStr(temperature)

    function tempStr(t) { return isNaN(t) ? "—" : (Math.round(t) + "°"); }

    // ISO local time string → "9PM" (12h) or "19:00" (24h)
    function formatHour(iso) { return new Date(iso).toLocaleTimeString(Qt.locale(), use24Hour ? "H:mm" : "hAP"); }
    // Card heading for one hourly sample. Past roughly hour 54 met.no stops
    // publishing hourly data and only 6-hour blocks remain, so a card there covers
    // a RANGE — label it as one ("20–02") instead of a single hour, which would
    // claim a precision the forecast no longer has. Hourly samples are unchanged.
    function formatSlot(sample) {
        if (!sample) return "";
        var span = sample.spanHours > 0 ? sample.spanHours : 1;
        if (span <= 1) return formatHour(sample.time);
        var end = new Date(new Date(sample.time).getTime() + span * 3600000);
        // 24h: bare hours read cleanly as a range ("20–02"). 12h: keep the AM/PM
        // marker on each end, since "8–2" would be ambiguous.
        if (use24Hour)
            return new Date(sample.time).toLocaleTimeString(Qt.locale(), "HH")
                 + "\u2013" + end.toLocaleTimeString(Qt.locale(), "HH");
        return formatHour(sample.time) + "\u2013" + end.toLocaleTimeString(Qt.locale(), "hAP");
    }
    // compact clock for the combined sun line: "5:23a" / "8:23p" (12h) or "5:23" / "20:23" (24h)
    function _sunClock(iso) {
        var d = new Date(iso);
        if (isNaN(d.getTime())) return "";
        if (use24Hour) return d.toLocaleTimeString(Qt.locale(), "H:mm");
        return d.toLocaleTimeString(Qt.locale(), "h:mm AP").replace(/\s*AM/, "a").replace(/\s*PM/, "p");
    }

    // Wind speed → "6.0 mph" / "12.3 kmh" / "3.4 m/s" (see windUnit).
    // One decimal, everywhere a wind speed is spelled out. Shared so the sustained
    // value can't change precision depending on whether a gust is shown next to it —
    // the header used to print "11.2 kmh" on its own but "11 G20 kmh" the moment a
    // gust appeared, which reads as the number losing accuracy for no reason.
    // (The hourly CARDS keep their own whole-number "5G10" form on purpose: no room.)
    function windNum(v) { return Math.round(v * 10) / 10; }
    function windLabel(speed) {
        if (isNaN(speed)) return "";
        return windNum(speed) + " " + windUnitLabel;
    }

    // Wind-direction arrow as a Weather Icons font glyph (the glyph already
    // points the right way for each of the 16 compass sectors — no rotation).
    // The bundled Weather Icons font, loaded once for every view that draws a glyph
    // from it (the wind-direction arrows) — a named theme icon would render differently
    // per user, or not at all.
    FontLoader {
        id: wiFontLoader
        source: Qt.resolvedUrl("../fonts/weathericons-regular-webfont.ttf")
    }
    readonly property string wiFontFamily: wiFontLoader.status === FontLoader.Ready
                                           ? wiFontLoader.font.family : ""

    // How far to turn contents/icons/wind-direction.svg (which points UP) for a wind
    // direction. Providers report where the wind comes FROM, and the arrow shows where it
    // BLOWS, so it is turned the other way round: a northerly (0°) points south, down the
    // screen. The angle is used as it comes, rather than snapped to the 16 compass points
    // the old font glyphs offered.
    function windArrowRotation(deg) {
        return isNaN(deg) ? 0 : (deg + 180) % 360;
    }

    // Day label for a daily index: index 0 is "Today" — Open-Meteo returns
    // days in the LOCATION's timezone, so day 0 is the location's current day (which
    // may differ from the viewer's calendar day if the location is in another tz).
    // "Today" stays in the fixed first slot; the midnight refresh re-rolls the array
    // so a new day simply becomes day 0. Other days show the short weekday (Mon…).
    // Pass absolute=true to get the weekday for day 0 too (graph-layout pills).
    function dayName(idx, absolute) {
        if (idx < 0 || idx >= dailyData.length) return idx === 0 ? i18n("Today") : "";
        if (idx === 0 && !absolute) return i18n("Today");
        return new Date(dailyData[idx].date + "T12:00").toLocaleDateString(Qt.locale(), "ddd");
    }
    // Calendar date for a daily index — day and month only, in the order and style of
    // the system's date format: en_US "9/17", en_GB "17/09", Polish "17.09", Swedish
    // "09-17", Hungarian "09. 17.". The format follows the system's DATE locale, which
    // can differ from the language (Qt.locale() already reports LC_TIME's formats).
    function dailyDate(idx) {
        if (idx < 0 || idx >= dailyData.length) return "";
        return monthDayText(dailyData[idx].date);
    }
    // Day and month of a "YYYY-MM-DD" date in that format, and the same with the short
    // weekday in front ("Fri, 18/09") for the graph's new-day marker — or the weekday
    // alone when the marker is set not to show the date.
    function monthDayText(date) {
        return new Date(date + "T12:00").toLocaleDateString(Qt.locale(), monthDayFormat);
    }
    function weekdayText(date) {
        return new Date(date + "T12:00").toLocaleDateString(Qt.locale(), "ddd");
    }
    function weekdayDateText(date) {
        return weekdayText(date) + ", " + monthDayText(date);
    }
    function dayMarkerText(date) {
        return showDayMarkerDate ? weekdayDateText(date) : weekdayText(date);
    }
    readonly property string monthDayFormat: withoutYear(Qt.locale().dateFormat(Locale.ShortFormat))
    // Qt has no "day and month" format of its own, so the year is taken out of the
    // locale's short date format. The format is read as fields (a run of one pattern
    // letter: d, M, y…) and literals (separators, and quoted text such as the
    // Bulgarian "'г'." year suffix), and the year leaves together with what ties it to
    // the rest: at the end (dd/MM/yyyy, d.MM.yy 'г'.) the separator before it; at the
    // start (yyyy-MM-dd, yy. M. d.) the separator after it.
    function withoutYear(fmt) {
        var parts = [];
        function addLiteral(t) {
            var last = parts[parts.length - 1];
            if (last && !last.field) last.text += t;
            else parts.push({ field: "", text: t });
        }
        for (var i = 0; i < fmt.length; ) {
            var c = fmt[i];
            if (c === "'") {
                var close = fmt.indexOf("'", i + 1);
                if (close < 0) close = fmt.length - 1;
                addLiteral(fmt.substring(i, close + 1));
                i = close + 1;
            } else if (/[A-Za-z]/.test(c)) {
                var k = i;
                while (k < fmt.length && fmt[k] === c) ++k;
                parts.push({ field: c, text: fmt.substring(i, k) });
                i = k;
            } else {
                addLiteral(c);
                ++i;
            }
        }
        var y = -1;
        for (var p = 0; p < parts.length; ++p) if (parts[p].field === "y") { y = p; break; }
        if (y < 0) return fmt;
        var fieldAfter = false;
        for (var q = y + 1; q < parts.length; ++q) if (parts[q].field) fieldAfter = true;
        if (!fieldAfter) {
            // Punctuation after a final year stays (Croatian "dd. MM. yyyy." → "dd. MM."),
            // a word does not (Bulgarian "'г'.", "year").
            var tail = parts.slice(y + 1).map(function (x) { return x.text; }).join("");
            parts.splice(y > 0 && !parts[y - 1].field ? y - 1 : y);
            if (tail && !/['A-Za-z\u00C0-\uFFFF]/.test(tail)) addLiteral(tail);
        } else
            parts.splice(y, y + 1 < parts.length && !parts[y + 1].field ? 2 : 1);
        return parts.map(function (x) { return x.text; }).join("");
    }
    function dayIndexForDate(date) {
        for (var i = 0; i < dailyData.length; ++i)
            if (dailyData[i].date === date) return i;
        return 0;
    }

    // utc offset (seconds) of the WEATHER LOCATION, from Open-Meteo's response. Lets
    // "now" be evaluated in the location's wall clock, so the day/hour logic lines up
    // with the forecast (which is in the location's tz) even when the viewer sits in
    // a different timezone.
    property real utcOffsetSeconds: NaN
    // "Now" in the location's wall clock, in the SAME frame as new Date(h.time):
    // Open-Meteo times are location-local naive strings, which new Date() would parse
    // in the VIEWER's tz. Shifting by (locationOffset + viewerOffset) re-aligns them.
    // No-op when the location's tz equals the viewer's (the common case).
    function locNow() {
        if (isNaN(utcOffsetSeconds)) return new Date();
        return new Date(Date.now() + utcOffsetSeconds * 1000 + new Date().getTimezoneOffset() * 60000);
    }

    // Continuous hourly timeline from now forward, with a day-break marker
    // ({ dayBreak: true, date, label }) inserted whenever the date rolls over.
    function timeline() {
        var out = [];
        var now = locNow();
        var lastDate = "";
        var n = Math.min(dailyDays, dailyData.length);
        var cutoff = n > 0 ? dailyData[n - 1].date : "";   // last day to include
        for (var i = 0; i < allHourly.length; ++i) {
            var h = allHourly[i];
            if (cutoff !== "" && h.date > cutoff) break;    // dates sort lexically
            // a sample is current until its whole span has elapsed — 1 h for an
            // hourly forecast, 6 for one of met.no's blocks
            var span = h.spanHours > 0 ? h.spanHours : 1;
            if (new Date(h.time).getTime() + span * 3600000 < now.getTime()) continue;
            if (lastDate !== "" && h.date !== lastDate)
                out.push({ dayBreak: true, date: h.date,
                           label: new Date(h.date + "T12:00").toLocaleDateString(Qt.locale(), "ddd") });
            lastDate = h.date;
            out.push(h);
        }
        return out;
    }

    // The hourly sample for the hour containing "now" (location tz) — the first hour
    // timeline() keeps. Lets the Detailed header fall back to the CURRENT HOUR's forecast
    // (so it matches the hourly cards) instead of the live `current` block when nothing's hovered.
    readonly property var currentHourSample: {
        if (!allHourly || !allHourly.length) return null;
        var hnow = locNow().getTime();
        for (var ci = 0; ci < allHourly.length; ++ci)
            if (new Date(allHourly[ci].time).getTime() + 3600000 >= hnow) return allHourly[ci];
        return null;
    }

    // Current-condition icon inputs for the header hero. Open-Meteo's live
    // `current.weather_code` is a nowcast that can read "overcast" while the current
    // HOUR's forecast (and so the first hourly card) already shows rain — they
    // disagree hour-marginally. Drive the hero off the current-hour sample through
    // precipAwareCode, exactly like the cards, so the header glyph can never
    // contradict the first card. The header metric row already falls back to
    // currentHourSample; this puts the icon on the same source. Falls back to the
    // live `current` block before the hourly array exists.
    readonly property int heroCode: currentHourSample
        ? precipAwareCode(currentHourSample.code, currentHourSample.precip,
                          currentHourSample.precipAmt, currentHourSample.snow, currentHourSample.temp)
        : weatherCode
    readonly property int  heroDay:   currentHourSample ? currentHourSample.day   : isDay
    readonly property real heroCloud: currentHourSample ? currentHourSample.cloud : cloudCover

    // ── Uniform hourly grid (the graph's source) ──────────────────────────
    // Expands met.no's 6-hour blocks onto a 1-hour grid so the graph has the even
    // spacing its curve and sun-marker mapping need. The whole rule set lives in
    // providers/grid.js as a pure function — see its header for why temperature
    // interpolates while everything categorical is held.
    function hourlyGrid(days) {
        return Grid.build(allHourly, dailyData, days, locNow().getTime());
    }

    // Privacy: weather/alerts are computed on multi-km grids, so we only ever
    // send ~1 km-precise coordinates to the network (2 decimals). The full
    // precision stays in the config for saved locations.
    readonly property int coordPrecision: 2
    function coarseCoord(v) {
        var p = Math.pow(10, coordPrecision);
        return Math.round(v * p) / p;
    }

    // ── Weather providers ─────────────────────────────────────────────────
    // Each provider is an adapter that turns one HTTP GET into the normalized
    // model below — see providers/OpenMeteo.qml for the full contract. Adding a
    // provider = one file there plus one line in the registry; no view file, and
    // none of the icon/condition machinery, knows a provider exists.
    OpenMeteo { id: openMeteoProvider }
    MetNo     { id: metNoProvider }

    readonly property var providers: ({ "openmeteo": openMeteoProvider, "metno": metNoProvider })
    readonly property string providerId: providers[Plasmoid.configuration.weatherProvider]
                                         ? Plasmoid.configuration.weatherProvider : "openmeteo"
    readonly property var provider: providers[providerId]
    // Toggle order for the header button — the switch walks this list, so a third
    // provider joins the rotation by being added here and to the registry above.
    readonly property var providerOrder: ["openmeteo", "metno"]
    // The header's location button. Location is the first settings page, which is
    // where the dialog opens.
    function openLocationSettings() { Plasmoid.internalAction("configure").trigger(); }
    function toggleProvider() {
        var i = providerOrder.indexOf(providerId);
        Plasmoid.configuration.weatherProvider = providerOrder[(i + 1) % providerOrder.length];
    }
    // Name of the provider the button would switch TO — for its tooltip.
    readonly property string nextProviderName: {
        var i = providerOrder.indexOf(providerId);
        var next = providers[providerOrder[(i + 1) % providerOrder.length]];
        return next ? next.displayName : "";
    }

    // ── The location's UTC offset ─────────────────────────────────────────
    // Open-Meteo reports it in every response; met.no has no notion of timezone
    // at all. Rather than ship a timezone database (or spend a request on a
    // lookup), resolve the IANA zone the geocoder already gave us through
    // Plasma's time dataengine — DST-correct, offline, and no new dependency
    // beyond a module that ships with the workspace.
    // Falls back to the VIEWER's own offset, which is right for the overwhelmingly
    // common case (your own city) and the best guess for a location saved before
    // the zone was recorded.
    readonly property string locationTimezone: Plasmoid.configuration.locationTimezone || ""
    P5Support.DataSource {
        id: tzSource
        engine: "time"
        connectedSources: root.locationTimezone ? [root.locationTimezone] : []
        interval: 60000   // only needs to be fresh enough to catch a DST change
    }
    readonly property real resolvedOffsetSeconds: {
        var tz = locationTimezone;
        if (tz && tzSource.data[tz] && tzSource.data[tz]["Offset"] !== undefined)
            return tzSource.data[tz]["Offset"];
        return -(new Date().getTimezoneOffset()) * 60;
    }

    // ── Units ─────────────────────────────────────────────────────────────
    // Every provider delivers the SAME units — °C, km/h, mm, cm (see the contract in
    // providers/OpenMeteo.qml) — and they are converted to the user's choice here,
    // once, for all of them. Each provider used to convert on its own (met.no in
    // code, Open-Meteo by asking its API for the user's units): two paths to keep in
    // step, and a network fetch just to switch °C/°F. The unconverted model is kept,
    // so a unit change now re-applies it on the spot.
    // Wind is based on km/h rather than m/s because that is Open-Meteo's native
    // precision (0.1 km/h): the default unit shows exactly what the API sent.
    // Precipitation (mm) and snowfall (cm) are left alone — their display functions
    // already convert for imperial users.
    property var _rawWeather: null
    function _userTemp(c) { return units === "fahrenheit" ? c * 9 / 5 + 32 : c; }   // NaN stays NaN
    function _userWind(kmh) {
        if (windUnitApi === "mph") return kmh / 1.609344;
        if (windUnitApi === "ms")  return kmh / 3.6;
        return kmh;
    }
    // Returns a converted COPY: the raw model must stay in °C / km/h to be converted
    // again later, never converted twice.
    function convertUnits(raw) {
        var out = { utcOffsetSeconds: raw.utcOffsetSeconds, current: null, daily: [], hourly: [] };
        var i, x;
        if (raw.current) {
            x = Object.assign({}, raw.current);
            x.temperature  = _userTemp(x.temperature);
            x.apparentTemp = _userTemp(x.apparentTemp);
            x.windSpeed    = _userWind(x.windSpeed);
            x.windGust     = _userWind(x.windGust);
            out.current = x;
        }
        for (i = 0; i < (raw.daily || []).length; ++i) {
            x = Object.assign({}, raw.daily[i]);
            x.hi = _userTemp(x.hi);
            x.lo = _userTemp(x.lo);
            out.daily.push(x);
        }
        for (i = 0; i < (raw.hourly || []).length; ++i) {
            x = Object.assign({}, raw.hourly[i]);
            x.temp  = _userTemp(x.temp);
            x.feels = _userTemp(x.feels);
            x.wind  = _userWind(x.wind);
            x.gust  = _userWind(x.gust);
            out.hourly.push(x);
        }
        return out;
    }
    // A unit setting changed: re-apply what we already have. Only fetch when there
    // is nothing yet (e.g. the setting changed before the first load finished).
    function reapplyUnits() {
        if (_rawWeather) applyWeather(convertUnits(_rawWeather));
        else fetchWeather();
    }

    // Apply a provider's normalized model to the live state the views bind to.
    // Every field the widget shows is set HERE, from that one shape — so two
    // providers can never leave the widget in half-updated states, and a field a
    // provider can't supply just stays NaN and reads as "—" everywhere.
    function applyWeather(res) {
        root.utcOffsetSeconds = res.utcOffsetSeconds;
        var c = res.current;
        if (c) {
            root.temperature  = c.temperature;
            root.weatherCode  = c.weatherCode;
            root.apparentTemp = c.apparentTemp;
            root.humidity     = c.humidity;
            root.isDay        = c.isDay;
            root.uvIndex      = c.uvIndex;
            root.precipRate   = c.precipRate;
            root.windSpeed    = c.windSpeed;
            root.windGust     = c.windGust;
            root.cloudCover   = c.cloudCover;
            root.pressure     = c.pressure;
        }
        if (res.daily && res.daily.length) {
            root.dailyData = res.daily;
            var d0 = res.daily[0];
            root.highTemp          = d0.hi;
            root.lowTemp           = d0.lo;
            root.precipSumToday    = d0.precipSum;
            root.precipChanceToday = d0.precipChanceMax;
            root.snowSumToday      = d0.snowSum;
        }
        if (res.hourly && res.hourly.length)
            root.allHourly = res.hourly;
    }

    // ── Data fetch ────────────────────────────────────────────────────────
    // The request LIFECYCLE lives here, not in the provider: abort-in-flight,
    // fast-fail, watchdog and the boot probe below are hard-won boot-resilience
    // behaviour, and every provider gets it identically by construction.
    // What a request for the current provider and location looks like: the provider,
    // the ctx it parses with, its URL, and the key that names its data. Shared by the
    // fetch and the offline cache, so a cached copy is only ever used for the exact
    // request it answered. null when there is no usable location.
    function _requestPlan() {
        if (!root.hasLocation) return null;
        var lat = Plasmoid.configuration.latitude;
        var lon = Plasmoid.configuration.longitude;
        if (lat === undefined || lon === undefined || isNaN(lat) || isNaN(lon))
            return null;
        var p = root.provider;
        // Privacy: the provider only ever sees the COARSENED coordinate (see
        // coarseCoord) — it builds the URL, so this is the one place that choice
        // can be enforced for all of them.
        var ctx = {
            lat: coarseCoord(lat),
            lon: coarseCoord(lon),
            forecastDays: 7,
            // Providers that report their own offset ignore this; the ones that
            // can't (met.no) render everything in the location's clock with it.
            utcOffsetSeconds: resolvedOffsetSeconds
        };
        var url = p.buildUrl(ctx);
        return { provider: p, ctx: ctx, url: url, cacheKey: p.providerId + "|" + url };
    }

    function fetchWeather() {
        if (!root.hasLocation) { root.loading = false; return; }
        var plan = _requestPlan();
        if (!plan) return;
        loading = true;
        var p = plan.provider, ctx = plan.ctx, url = plan.url;
        // Abandon any still-in-flight request first. At boot the free-running
        // boot probe (below) re-fires on its OWN schedule whether or not the
        // previous attempt's callbacks ever returned, so without this an attempt
        // hung on a half-up route would leak one socket per probe tick.
        if (root._wxhr) { try { root._wxhr.abort(); } catch (e) {} }
        var xhr = new XMLHttpRequest();
        root._wxhr = xhr;
        // Belt-and-suspenders fast-fail. At login the interface can be up while
        // the route isn't ready (e.g. a VPN tunnel mid-handshake): the connect
        // then HANGS instead of returning HTTP 0. We set a timeout, but a connect
        // stuck in the SYN/black-hole phase doesn't reliably honour xhr.timeout —
        // so the real safety net is the boot probe, which retries on its own
        // timer regardless of whether this request ever calls back.
        var done = false;
        function failWeather(why) {
            if (done) return;
            done = true;
            root.loading = false;
            root.fetchFailing = true;
            loadingWatchdog.stop();
            console.log("Weather:", why);   // probe re-fires on its own timer
        }
        xhr.timeout = 8000;
        xhr.ontimeout = function () { failWeather("timeout"); };
        var cacheKey = plan.cacheKey;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || done) return;
            // 304: our copy is still the current forecast. Nothing to parse — just
            // stamp the success so the staleness marker clears, exactly as a 200 would.
            if (xhr.status === 304) {
                done = true;
                root.loading = false;
                root.fetchFailing = false;
                loadingWatchdog.stop();
                root._probeUntilOk = false;
                root.lastGoodFetch = Date.now();
                root._touchCache(cacheKey, root.lastGoodFetch);
                return;
            }
            if (xhr.status !== 200) {
                failWeather("HTTP " + xhr.status);   // network likely not up yet (boot)
                return;
            }
            done = true;
            root.loading = false;
            loadingWatchdog.stop();
            root._probeUntilOk = false;   // a resume-armed retry has landed
            try {
                root._rawWeather = p.parse(xhr.responseText, ctx);
                root.applyWeather(root.convertUnits(root._rawWeather));
                root.lastGoodFetch = Date.now();   // stamp success → clears the stale marker
                root.fetchFailing = false;
                root._loadedKey = cacheKey;        // the model now holds THIS source's data
                var lm = "";
                if (p.conditional) {
                    lm = xhr.getResponseHeader("Last-Modified") || "";
                    // Only remember it once the body PARSED — caching a validator for
                    // data we failed to read would lock us into 304s forever.
                    if (lm) root._lastModified[cacheKey] = lm;
                }
                root._saveCache(cacheKey, xhr.responseText, root.lastGoodFetch, lm);
                // good data — weatherCode is now ≥ 0, so the boot probe stops
            } catch (e) {
                root.fetchFailing = true;
                console.log("Weather: parse error", e);   // probe keeps retrying while weatherCode < 0
            }
        };
        xhr.open("GET", url);
        // Provider-required headers (met.no's terms demand an identifying
        // User-Agent; Qt 6's XHR does allow overriding it). Must come AFTER
        // open() — setRequestHeader on an unopened request is a no-op.
        var hdrs = p.requestHeaders || [];
        for (var i = 0; i < hdrs.length; ++i) {
            try { xhr.setRequestHeader(hdrs[i][0], hdrs[i][1]); } catch (e) {}
        }
        // Only revalidate when the model still holds THIS source's data — see _loadedKey.
        if (p.conditional && root._lastModified[cacheKey] && root._loadedKey === cacheKey) {
            try { xhr.setRequestHeader("If-Modified-Since", root._lastModified[cacheKey]); } catch (e) {}
        }
        xhr.send();
        loadingWatchdog.restart();   // see the watchdog — this request may never call back
    }

    // ── Offline cache ─────────────────────────────────────────────────────
    // The last good response is kept per widget in QML's LocalStorage (an SQLite file
    // under ~/.local/share/plasmashell/QML/OfflineStorage). Right after a reboot the
    // network is often not up for a minute or two; instead of an empty panel and
    // popup, the widget starts from that copy — marked "Updated … ago" once it is old
    // enough to count as stale — and the boot probe keeps retrying until a live fetch
    // replaces it. The raw response is stored and parsed again on restore, so the
    // cache needs nothing from the model's format (whose NaNs JSON would not keep).
    // A copy older than cacheMaxAgeMs is ignored: by then it misleads more than helps.
    readonly property double cacheMaxAgeMs: 48 * 3600 * 1000
    function _cacheDb() {
        try {
            var db = LocalStorage.openDatabaseSync("KlimeWeather", "", "KlimeWeather forecast cache", 4000000);
            db.transaction(function (tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS forecast(applet TEXT PRIMARY KEY, request TEXT, "
                              + "fetched REAL, lastModified TEXT, body TEXT)");
            });
            return db;
        } catch (e) {
            console.log("Weather: cache unavailable", e);
            return null;
        }
    }
    function _saveCache(key, body, fetchedMs, lastModified) {
        var db = _cacheDb();
        if (!db) return;
        try {
            db.transaction(function (tx) {
                tx.executeSql("INSERT OR REPLACE INTO forecast VALUES (?, ?, ?, ?, ?)",
                              [String(Plasmoid.id), key, fetchedMs, lastModified || "", body]);
            });
        } catch (e) { console.log("Weather: cache write failed", e); }
    }
    // A 304 confirmed the cached copy is still current: move its timestamp only.
    function _touchCache(key, fetchedMs) {
        var db = _cacheDb();
        if (!db) return;
        try {
            db.transaction(function (tx) {
                tx.executeSql("UPDATE forecast SET fetched = ? WHERE applet = ? AND request = ?",
                              [fetchedMs, String(Plasmoid.id), key]);
            });
        } catch (e) { console.log("Weather: cache write failed", e); }
    }
    // The cached copy's "current" block is a reading from when it was fetched, which
    // may be hours ago. Replace it with the forecast for the hour we are in now.
    // Returns false when the forecast no longer covers now (nothing sensible to show).
    function _currentFromForecast(raw) {
        var off = raw.utcOffsetSeconds;
        var now = isNaN(off) ? Date.now()
                             : Date.now() + off * 1000 + new Date().getTimezoneOffset() * 60000;
        var hs = raw.hourly || [];
        for (var i = 0; i < hs.length; ++i) {
            var s = hs[i];
            var span = Math.max(1, s.spanHours || 1);
            var start = new Date(s.time).getTime();
            if (now >= start && now < start + span * 3600000) {
                raw.current = {
                    temperature: s.temp, weatherCode: s.code, apparentTemp: s.feels,
                    humidity: s.humidity, isDay: s.day, uvIndex: s.uv,
                    precipRate: isNaN(s.precipAmt) ? NaN : s.precipAmt / span,
                    windSpeed: s.wind, windGust: s.gust, cloudCover: s.cloud,
                    pressure: s.pressure
                };
                return true;
            }
        }
        return false;
    }
    function restoreCache() {
        var plan = _requestPlan();
        if (!plan || root.weatherCode >= 0) return;   // never over live data
        var db = _cacheDb();
        if (!db) return;
        var row = null;
        try {
            db.readTransaction(function (tx) {
                var rs = tx.executeSql("SELECT request, fetched, lastModified, body FROM forecast WHERE applet = ?",
                                       [String(Plasmoid.id)]);
                if (rs.rows.length) row = rs.rows.item(0);
            });
        } catch (e) { return; }
        // only the exact request it answered: same provider, same place
        if (!row || row.request !== plan.cacheKey || Date.now() - row.fetched > cacheMaxAgeMs) return;
        try {
            var raw = plan.provider.parse(row.body, plan.ctx);
            if (!_currentFromForecast(raw)) return;
            root._rawWeather = raw;
            root.applyWeather(root.convertUnits(raw));
            root.lastGoodFetch = row.fetched;
            // A conditional request can now confirm this copy with a 304 instead of
            // downloading it again (see _loadedKey).
            root._loadedKey = plan.cacheKey;
            if (row.lastModified) root._lastModified[plan.cacheKey] = row.lastModified;
            // Restored data has weatherCode >= 0, which would stop the boot probe; keep
            // it retrying until a live fetch lands, as after a resume.
            root._probeUntilOk = true;
        } catch (e) {
            console.log("Weather: cached forecast unreadable", e);
        }
    }

    // ── Severe-weather alerts (KDE FOSS Public Alert Server) ──────────────
    // Global, FOSS, privacy-focused (alerts.kde.org). Two steps: query a
    // deliberately COARSE bounding box (alertBoxDeg) so the server learns only a
    // rough region — not the point — then pull each matching CAP 1.2 alert.
    // Anything but a clean result → no banner.
    readonly property real alertBoxDeg: 0.3   // ±deg box (~±33 km) around the location
    function fetchAlerts() {
        if (!showAlerts || !hasLocation) { weatherAlerts = []; return; }
        var lat = Plasmoid.configuration.latitude;
        var lon = Plasmoid.configuration.longitude;
        if (lat === undefined || lon === undefined || isNaN(lat) || isNaN(lon)) return;
        // round to ~1 km BEFORE building the box: the box edges are symmetric, so
        // its centre = the coordinate we send. Coarsening here keeps that centre
        // ~1 km-precise, matching the weather request (raw lat/lon would let the
        // server recover the exact point from (min+max)/2).
        lat = coarseCoord(lat);
        lon = coarseCoord(lon);
        var gen = ++root._alertGen;   // this fetch's id; a newer one supersedes it
        var d = alertBoxDeg;
        var url = "https://alerts.kde.org/alert/area"
                + "?min_lat=" + Math.max(-90,  lat - d).toFixed(3)
                + "&max_lat=" + Math.min(90,   lat + d).toFixed(3)
                + "&min_lon=" + Math.max(-180, lon - d).toFixed(3)
                + "&max_lon=" + Math.min(180,  lon + d).toFixed(3);
        var xhr = new XMLHttpRequest();
        xhr.timeout = 8000;   // don't hang on a half-up route at boot (see fetchWeather)
        xhr.ontimeout = function () { if (gen === root._alertGen) root.weatherAlerts = []; };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (gen !== root._alertGen) return;   // a later fetch already started → drop this
            if (xhr.status !== 200) { root.weatherAlerts = []; return; }
            var ids;
            try { ids = JSON.parse(xhr.responseText) || []; }
            catch (e) { root.weatherAlerts = []; return; }
            if (!ids.length) { root.weatherAlerts = []; return; }
            root._fetchAlertDetails(ids.slice(0, 12), gen);   // cap to keep it polite
        };
        xhr.open("GET", url);
        xhr.send();
    }
    // pull each CAP alert by id, parse, and publish once the whole batch is in
    function _fetchAlertDetails(ids, gen) {
        var results = [], pending = ids.length;
        for (var k = 0; k < ids.length; ++k) {
            var x = new XMLHttpRequest();
            // a hung detail would never decrement `pending`, so results never
            // publish — time it out and count it as a skipped (failed) detail.
            var settle = (function (xhr) {
                var fin = false;
                return function (use) {
                    if (fin || gen !== root._alertGen) return;   // superseded/done → drop
                    fin = true;
                    if (use && xhr.status === 200) {
                        var a = root._parseCapAlert(xhr.responseText);
                        // store the FULL set; the minimum-severity filter is applied at
                        // display time (displayAlerts) so the level can change live
                        if (a) results.push(a);
                    }
                    if (--pending === 0 && gen === root._alertGen) root.weatherAlerts = results;
                };
            })(x);
            x.timeout = 8000;
            x.ontimeout = (function (fn) { return function () { fn(false); }; })(settle);
            x.onreadystatechange = (function (xhr, fn) { return function () {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                fn(true);
            }; })(x, settle);
            // no trailing slash: /alert/{id} 301-redirects to the raw CAP file
            // (QML XHR follows the same-origin redirect automatically)
            x.open("GET", "https://alerts.kde.org/alert/" + encodeURIComponent(ids[k]));
            x.send();
        }
    }
    // CAP 1.2 XML → our alert object. CAP carries one <info> per language; pick
    // the UI language, else English, else the first. (Lightweight regex parse —
    // CAP's structure is regular and QML's XML DOM is awkward with namespaces.)
    function _xmlUnescape(s) {
        return s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
                .replace(/&#39;/g, "'").replace(/&apos;/g, "'").replace(/&amp;/g, "&");
    }
    function _capTag(s, tag) {
        var m = s.match(new RegExp("<" + tag + "\\b[^>]*>([\\s\\S]*?)<\\/" + tag + ">"));
        return m ? root._xmlUnescape(m[1].trim()) : "";
    }
    // ray-cast point-in-polygon. polyStr is a CAP <polygon> ("lat,lon lat,lon …").
    // Runs locally on our exact config coords — nothing is sent.
    function _pointInRing(lon, lat, polyStr) {
        var pts = polyStr.replace(/<\/?polygon>/g, "").trim().split(/\s+/);
        var c = false, n = pts.length;
        for (var i = 0, j = n - 1; i < n; j = i++) {
            var pi = pts[i].split(","), pj = pts[j].split(",");   // CAP order = lat,lon
            var yi = +pi[0], xi = +pi[1], yj = +pj[0], xj = +pj[1];
            if (((yi > lat) !== (yj > lat)) && (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)) c = !c;
        }
        return c;
    }
    function _parseCapAlert(xml) {
        var infos = xml.match(/<info\b[\s\S]*?<\/info>/g);
        if (!infos || !infos.length) return null;
        var want = Qt.locale().name.substring(0, 2).toLowerCase();
        var chosen = null, english = null;
        for (var i = 0; i < infos.length; ++i) {
            var lang = (root._capTag(infos[i], "language") || "").substring(0, 2).toLowerCase();
            if (lang === want) { chosen = infos[i]; break; }
            if (lang === "en" && !english) english = infos[i];
        }
        var blk = chosen || english || infos[0];
        // Local point-in-polygon filter: if the block carries polygon geometry, drop
        // the alert unless our EXACT point is inside one. Kills neighbour-area false
        // positives (a watch clipping the coarse query box). Geocode-only blocks have
        // no polygon to test → fall through and stay (box behaviour, can't do better).
        var polys = blk.match(/<polygon>[\s\S]*?<\/polygon>/g);
        if (polys && polys.length) {
            var plat = Plasmoid.configuration.latitude;
            var plon = Plasmoid.configuration.longitude;
            var inAny = false;
            for (var p = 0; p < polys.length; ++p)
                if (root._pointInRing(plon, plat, polys[p])) { inAny = true; break; }
            if (!inAny) return null;
        }
        var ev = root._capTag(blk, "event");
        return {
            event:       ev,
            severity:    root._capTag(blk, "severity") || "Unknown",
            headline:    root._capTag(blk, "headline") || ev,
            ends:        root._capTag(blk, "expires") || root._capTag(blk, "onset") || "",
            expires:     root._capTag(blk, "expires") || "",   // real CAP <expires>, for the expiry filter (ends may fall back to onset)
            description: root._capTag(blk, "description") || "",
            instruction: root._capTag(blk, "instruction") || ""
        };
    }

    // ── WMO weather code → human text ─────────────────────────────────────
    function conditionText(code, day) {
        if (code === 0 || code === 1)      return (day === 0) ? i18n("Clear night") : i18n("Clear sky");
        if (code === 2)                    return i18n("Partly cloudy");
        if (code === 3)                    return i18n("Overcast");
        if (code === 45 || code === 48)    return i18n("Fog");
        if (code === 56 || code === 57 || code === 66 || code === 67) return i18n("Freezing rain");
        if (code >= 51 && code <= 67)      return i18n("Rain");
        if (code >= 71 && code <= 77)      return i18n("Snow");
        if (code >= 80 && code <= 82)      return i18n("Showers");
        if (code === 85 || code === 86)    return i18n("Snow showers");
        if (code >= 95)                    return i18n("Thunderstorm");
        return "—";
    }

    // ── Icon packs (registry) ─────────────────────────────────────────────
    // Each entry says how to turn a WMO code into an icon source:
    //   dir        → a bundled Meteocons style, with the wi-* stem names below
    //                in <dir>static/ and their SMIL-animated twins in <dir>animated/
    //   mask:true  → one-colour artwork, drawn in the theme's text colour
    //   theme:true → freedesktop "weather-*" names from the user's icon theme
    //                (no bundled files; follows the desktop theme)
    //   custom     → the user's own folder of wi-*.svg files
    // Adding a pack = one entry here (+ its files under contents/icons/).
    readonly property var iconPacks: ({
        "meteocons-fill":       { dir: "../icons/meteocons/fill/",       animated: true },
        "meteocons-flat":       { dir: "../icons/meteocons/flat/",       animated: true },
        "meteocons-line":       { dir: "../icons/meteocons/line/",       animated: true },
        "meteocons-monochrome": { dir: "../icons/meteocons/monochrome/", animated: true, mask: true },
        "system":               { theme: true, animated: false },
        "custom":               { custom: true, ext: ".svg", animated: false }
    })
    // "basmilius", the pack these replaced (Meteocons too: flat stills, and fill
    // animations baked to WebP), and anything unknown fall back to the fill style.
    readonly property string iconPackId: iconPacks[Plasmoid.configuration.iconPack]
                                         ? Plasmoid.configuration.iconPack : "meteocons-fill"
    readonly property var _pack: iconPacks[iconPackId]
    // true when the active pack uses theme names (needs Kirigami.Icon, not Image)
    readonly property bool iconPackIsTheme: _pack.theme === true
    // one of the bundled Meteocons styles (their proportions drive iconZoom & co.)
    readonly property bool iconPackIsMeteocons: _pack.dir !== undefined
    // one-colour artwork that views tint with the theme's text colour
    readonly property bool iconPackIsMask: _pack.mask === true
    // The panel's default icon is a white silhouette of the Meteocons artwork,
    // whichever pack the popup uses — outline styles are too fine to read at
    // panel size.
    readonly property string panelWhiteDir: "../icons/basmilius-white/32/"
    // The popup's shared animated icons (AnimatedIconCache), set by the full
    // representation it lives in; null until then, and in the panel.
    property var iconCache: null

    // Probability-aware icon code: when an hour's chance of precipitation is high
    // (≥ rainIconThreshold) but its weather_code is only clear/cloudy, show a rain
    // icon. Open-Meteo's deterministic code can read "cloudy" through a likely-rain
    // stretch (it even alternates drizzle/overcast hour-to-hour) while the chance
    // stays high — the chance is the steadier signal, so the icon follows it.
    readonly property int  rainIconThreshold: 60     // chance% — NWS "likely" line
    readonly property real rainAmountThreshold: 0.1  // mm — any predicted precip counts
    // chance% at/under which a card shows NO precip — both the blue rain wash
    // (FullView's rainTideFloor reads this) and the per-hour precip% readout. One
    // source so the tint and the number can never disagree about "is it raining".
    // 20 = NWS "Slight Chance" line (its first firm precip wording); pairs with
    // rainIconThreshold's 60 = NWS "Likely". See DEVELOPMENT for the PoP table.
    readonly property real precipDisplayFloor: 20

    // ── Precipitation chance vs. amount ──────────────────────────────────
    // Not every provider publishes a CHANCE of precipitation. met.no only does for
    // the Nordic region — anywhere else every sample carries an amount but no
    // probability at all. Both helpers below decide from the SAMPLE, never from the
    // provider's name, so any provider (or any individual hour) that lacks a chance
    // gets the same treatment automatically.
    //
    // Does this sample carry a real chance of precipitation? Where it doesn't, a
    // missing value must not be read as 0% and printed.
    function hasPrecipChance(s) { return !!s && !isNaN(s.precip); }
    // Amount (mm) that paints the rain wash as heavily as a 100% chance would.
    readonly property real precipWashFullMm: 2.5
    // The rain WASH intensity for a sample, on the same 0-100 scale as a chance, so
    // the graph band and the card background keep one pipeline for both kinds of
    // provider. A real chance is used exactly as before. Without one, the amount
    // stands in, linearly: 2.5 mm or more is full intensity, 1.25 mm is half.
    // Amount and chance are different quantities — this is purely so a location
    // without a chance still shows its rain, not a claim that one implies the other.
    function precipWashPct(s) {
        if (!s) return 0;
        if (!isNaN(s.precip)) return s.precip;
        if (!isNaN(s.precipAmt))
            return Math.min(100, Math.max(0, s.precipAmt) / precipWashFullMm * 100);
        return 0;
    }
    // Real precipitation — at least rainAmountThreshold (0.1 mm), the same line the
    // icons use for "it rains" — on a sample with no chance to show for it. Such an
    // hour is raining and says so in its amount, but its amount-derived wash can still
    // fall under a view's display floor (up to 0.5 mm maps to 20% or less). Views use
    // this to give it at least their faintest rain treatment rather than none.
    function precipWithoutChance(s) {
        return !!s && isNaN(s.precip) && !isNaN(s.precipAmt) && s.precipAmt >= rainAmountThreshold;
    }
    readonly property real snowIconThreshold: 0.1    // cm/hr — at/above this it's snowing; show snow even over a RAIN code (marginal-temp mismatch)
    // cloud% at/above which DAYTIME snow drops the sun-and-cloud glyph for the
    // sun-free "overcast snow" icon — 85 = the METAR/WMO "overcast" (8/8) cutoff.
    readonly property real overcastCloudCover: 85
    // True only for daytime snow under (near-)full overcast — conditionStem gates
    // on it (→ wi-overcast-snow), and the static and animated icons share that
    // stem, so they can never disagree. Night snow is untouched.
    function isOvercastDaySnow(code, day, cloudCover) {
        return day !== 0
            && ((code >= 71 && code <= 77) || code === 85 || code === 86)
            && !isNaN(cloudCover) && cloudCover >= overcastCloudCover;
    }
    function precipAwareCode(code, precip, precipAmt, snow, temp) {
        var snowing = !isNaN(snow) && snow >= snowIconThreshold;
        var freezing = (units === "fahrenheit") ? 32 : 0;
        // Does this hour show precip at all? Either a precip weather_code, OR a
        // clear/cloudy code that a high chance / real amount upgrades to precip
        // (same test the chance-upgrade rule below uses). Both the sub-freezing
        // and mix-band rules need to fire on EITHER, else a cloudy-but-likely hour
        // slips past them and gets rain-upgraded.
        var precipCode = (code >= 51 && code <= 67) || (code >= 71 && code <= 86);
        var chanceUp   = code <= 3 && ((!isNaN(precip) && precip >= rainIconThreshold)
                                    || (!isNaN(precipAmt) && precipAmt >= rainAmountThreshold));
        var hasPrecip  = precipCode || chanceUp;
        // Sub-freezing air can't produce liquid rain/drizzle, yet Open-Meteo can
        // return a plain rain code (or a likely-rain cloudy code) at e.g. -6 °C.
        // Force snow. SKIP explicit freezing-rain codes (56/57/66/67) — legit
        // supercooled liquid, stays sleet.
        var freezingRain = (code === 56 || code === 57 || code === 66 || code === 67);
        if (!isNaN(temp) && temp <= freezing && hasPrecip && !freezingRain)
            return 71;                                // → snow icon (71–77 all map to snow)
        // Just above freezing (~33–39 °F / 0–4 °C), a RAIN code is the dubious one:
        // liquid rain at near-freezing amid cold air is really wintry MIX (verified
        // across GFS/ECMWF/ICON/wttr/met.no — they split, two independents said
        // sleet). So a rain/drizzle/shower hour (or a cloudy hour chance-upgraded to
        // rain) in that band → sleet (66 → wi-sleet). A SNOW code here is left ALONE
        // — it's a confident snow forecast, so consistent snow runs at 35–38 °F stay
        // snow instead of being blanket-converted to sleet. See DEVELOPMENT.
        var mixCeil = (units === "fahrenheit") ? 39 : 4;
        var rainType = (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || chanceUp;
        if (!isNaN(temp) && temp > freezing && temp <= mixCeil && rainType)
            return 66;                                // → sleet icon (56/57/66/67 all map to sleet)
        // Near freezing, Open-Meteo can return a RAIN weather_code while still
        // forecasting snowfall (cm). The amount is the honest signal, so trust it
        // over a rain/drizzle/showers code and show snow — keeping the icon in
        // step with the snow band tint, the snow labels, and the daily total.
        if (snowing && ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)))
            return 71;
        // only override a clear/cloudy code; a high CHANCE or a non-trivial
        // predicted AMOUNT both mean "show precip" (the amount catches hours where
        // Open-Meteo predicts real precip but leaves the chance/code understated).
        if (code <= 3 && ((!isNaN(precip) && precip >= rainIconThreshold)
                       || (!isNaN(precipAmt) && precipAmt >= rainAmountThreshold)))
            // if that precip is falling as snow, show snow — not rain
            return snowing ? 71 : 61;
        return code;
    }

    // ── WMO weather code → wi-* condition stem (night-aware) ──────────────
    // cloudCover (optional %) lets daytime snow swap the sun-and-cloud glyph for
    // the sun-free overcast-snow icon when the sky is (near-)fully overcast.
    function conditionStem(code, day, cloudCover) {
        var night = (day === 0);
        if (code === 0 || code === 1)      return night ? "wi-night-clear" : "wi-day-sunny";
        if (code === 2)                    return night ? "wi-night-alt-partly-cloudy" : "wi-day-cloudy";
        if (code === 3)                    return night ? "wi-night-cloudy" : "wi-cloudy";
        if (code === 45 || code === 48)    return night ? "wi-night-fog" : "wi-day-fog";
        // Daytime precip uses SUN-FREE stems (wi-rain/snow/sleet/thunderstorm) so a
        // 100%-overcast rain hour doesn't show a sun. Night keeps wi-night-alt-*, with
        // the moon.
        // freezing drizzle/rain (56/57/66/67) — the sleet glyph (rain + snowflakes)
        if (code === 56 || code === 57 || code === 66 || code === 67)
            return night ? "wi-night-alt-sleet" : "wi-sleet";
        if (code >= 51 && code <= 67)      return night ? "wi-night-alt-rain" : "wi-rain";
        if (code >= 80 && code <= 82)      return night ? "wi-night-alt-rain" : "wi-rain";
        // overcast daytime snow drops the sun
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return night ? "wi-night-alt-snow"
                         : (isOvercastDaySnow(code, day, cloudCover) ? "wi-overcast-snow" : "wi-snow");
        if (code >= 95)                    return night ? "wi-night-alt-thunderstorm" : "wi-thunderstorm";
        return "wi-cloudy";
    }
    // ── WMO weather code → freedesktop "weather-*" name (System theme pack) ─
    function conditionStemFreedesktop(code, day) {
        var night = (day === 0);
        if (code === 0 || code === 1)   return night ? "weather-clear-night" : "weather-clear";
        if (code === 2)                 return night ? "weather-few-clouds-night" : "weather-few-clouds";
        if (code === 3)                 return "weather-many-clouds";
        if (code === 45 || code === 48) return "weather-fog";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "weather-snow";
        if (code >= 95)                 return "weather-storm";
        // Breeze extension (not in the freedesktop standard set); sparse themes
        // without it fall back to their generic icon — acceptable for the rarer code.
        if (code === 56 || code === 57 || code === 66 || code === 67) return "weather-freezing-rain";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "weather-showers";
        return "weather-many-clouds";
    }
    // cloudCover (optional %) → daytime overcast snow gets the sun-free glyph.
    // stemOverride (optional) forces a specific wi-* stem for the bundled/custom
    // packs (e.g. the panel substituting its own overcast-night artwork); theme
    // packs ignore both since they use freedesktop names.
    function conditionIcon(code, day, cloudCover, stemOverride) {
        if (code < 0) return "weather-none-available";
        if (_pack.theme) return conditionStemFreedesktop(code, day);
        var stem = stemOverride || conditionStem(code, day, cloudCover);
        if (_pack.custom && Plasmoid.configuration.customIconDir)
            return Plasmoid.configuration.customIconDir + "/" + stem + _pack.ext;
        // bundled pack (or custom with no folder chosen → fall back to the fill style)
        var dir = _pack.dir || iconPacks["meteocons-fill"].dir;
        return Qt.resolvedUrl(dir) + "static/" + stem + ".svg";
    }
    // The animated twin of conditionIcon, or "" when the pack has none. Only
    // ConditionIcon asks for it, and only where a view animates icons.
    function conditionIconAnimated(code, day, cloudCover) {
        if (code < 0 || !_pack.animated) return "";
        return Qt.resolvedUrl(_pack.dir) + "animated/" + conditionStem(code, day, cloudCover) + ".svg";
    }
    // White (monochrome) variant — used for the panel/tray icon.
    function conditionIconWhite(code, day, cloudCover, stemOverride) {
        if (code < 0) return "weather-none-available";
        if (_pack.theme) return conditionStemFreedesktop(code, day);
        var stem = stemOverride || conditionStem(code, day, cloudCover);
        if (_pack.custom && Plasmoid.configuration.customIconDir)
            return Plasmoid.configuration.customIconDir + "/" + stem + _pack.ext;
        return Qt.resolvedUrl(panelWhiteDir) + stem + ".svg";
    }

    // Sunrise/sunset glyphs for the SimpleView temperature curve are DECORATION,
    // not condition icons, so they come from their own bundled pair regardless of
    // the active icon pack: the System theme has no sunrise/sunset glyph
    // (conditionIcon would yield a plain sun) and a Custom folder may not include
    // wi-sunrise/wi-sunset at all.
    function sunEventIcon(rise) {
        return Qt.resolvedUrl("../icons/sun-events/") + (rise ? "wi-sunrise" : "wi-sunset") + ".svg";
    }

    // The clear-night moon artwork (wi-night-clear) packs more visual mass into its
    // box than other condition icons, so it reads oversized at the same pixel size.
    // Scale the HERO down for that condition only (both layouts multiply their hero
    // size by this); everything else stays 1.0.
    function heroScale(code, day) {
        // Other packs (system theme, custom folder) have their own proportions, so
        // render them at the plain configured size rather than leaking these factors.
        if (!iconPackIsMeteocons) return 1.0;
        var night = (day === 0);
        if (night && (code === 0 || code === 1)) return 0.90;   // tame the heavy clear-night moon
        return 1.10;                                            // all other conditions a touch larger
    }

    // Zoom that makes a Meteocons icon fill its box. The artwork covers only about
    // half of its 128-unit canvas, so it is drawn ~1.45× larger and centred (the
    // empty margins overflow harmlessly). Static and animated icons share their
    // geometry, so both take the same factor. Meteocons-only: theme and custom
    // packs fill their own boxes, so they stay 1.0.
    // Per-condition because the glyphs fill their box by very different amounts: the
    // clear-DAY sun already fills ~75 % (rays spread wide), so the full 1.45× makes it
    // overflow and read large — it needs much less zoom than the ~50 %-fill moon.
    function iconZoom(code, day) {
        if (!iconPackIsMeteocons) return 1.0;
        if (day !== 0 && (code === 0 || code === 1)) return 1.20;   // sunny: lands at ~0.90 of the box
        if (code === 45 || code === 48) return (232 / 160) * 1.15;  // fog: a touch larger (sun/moon cut at the fog bank reads small)
        return 232 / 160;                                           // others: ~1.45× to fill the empty box
    }

    // ── UV index → text with WHO category ─────────────────────────────────
    function uvIndexText(uv) {
        if (isNaN(uv)) return "—";
        var v = Math.round(uv * 10) / 10;
        if (v <= 2)  return v + " (" + i18n("Low") + ")";
        if (v <= 5)  return v + " (" + i18n("Moderate") + ")";
        if (v <= 7)  return v + " (" + i18n("High") + ")";
        if (v <= 10) return v + " (" + i18n("Very High") + ")";
        return v + " (" + i18n("Extreme") + ")";
    }

    // ── Value colors ──────────────────────────────────────────────────────
    // Feels-like: warm when apparent sits in the top half of today's range,
    // blue below — ratio-based, so it works in °C or °F without a fixed window.
    function feelsColor(val) {
        var ft = (val === undefined) ? apparentTemp : val;
        if (isNaN(ft) || isNaN(highTemp) || isNaN(lowTemp) || highTemp === lowTemp)
            return Kirigami.Theme.textColor;
        var t = (ft - lowTemp) / (highTemp - lowTemp);
        return t >= 0.5 ? "#ff6e40" : "#42a5f5";
    }
    // Humidity: a "moisture" scale — dry amber → comfortable teal → muggy blue.
    function humidityColor(val) {
        var h = (val === undefined) ? humidity : val;
        if (isNaN(h)) return Kirigami.Theme.textColor;
        if (h < 30)  return "#d4a85f";
        if (h <= 60) return "#4db6ac";
        return "#1e88e5";
    }
    // UV: official WHO exposure-category colors.
    function uvColor(val) {
        var uv = (val === undefined) ? uvIndex : val;
        if (isNaN(uv)) return Kirigami.Theme.textColor;
        if (uv <= 2)  return "#43a047";
        if (uv <= 5)  return "#eab308";
        if (uv <= 7)  return "#fb8c00";
        if (uv <= 10) return "#e53935";
        return "#8e24aa";
    }

    // Location auto-detection is on-demand only — the config page's "Detect now"
    // button (Mullvad, no-logging). No startup detection: boot uses the stored
    // coordinates, so the widget never pings a geolocation service unprompted.
    Component.onCompleted: {
        // One-time carry-over: the condition font setting used to size the location
        // too, so start each layout's new location font at its condition font. Only a
        // location font still at its default is taken over; one already set is kept.
        if (!Plasmoid.configuration.locationFontsSplit) {
            if (Plasmoid.configuration.locationFontSize === 28)
                Plasmoid.configuration.locationFontSize = conditionFontSize;
            Plasmoid.configuration.locationFontsSplit = true;
        }
        // The graph zoom used to be a two-way switch; carry a 12-hour choice over to
        // the three-level setting, and clear the old key so this happens only once.
        if (Plasmoid.configuration.simpleHourly) {
            Plasmoid.configuration.graphZoom = 0;
            Plasmoid.configuration.simpleHourly = false;
        }
        restoreCache();
        fetchWeather();
        fetchAlerts();
    }

    Timer {
        interval: Math.max(1, root.refreshMinutes) * 60 * 1000
        running: true
        repeat: true
        onTriggered: { root.fetchWeather(); root.fetchAlerts(); }
    }

    // Staleness clock: 60s granularity is plenty for a 30-min threshold.
    // It doubles as the resume-from-suspend detector. Qt timers run on the
    // MONOTONIC clock, which is frozen while the machine sleeps, so the periodic
    // refresh above wakes up still believing it has most of its interval left —
    // after an 8-hour suspend the widget shows last night's weather until the
    // remainder plays out (or the user refreshes by hand). Date.now() is the wall
    // clock and DOES jump, so a gap far larger than our interval means we were
    // asleep (or the clock was stepped): refetch immediately.
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = Date.now();
            if (root._nowMs > 0 && now - root._nowMs > 150000) {   // 2+ missed ticks
                // arm the free-running retry too: right after resume the route is
                // usually still coming up, so this first attempt often black-holes
                root._bootProbes = 0;
                root._probeUntilOk = true;
                root.fetchWeather();
                root.fetchAlerts();
            }
            root._nowMs = now;
        }
    }

    // Day-boundary refresh: re-fetch just after local midnight so the daily array
    // rolls over (Open-Meteo returns days from the current local day). Without it,
    // "Today" keeps pointing at yesterday until the next periodic refresh — up to
    // refreshInterval minutes. One-shot, rescheduled for the next midnight each time.
    function _msToNextDay() {
        // Roll over at the LOCATION's midnight (locNow), matching the timezone-aware
        // "today"/timeline — not the viewer's. locNow() advances 1:1 with real time
        // (just shifted to the location's wall clock), so the field-difference below
        // is the real elapsed ms to the location's next midnight. Falls back to the
        // viewer's clock when the location offset is unknown, so it's correct either way.
        var now = locNow();
        var next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 20);
        return Math.max(1000, next.getTime() - now.getTime());
    }
    Timer {
        id: dayRollover
        interval: root._msToNextDay()
        running: true
        repeat: false
        onTriggered: {
            root.fetchWeather(); root.fetchAlerts();
            interval = root._msToNextDay();   // reschedule for the following midnight
            restart();
        }
    }

    // Boot resilience. At login the network is often not up when the first fetch
    // fires, so the widget would sit in the "?" state until the next periodic
    // refresh (refreshMinutes — up to 15 min). We retry until the first success,
    // but the retry MUST be driven by a free-running timer, NOT chained off the
    // request's error/timeout callback: a connect black-holed by a half-up route
    // (VPN tunnel mid-handshake) can hang without ever calling back — QML's
    // xhr.timeout doesn't reliably abort a connect stuck in that phase — and a
    // chain kicked only from that dead callback then stalls for the whole ~minute
    // until the OS connect timeout. This timer doesn't wait on the dead socket:
    // each tick aborts the prior attempt (see fetchWeather) and fires a fresh one,
    // so we load within one interval of the route coming up. It stops the instant
    // we have data (weatherCode ≥ 0) and after ~3 min hands off to periodic refresh.
    property var _wxhr: null         // current in-flight weather request (abortable)
    // Last-Modified per provider+url, for conditional re-fetches. met.no's terms
    // ask us not to re-request unchanged data; If-Modified-Since is the sanctioned
    // way to keep refreshing on schedule without pulling the payload every time.
    property var _lastModified: ({})
    // Which provider+url the data CURRENTLY on screen was parsed from. A 304 means
    // "unchanged since you last asked ME" — it says nothing about whether the model
    // still holds that provider's data. After switching away and back, the validator
    // is still cached but the model belongs to the other provider, so revalidating
    // would answer 304 and leave the widget showing the wrong source's forecast
    // under the new name. Only send If-Modified-Since when this matches.
    property string _loadedKey: ""
    property int _bootProbes: 0
    // Armed by the resume-from-suspend detector. Waking up is the boot case all over
    // again — the wifi is still reassociating, so the refetch hits the same half-up
    // route — except we already HAVE (stale) data, so `weatherCode < 0` is false and
    // the probe below would never run. Without it the widget sat on pre-sleep weather
    // until the next periodic refresh, up to 15 min later.
    property bool _probeUntilOk: false
    Timer {
        id: bootProbe
        interval: 10000              // worst-case wait after the route is up
        repeat: true
        running: (root.weatherCode < 0 || root._probeUntilOk) && _bootProbes < 18   // ~3 min, then leave it to periodic refresh
        onTriggered: { _bootProbes++; root.fetchWeather(); root.fetchAlerts(); }
    }
    // `loading` greys out the Refresh button, so anything that can leave it stuck true
    // takes the button with it — permanently, since the user's own escape hatch is the
    // button. A connect black-holed by a half-up route (see fetchWeather) hangs without
    // ever calling back, and xhr.timeout doesn't reliably fire in that phase, so this
    // clears the flag a beat after xhr.timeout should have. The request itself is left
    // alone; the next fetch aborts it.
    Timer {
        id: loadingWatchdog
        interval: 12000              // > xhr.timeout (8 s): only catches the never-called-back case
        onTriggered: root.loading = false
    }

    Connections {
        target: Plasmoid.configuration
        function onLatitudeChanged()        { root.fetchWeather(); root.weatherAlerts = []; alertsDebounce.restart(); }
        function onLongitudeChanged()       { root.fetchWeather(); root.weatherAlerts = []; alertsDebounce.restart(); }
        function onWeatherProviderChanged() { root.fetchWeather(); }
        // the offset feeds straight into a met.no request — a new zone means the
        // forecast has to be rebuilt on the new clock
        function onLocationTimezoneChanged() { root.fetchWeather(); }
        function onTemperatureUnitChanged() { Qt.callLater(root.reapplyUnits); }
        function onWindUnitChanged()        { Qt.callLater(root.reapplyUnits); }
        function onShowAlertsChanged()      { root.fetchAlerts(); }
        // On first-time setup, lat/lon and locationConfigured commit together on
        // Apply in an unspecified order — fetch on the flag too so weather always
        // loads even if the coordinates happened to write first (while gated off).
        function onLocationConfiguredChanged() { root.fetchWeather(); root.fetchAlerts(); }
    }
    // A location switch updates latitude AND longitude as two separate writes;
    // debounce so alerts are fetched once with the FINAL point, not on the first
    // half-changed (stale-longitude) write — which would land on the wrong place.
    Timer {
        id: alertsDebounce
        interval: 400
        onTriggered: root.fetchAlerts()
    }

    compactRepresentation: CompactView { weatherRoot: root }

    // Full popup: switch between the detailed (card) view and the simple (graph)
    // view per the simpleLayout setting. The wrapper forwards the inner view's
    // implicit/minimum sizing so the popup sizes correctly for either layout.
    fullRepresentation: Item {
        id: fullRep
        AnimatedIconCache {
            id: iconCacheItem
            Component.onCompleted: root.iconCache = iconCacheItem
            Component.onDestruction: if (root.iconCache === iconCacheItem) root.iconCache = null
        }
        readonly property var view: !root.hasLocation ? null
                                  : (root.simpleLayout ? simpleLoader.item : detailLoader.item)
        // Pin the WIDTH to the saved size once set. We drive the popup window
        // directly (below), but Plasma still follows this implicit size — and the
        // metric readouts change the view's implicit WIDTH on every scroll/pan, so
        // Plasma kept resizing the popup back to fit (the "resets when I scroll"
        // bug). A stable implicit width = saved width stops it. HEIGHT is NOT pinned:
        // it's stable during scroll (single-line readouts), and pinning it to savedH
        // fed capture → implicitHeight → resize → capture into a runaway vertical
        // grow. First run (unpinned width) tracks the view so the popup opens at its
        // natural size, then self-pins on first capture.
        implicitWidth:  savedW > 0 ? savedW : (view ? view.implicitWidth : Kirigami.Units.gridUnit * 32)
        implicitHeight: view ? view.implicitHeight : Kirigami.Units.gridUnit * 20
        // On the panel the popup keeps its own sizing. On the DESKTOP a widget has ONE
        // stored geometry that Plasma only ever grows (never shrinks) — per-layout or
        // auto-shrink sizing is impossible. We pin the minimum to the content size so
        // the box is always big enough for the active layout (no graph/pills spilling
        // past the edge, toolbar stays in the corner); the box settles at the largest
        // layout's size and both layouts share it. Size is driven by content
        // (Appearance settings). Panel popup keeps its own implicit sizing.
        readonly property real _deskW: view ? view.implicitWidth  : Kirigami.Units.gridUnit * 32
        readonly property real _deskH: view ? view.implicitHeight : Kirigami.Units.gridUnit * 20
        Layout.minimumWidth:  root.planar ? _deskW : (view ? view.Layout.minimumWidth  : 0)
        Layout.minimumHeight: root.planar ? _deskH : (view ? view.Layout.minimumHeight : 0)
        Layout.preferredWidth:  root.planar ? _deskW : implicitWidth
        Layout.preferredHeight: root.planar ? _deskH : implicitHeight

        // On the desktop the widget floats frameless over the wallpaper, so its text
        // can wash out on bright/busy backgrounds. Drop a soft shadow behind the whole
        // view (text + icons) for contrast. Desktop only — the panel popup has its own
        // background. ponytail: one layer effect instead of a shadow on every label;
        // the layer re-rasterises with the hero animation, fine for one desktop widget.
        layer.enabled: root.planar
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowBlur: 0.55
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }

        // ── Per-layout remembered popup size ──────────────────────────────
        // Plasma's AppletPopup owns the window size: it keeps ONE shared
        // popupWidth/popupHeight (saved on close, restored once on creation)
        // and ignores our Layout hints once a size is set. To give each
        // layout its own size we drive the popup window directly — restore
        // the active layout's saved size on open and on layout switch, and
        // capture user drags back into that layout's keys. We store the
        // CONTENT size (this Item's width/height); the window chrome delta is
        // measured live and re-added when applying, so 0 means "use the view's
        // implicit size" (first run).
        readonly property int savedW: root.simpleLayout ? Plasmoid.configuration.simplePopupWidth
                                                        : Plasmoid.configuration.detailPopupWidth
        readonly property int savedH: root.simpleLayout ? Plasmoid.configuration.simplePopupHeight
                                                        : Plasmoid.configuration.detailPopupHeight
        property bool _applying: false

        // On the desktop (Planar form factor) the full rep is embedded directly
        // in the containment view — its Window IS the desktop, not a popup. The
        // size-driving below would then resize the desktop window itself, which
        // a user reads as "it resizes the wallpaper" / "zooms in on layout switch"
        // (KDE Neon / Plasma 6.7 bug report). Return null off-panel so every
        // driver here no-ops; the embedded widget just sizes from its Layout hints.
        function _win() {
            if (Plasmoid.formFactor === PlasmaCore.Types.Planar) return null;
            return fullRep.Window.window;
        }

        function applySize() {
            var win = _win();
            if (!win || fullRep.width <= 0) return;
            var chromeW = win.width  - fullRep.width;
            var chromeH = win.height - fullRep.height;
            var w = (savedW > 0 ? savedW : Math.round(implicitWidth))  + chromeW;
            var h = (savedH > 0 ? savedH : Math.round(implicitHeight)) + chromeH;
            _applying = true;
            win.width  = w;
            win.height = h;
            Qt.callLater(function () { fullRep._applying = false; });
        }

        // Only a user can resize the popup, and only while it is open. Size changes
        // while it is hidden, or in the moment after it opens, come from Plasma itself:
        // it restores ONE shared popup size — whichever layout was last closed — onto
        // the preloaded popup at login. Taking that for a drag stored the graph
        // layout's size as the card layout's, which then opened too short, cards cut off.
        property double _openedMs: 0
        function _userCanResize() {
            return root.expanded && Date.now() - _openedMs > 600;
        }

        function captureSize() {
            if (_applying || fullRep.width <= 0 || fullRep.height <= 0) return;
            if (root.planar) return;   // desktop auto-fits to content; nothing to capture
            if (!_userCanResize()) return;
            if (root.simpleLayout) {
                Plasmoid.configuration.simplePopupWidth  = Math.round(fullRep.width);
                Plasmoid.configuration.simplePopupHeight = Math.round(fullRep.height);
            } else {
                Plasmoid.configuration.detailPopupWidth  = Math.round(fullRep.width);
                Plasmoid.configuration.detailPopupHeight = Math.round(fullRep.height);
            }
        }

        // User drags resize this Item; debounce, then store under the active
        // layout. Skipped while we're applying a size ourselves. Stamp the time of
        // a real (non-self) size change so _reflow can tell a drag from a content
        // reflow and not fight an in-progress resize.
        property double _lastDragMs: 0
        // A non-self WIDTH change is a user drag → latch "manual" so auto-fit-to-tabs
        // stops overriding their chosen width (Simple layout only; cleared on a day-
        // count change). Height drags don't disable width auto-fit.
        onWidthChanged:  {
            if (!_applying && _userCanResize()) {
                _lastDragMs = Date.now();
                if (root.simpleLayout) Plasmoid.configuration.simplePopupManual = true;
            }
            captureTimer.restart();
        }
        onHeightChanged: { if (!_applying && _userCanResize()) _lastDragMs = Date.now(); captureTimer.restart(); }
        Timer { id: captureTimer; interval: 250; onTriggered: fullRep.captureSize() }

        // A font/metric change alters the view's implicit (and minimum) size, so
        // Plasma would resize the popup to fit and the capture above would overwrite
        // the user's saved drag. On such a reflow, re-assert the PINNED dimension(s)
        // and drop the pending capture. Two musts, learned the hard way:
        //  • Only PINNED dims — re-applying an UNPINNED dim snaps it to the implicit
        //    size, which the live readouts nudge on every scroll → window jitter.
        //  • Skip if a real resize just happened (_lastDragMs): a drag's size change
        //    fires FIRST, so a drag-induced reflow must not fight the drag. A font
        //    change has no preceding size change, so it still re-asserts.
        // While a fit is "armed" (just opened / switched to Simple / changed the day
        // count), the view is still laying out its tabs — its implicit width keeps
        // changing for a few frames. Re-run the fit on each of those changes so we
        // measure the SETTLED width, not a half-laid-out one (the fresh-widget "didn't
        // auto-fit on first open" bug). Outside the armed window this does nothing, so
        // scroll-time readout nudges never trigger a resize. fitToTabs disarms once the
        // width converges.
        property double _fitArmedUntil: 0
        function armFit() {
            if (!root.simpleLayout) return;
            _fitArmedUntil = Date.now() + 1200;
            fitTimer.restart();
        }
        onImplicitWidthChanged:  {
            _reflow();
            if (root.simpleLayout && !Plasmoid.configuration.simplePopupManual
                && Date.now() < _fitArmedUntil) fitTimer.restart();
        }
        onImplicitHeightChanged: _reflow()
        function _reflow() {
            if (savedW <= 0 && savedH <= 0) return;      // nothing pinned → let implicit drive
            if (Date.now() - _lastDragMs < 200) return;  // a resize is in progress → don't fight it
            var win = _win();
            if (!win || fullRep.width <= 0) return;
            captureTimer.stop();
            _applying = true;
            var chromeW = win.width  - fullRep.width;
            var chromeH = win.height - fullRep.height;
            if (savedW > 0) win.width  = savedW + chromeW;
            if (savedH > 0) win.height = savedH + chromeH;
            Qt.callLater(function () { fullRep._applying = false; });
        }

        // Auto-fit the Simple popup to the day tabs — for ANY day count, growing OR
        // shrinking to an exact fit (the pills live in the header row, so the count
        // drives the view's implicit width; SimpleView floors it at gridUnit*34 so
        // few days don't shrink it absurdly). Runs only on the discrete count-change
        // event (popup open) — never on scroll, where the
        // live metric readouts also nudge the implicit width. A manual width resize
        // latches simplePopupManual, which suppresses this so the user's size sticks.
        // The timer lets the new pills lay out before we measure.
        function fitToTabs() {
            if (!root.simpleLayout || !view) return;
            if (Plasmoid.configuration.simplePopupManual) return;   // manual size wins
            var win = _win();
            if (!win || fullRep.width <= 0) return;
            // implicitWidth is an EXACT fit — SimpleView's header runs edge-to-edge
            // with negative margins, so it leaves no slack and a wide readout (e.g.
            // "UV index … Very High") spills the last day tab past the right edge.
            // Add headroom so the header spacer keeps breathing room and a changing
            // readout is absorbed there instead of clipping the tabs.
            var need = Math.round(view.implicitWidth) + Kirigami.Units.gridUnit * 2;
            if (Math.abs(fullRep.width - need) < 2) { _fitArmedUntil = 0; return; }  // converged → disarm
            Plasmoid.configuration.simplePopupWidth = need;    // persist the fitted width…
            Qt.callLater(applySize);                           // …and apply it now
        }
        Timer { id: fitTimer; interval: 60; onTriggered: fullRep.fitToTabs() }

        // Apply the saved size on open and on layout switch. ⚠️ NOT on savedW/H
        // change — capture writes those on every drag, and re-applying then both
        // fought the drag and yanked the unpinned dimension to its implicit size.
        Component.onCompleted: { Qt.callLater(applySize); armFit(); }

        // Resizing the popup BEFORE the newly-shown view paints stretches the stale
        // buffer for a frame, so on a switch we resize a couple frames later — the
        // warm view is already up at the old size, correct content and all.
        Timer { id: resizeAfterPaint; interval: 48; onTriggered: fullRep.applySize() }

        Connections {
            target: root
            function onExpandedChanged()    {
                if (root.expanded) {
                    fullRep._openedMs = Date.now();
                    Qt.callLater(fullRep.applySize);
                    fullRep.armFit();
                }
            }
            // Both views stay warm (loaders below), so a switch just flips which is
            // visible — no rebuild, no blank frame. Resize after the shown view paints.
            function onSimpleLayoutChanged() { resizeAfterPaint.restart(); fullRep.armFit(); }
        }

        // Both layouts stay instantiated once built, toggling visibility instead of
        // swapping a single Loader's sourceComponent: destroying and recreating the view
        // on every switch left an empty frame (the "flash"), while a warm view paints
        // the instant it's shown. active:false until hasLocation keeps the lazy-until-
        // located behaviour and lets the empty-state notice below stand in.
        //
        // But only the layout on SCREEN is built up front, synchronously, so the popup
        // opens with content. Building both at once made every first open pay for the
        // layout you weren't looking at too — the card layout alone is most of the cost.
        // The hidden one is built shortly after the visible one is ready, asynchronously
        // (in small slices, so it never stalls a frame). `asynchronous` is bound to
        // "hidden": switch to it before it has finished, and Qt completes it on the spot.
        //
        // The *Built latches keep a view alive once it exists. Without them, switching
        // before the warm-up began would drop the layout you just left (its `active`
        // would fall back to false) and build it again later.
        property bool warmHidden: false
        property bool detailBuilt: false
        property bool simpleBuilt: false
        Timer {
            interval: 400
            running: root.hasLocation && !fullRep.warmHidden
                     && (root.simpleLayout ? simpleLoader.status : detailLoader.status) === Loader.Ready
            onTriggered: fullRep.warmHidden = true
        }
        Loader {
            id: detailLoader
            anchors.fill: parent
            active: root.hasLocation && (!root.simpleLayout || fullRep.warmHidden || fullRep.detailBuilt)
            asynchronous: root.simpleLayout
            onLoaded: fullRep.detailBuilt = true
            visible: !root.simpleLayout
            sourceComponent: detailComp
        }
        Loader {
            id: simpleLoader
            anchors.fill: parent
            active: root.hasLocation && (root.simpleLayout || fullRep.warmHidden || fullRep.simpleBuilt)
            asynchronous: !root.simpleLayout
            onLoaded: fullRep.simpleBuilt = true
            visible: root.simpleLayout
            sourceComponent: simpleComp
        }
        Component { id: detailComp; FullView   { weatherRoot: root } }
        Component { id: simpleComp; SimpleView { weatherRoot: root } }

        // Out of the box there is no default city, so this stands in for the weather
        // view (null above). hasLocation flips in configLocation's _setLocation and
        // the manual lat/lon fields.
        Kirigami.InlineMessage {
            id: locationHint
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Kirigami.Units.largeSpacing
            z: 100
            visible: !root.hasLocation
            type: Kirigami.MessageType.Information
            text: i18n("No location set. Open settings to choose where to show the weather.")
            actions: [
                Kirigami.Action {
                    text: i18n("Open settings")
                    icon.name: "configure"
                    onTriggered: Plasmoid.internalAction("configure").trigger()
                }
            ]
        }

        // No forecast at all (nothing cached either) and the requests are failing —
        // typically the network is not up yet after login. Say so instead of leaving
        // an empty popup; the boot probe keeps retrying on its own.
        Kirigami.InlineMessage {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Kirigami.Units.largeSpacing
            z: 100
            visible: root.hasLocation && root.weatherCode < 0 && root.fetchFailing
            type: Kirigami.MessageType.Warning
            text: i18n("Can't reach %1 yet. Retrying automatically.", root.provider ? root.provider.displayName : "")
            actions: [
                Kirigami.Action {
                    text: i18n("Retry now")
                    icon.name: "view-refresh"
                    enabled: !root.loading
                    onTriggered: root.fetchWeather()
                }
            ]
        }
    }
}
