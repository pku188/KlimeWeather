/*
 * The left half of the popup header, shared by the layouts: the current-condition
 * icon and temperature, the condition under them, and the Weather Elements beside
 * them (none in the Detailed view, whose elements are all below the header).
 * Everything that differs between the layouts comes in through the properties below
 * — which elements to list, which hour and day they read, and how the animated icon
 * behaves — and the view decides where the row sits.
 *
 * Moved here from FullView and SimpleView, which each carried a copy.
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: heroRow
    property var weatherRoot: null
    property Item toolbar: null       // the view's WeatherToolbar (shared header geometry)
    property var metrics: []          // Weather Element ids to list, up to four
    property int selectedDay: 0       // the day the day-based elements report on
    property var sample: null         // the hour the elements read, and the wind arrow follows
    property bool animate: false      // the animated icon, when the view has it on
    property bool animCanBuild: true  // the view's go-ahead to build it (see ConditionIcon)
    property bool animPlaying: false  // and to let it move
    // the icon+temperature row's width: the view keeps its location clear of it
    readonly property real heroTempWidth: heroTemp.width
    readonly property int conditionPull: toolbar ? toolbar.conditionPull : 0
    // Every hour the view can hand in as `sample` (by hover or focus), and how many
    // days it can select — what elementsSteadyWidth has to make room for.
    property var readingHours: []
    property int readingDays: 0
    // ── A steady width for the Weather Elements ──
    // The widest the column can get over what the view can show: every hour it can
    // hand in (hovering the graph or an hourly card) and every day it can select.
    // The column holds that width while its readings change. In a popup narrow
    // enough that the location, day buttons and source sit right after it, they
    // otherwise moved with every reading — a hover across the graph slid them back
    // and forth. Worked out once per forecast and settings change, and only while
    // the header is shown (the layout warming up in the background skips it).
    readonly property real elementsSteadyWidth: {
        if (!weatherRoot || !visible || !metrics || !metrics.length) return 0;
        var hours = readingHours || [], days = Math.min(readingDays, weatherRoot.dailyData.length);
        var gap = Kirigami.Units.smallSpacing, widest = 0, icons = weatherRoot.elementsAsIcons;
        for (var m = 0; m < metrics.length; ++m) {
            var id = metrics[m], seen = {}, w = 0, i;
            // now, each day (the day totals and sun times), and each hour (the rest)
            var texts = [_reading(id, -1, null)];
            for (i = 0; i < days; ++i) texts.push(_reading(id, i, null));
            for (i = 0; i < hours.length; ++i)
                if (hours[i] && !hours[i].dayBreak) texts.push(_reading(id, -1, hours[i]));
            for (i = 0; i < texts.length; ++i) {
                var t = texts[i];
                if (!t || seen[t]) continue;
                seen[t] = true;
                w = Math.max(w, icons ? _partsWidth(t) : elementsFont.advanceWidth(_plainText(t)));
            }
            if (w <= 0) continue;
            if (id === "wind") w += gap * 2 + weatherRoot.windArrowSize;         // the arrow after the speed
            widest = Math.max(widest, Math.ceil(w) + 1);
        }
        return widest;
    }
    // An element as the column prints it, for measuring: its text, or in the icon style
    // its parts (JSON, so identical readings are measured once).
    function _reading(id, day, sample) {
        if (!weatherRoot.elementsAsIcons) return weatherRoot.metricText(id, day, sample);
        var p = weatherRoot.metricParts(id, day, sample, true);
        return p.length ? JSON.stringify(p) : "";
    }
    // the width of an icon-style element (ElementReading): an icon slot and its value
    // per part, with the spacings between them
    function _partsWidth(json) {
        var p = JSON.parse(json), w = 0, fontPx = elementsFont.font.pixelSize;
        for (var i = 0; i < p.length; ++i)
            w += iconSlot + Math.round(fontPx * 0.3) + elementsFont.advanceWidth(_plainText(p[i].text))
                 + (i > 0 ? Math.round(fontPx * 0.6) : 0);
        return w;
    }
    // Every element's icon sits centred in a slot this wide, so the values start level
    // (the widest artwork — sunrise, sunset — fits it).
    readonly property int iconSlot: Math.round((weatherRoot ? weatherRoot.headerInfoFontSize : 14) * 1.6)
    // what a styled Weather Element prints, without its markup (colours only)
    function _plainText(t) {
        return t.replace(/<[^>]*>/g, "").replace(/&#160;|&nbsp;/g, "\u00a0")
                .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
    }
    readonly property int headerGap: toolbar ? toolbar.headerGap : 0
    spacing: Kirigami.Units.largeSpacing

    // Icon and temperature, with the condition right under them. Its width
    // is the icon+temperature row's, so a long condition wraps there rather
    // than widening this column and pushing the Weather Elements aside
    // (see ConditionLabel for how an overlong word is handled).
    ColumnLayout {
        Layout.alignment: Qt.AlignTop
        spacing: 0

        // The icon and temperature centre on each other only. When the
        // Weather Elements shared their row, the column's line count set the
        // height they centred on, so a fourth element pushed them down.
        RowLayout {
            id: heroTemp
            spacing: Kirigami.Units.largeSpacing

            Item {
                // hero size, shrunk for the visually-heavy clear-night moon
                readonly property int heroSz: Math.round((weatherRoot ? weatherRoot.heroIconSize : 88)
                    * (weatherRoot ? weatherRoot.heroScale(weatherRoot.heroCode, weatherRoot.heroDay) : 1))
                Layout.preferredWidth:  heroSz
                Layout.preferredHeight: heroSz
                Layout.alignment: Qt.AlignVCenter
                Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 0.45)   // lift the icon a little

                ConditionIcon {
                    anchors.fill: parent
                    weatherRoot: heroRow.weatherRoot
                    code: weatherRoot ? weatherRoot.heroCode : -1
                    day: weatherRoot ? weatherRoot.heroDay : 1
                    cloud: weatherRoot ? weatherRoot.heroCloud : NaN
                    animate: heroRow.animate
                    canBuild: heroRow.animCanBuild
                    playing: heroRow.animPlaying
                }
            }
            Label {
                id: tempLabel
                text: weatherRoot ? weatherRoot.temperatureText : "—"
                color: Kirigami.Theme.textColor
                font.pixelSize: weatherRoot ? weatherRoot.tempFontSize : 54
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
                Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 0.7)   // lift the temperature a little
            }
        }
        ConditionLabel {
            Layout.topMargin: heroRow.conditionPull
            // The icon+temperature row plus the gap before the Weather Elements: the
            // gap belongs to this column (see below), so the condition can run into it
            // without widening the column and pushing the elements aside.
            maxWidth: heroTemp.implicitWidth + heroRow.headerGap
            text: weatherRoot ? weatherRoot.conditionText(weatherRoot.heroCode, weatherRoot.heroDay) : ""
            baseSize: weatherRoot ? weatherRoot.conditionFontSize : 26
        }
    }
    ColumnLayout {
        spacing: 0
        Layout.alignment: Qt.AlignTop
        // First line's capitals level with the tops of the temperature digits,
        // measured from both fonts so it holds at any size of either.
        Layout.topMargin: Math.round(tempLabel.y + tempLabel.baselineOffset + tempDigits.tightBoundingRect.y
                                     - (elementsFont.ascent + elementsCap.tightBoundingRect.y))
        TextMetrics { id: tempDigits; font: tempLabel.font; text: "0" }
        FontMetrics {
            id: elementsFont
            font.family: Kirigami.Theme.defaultFont.family
            font.weight: weatherRoot ? weatherRoot.headerInfoFontWeight : Font.DemiBold
            font.pixelSize: weatherRoot ? weatherRoot.headerInfoFontSize : 14
        }
        TextMetrics { id: elementsCap; font: elementsFont.font; text: "H" }
        // holds the column at elementsSteadyWidth (see above); no height of its own
        Item { Layout.preferredWidth: heroRow.elementsSteadyWidth; implicitHeight: 0 }
        // No margin of its own: the gap after the temperature (headerGap) is held by
        // the column on the left, whose condition is sized to include it. The
        // elements start at the same x either way; the condition just gets to use
        // that space.
        // the user's Weather Elements (up to 4); the alert mark is beside the location
        // (HeaderRightBlock)
        Repeater {
            model: heroRow.metrics
            delegate: RowLayout {
                id: metricRow
                required property int index
                required property var modelData
                // the hour the readouts are showing — the arrow below points
                // the way ITS wind blows, not some other hour's
                readonly property var sample: heroRow.sample
                // day-based elements (sun, precipitation and snow totals) follow the
                // view's selected day; the rest read the hour it hands in
                readonly property bool icons: weatherRoot ? weatherRoot.elementsAsIcons : false
                readonly property string metric: (weatherRoot && !icons)
                    ? weatherRoot.metricText(modelData, heroRow.selectedDay, heroRow.sample) : ""
                // the icon style: each value after the hourly cards' icon for it
                readonly property var parts: (weatherRoot && icons)
                    ? weatherRoot.metricParts(modelData, heroRow.selectedDay, heroRow.sample,
                                              weatherRoot.weatherSpecificColors) : []
                readonly property bool hasReading: icons ? parts.length > 0 : metric.length > 0
                visible: hasReading
                spacing: Kirigami.Units.smallSpacing
                Label {
                    visible: !metricRow.icons
                    textFormat: Text.StyledText
                    font.weight: weatherRoot ? weatherRoot.headerInfoFontWeight : Font.DemiBold
                    font.pixelSize: weatherRoot ? weatherRoot.headerInfoFontSize : 14
                    text: metricRow.metric
                }
                ElementReading {
                    visible: metricRow.icons && metricRow.parts.length > 0
                    weatherRoot: heroRow.weatherRoot
                    parts: metricRow.parts
                    fontPx: weatherRoot ? weatherRoot.headerInfoFontSize : 14
                    fontWeight: weatherRoot ? weatherRoot.headerInfoFontWeight : Font.DemiBold
                    coloredIcons: weatherRoot ? weatherRoot.readingIconsColored : false
                    iconSlot: heroRow.iconSlot
                }
                Kirigami.Icon {   // wind direction, after the speed (and its gust)
                    visible: metricRow.modelData === "wind" && metricRow.hasReading
                             && metricRow.sample && !isNaN(metricRow.sample.windDir)
                    source: Qt.resolvedUrl("../icons/wind-direction.svg")
                    isMask: true
                    color: Kirigami.Theme.textColor
                    roundToIconSize: false
                    rotation: (weatherRoot && metricRow.sample)
                              ? weatherRoot.windArrowRotation(metricRow.sample.windDir) : 0
                    // a little air after the reading it belongs to
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    Layout.preferredWidth: weatherRoot ? weatherRoot.windArrowSize : 21
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
