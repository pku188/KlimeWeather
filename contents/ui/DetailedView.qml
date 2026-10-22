/*
 * The Detailed view: the header the other layouts have — without Weather Elements of
 * its own — and under it every element for one hour at once (Appearance → Detailed
 * view → Detailed view Elements), three to a row: the sun, the date and the moon
 * first by default.
 *
 * The mouse wheel anywhere on it moves an hour per notch, down = later, and so do the
 * arrows beside refresh, where the Weather graph has its zoom. The day
 * buttons, in the graph layout's spot, jump to a day: at the "Day starts at" hour
 * (General), today at the current hour. The hour shown is weatherRoot's
 * detailedFocusTime: a click on an hourly card sets it, and it goes back to the current
 * hour when the view is left.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "wheel.js" as Wheel
import "detailedelements.js" as DetailedElements

Item {
    id: dv

    property var weatherRoot

    readonly property int pad: Math.round(Kirigami.Units.gridUnit * 0.85)
    // Top of the header row, in view coordinates (as in the graph layout).
    readonly property int headerY: Math.round(pad * 1.0)
    // False while the popup is closed (see SimpleView).
    readonly property bool onScreen: Window.visibility !== Window.Hidden
    readonly property int fontPx: weatherRoot ? weatherRoot.detailedFontSize : 15
    readonly property int fontWeight: weatherRoot ? weatherRoot.detailedFontWeight : Font.DemiBold
    readonly property int iconSize: Math.round(fontPx * 2.6)
    // between a reading's icon and its text: a few pixels past the spacing, which the
    // wider artwork (the wind's, the cloud's) nearly filled
    readonly property int iconGap: Kirigami.Units.largeSpacing + Math.round(fontPx * 0.3)

    // ── Coming in ──
    // As the Daily forecast deals its cards, when the view shows, when the popup opens
    // and when the hour changes: the elements rise into place and fade in, in a wave
    // from the top left — each a stagger after the one before it in its row or its
    // column (see DetailedElement.enter). Appearance → Detailed view → Element entrance
    // duration scales the pace, 0 none.
    readonly property real entrancePace: (weatherRoot ? weatherRoot.detailedEntrancePercent : 60) / 100
    readonly property int entranceDuration: Math.round(550 * entrancePace)
    readonly property int entranceStagger: Math.round(80 * entrancePace)
    signal entrance()
    Component.onCompleted: if (visible) Qt.callLater(dv.entrance)
    // shown, it comes in; left, it is back at the current hour for the next time
    onVisibleChanged: {
        if (visible) entrance();
        else if (weatherRoot) weatherRoot.detailedFocusTime = "";
    }
    Connections {
        target: dv.weatherRoot
        function onExpandedChanged() { if (dv.weatherRoot.expanded && dv.visible) dv.entrance(); }
    }

    // ── The hour shown ──
    // Every hour the view can show: its days' forecast, from the current hour on.
    readonly property var hours: {
        if (!weatherRoot) return [];
        var _hourly = weatherRoot.allHourly;   // refreshes with every forecast…
        var _turn = halfHour;                  // …and as the hours turn, between them
        return weatherRoot.timeline(weatherRoot.detailedDays).filter(function (e) { return !e.dayBreak; });
    }
    // the clock to the half hour: the hours shown move on with it (half an hour for
    // the time zones that start their hours then)
    readonly property int halfHour: weatherRoot ? Math.floor(weatherRoot.clockMs / 1800000) : 0
    readonly property int dayCount: weatherRoot ? Math.min(weatherRoot.detailedDays, weatherRoot.dailyData.length) : 0
    // The hour detailedFocusTime names, or the first after it once it has passed; with
    // none named, the current hour.
    readonly property int index: {
        var t = weatherRoot ? weatherRoot.detailedFocusTime : "";
        if (!t || !hours.length) return 0;
        for (var i = 0; i < hours.length; ++i)
            if (hours[i].time >= t) return i;
        return hours.length - 1;
    }
    readonly property bool isNow: index === 0
    readonly property var sample: hours.length ? hours[index] : (weatherRoot ? weatherRoot.currentHourSample : null)
    readonly property int selectedDay: sample && weatherRoot ? weatherRoot.dayIndexForDate(sample.date) : 0

    // The hour as new Date() reads the forecast's own times (the location's clock) —
    // now, to the minute, for the current hour — and as a true instant (main.qml's
    // clock, which ticks on each minute's turn).
    readonly property var refDate: !weatherRoot ? new Date()
        : isNow || !sample ? weatherRoot.locAt(weatherRoot.clockMs) : new Date(sample.time)
    readonly property real refUtcMs: !weatherRoot ? Date.now()
        : isNow || !sample ? weatherRoot.clockMs : weatherRoot.sampleUtcMs(sample)

    // an hour before the one shown, and one after it (the hour buttons)
    readonly property bool canHourBack: index > 0
    readonly property bool canHourForward: index < hours.length - 1
    function selectIndex(i) {
        if (!weatherRoot || !hours.length) return;
        i = Math.max(0, Math.min(hours.length - 1, i));
        if (i === index) return;
        weatherRoot.detailedFocusTime = i === 0 ? "" : hours[i].time;
        entrance();   // the new hour comes in as the view does
    }
    // A day opens at the "Day starts at" hour, today at the current hour — or at its
    // first 6-hour block, which that hour would skip (as the card layout's day tabs).
    function dayStartIndex(d) {
        if (!weatherRoot || d <= 0 || d >= weatherRoot.dailyData.length) return 0;
        var date = weatherRoot.dailyData[d].date, first = -1;
        for (var i = 0; i < hours.length; ++i) {
            var h = hours[i];
            if (h.date !== date) continue;
            if (first < 0) first = i;
            if (h.spanHours > 1 || new Date(h.time).getHours() >= weatherRoot.detailDayStartHour) return i;
        }
        return Math.max(0, first);
    }
    function goToDay(d) { selectIndex(dayStartIndex(Math.max(0, Math.min(dayCount - 1, d)))); }
    function stepDay(delta) { goToDay(selectedDay + delta); }

    // An hour per notch, anywhere on the view but the buttons, which have their own.
    WheelHandler {
        id: hourWheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: (wheel) => {
            wheel.accepted = true;
            var ad = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            var dir = Wheel.step(hourWheel, ad);
            if (dir !== 0) dv.selectIndex(dv.index + dir);
        }
    }

    // ── The elements ──
    readonly property var rows: weatherRoot ? DetailedElements.rows(weatherRoot.detailedElements) : []
    // Each reading's widest text over every hour the view can show — its name and its
    // value — so the columns hold still while the hour changes.
    FontMetrics { id: labelFont; font.pixelSize: dv.fontPx }
    FontMetrics { id: valueFont; font.pixelSize: dv.fontPx; font.weight: dv.fontWeight }
    function _plain(t) {
        return String(t).replace(/<[^>]*>/g, "").replace(/&#160;|&nbsp;/g, " ")
                        .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
    }
    readonly property var textWidths: {
        var out = {};
        if (!weatherRoot || !visible) return out;
        var dayOf = {};
        for (var d = 0; d < weatherRoot.dailyData.length; ++d) dayOf[weatherRoot.dailyData[d].date] = d;
        var arrow = weatherRoot.windArrowSize + Kirigami.Units.smallSpacing;
        for (var r = 0; r < rows.length; ++r) {
            for (var c = 0; c < rows[r].length; ++c) {
                var id = rows[r][c];
                if (id === "sun" || id === "moon" || out[id] !== undefined) continue;
                var w = valueFont.advanceWidth("—"), seen = {};
                for (var i = 0; i < hours.length; ++i) {
                    var h = hours[i];
                    var di = dayOf[h.date] !== undefined ? dayOf[h.date] : 0;
                    // the weather: its condition over its temperature (DetailedElement)
                    var label = id === "weather"
                        ? weatherRoot.conditionText(weatherRoot.precipAwareCode(h.code, h.precip, h.precipAmt, h.snow, h.temp), h.day)
                        : weatherRoot.metricLabel(id, di);
                    var value = id === "weather" ? weatherRoot.tempStr(h.temp)
                        : _plain(weatherRoot.metricValue(id, di, h, false));
                    var key = label + "|" + value;
                    if (seen[key]) continue;
                    seen[key] = true;
                    w = Math.max(w, labelFont.advanceWidth(label),
                                 valueFont.advanceWidth(value) + (id === "wind" ? arrow : 0));
                }
                // the current hour shows the header's weather (DetailedElement)
                if (id === "weather")
                    w = Math.max(w, labelFont.advanceWidth(weatherRoot.conditionText(weatherRoot.heroCode, weatherRoot.heroDay)),
                                 valueFont.advanceWidth(weatherRoot.temperatureText));
                out[id] = Math.ceil(w) + 1;
            }
        }
        return out;
    }
    function blockWidth(id) {
        return iconSize + iconGap + (textWidths[id] || 0);
    }

    WeatherToolbar {
        id: toolbar
        pad: dv.pad
        root: weatherRoot
        // the location line is centred on the top buttons; see WeatherToolbar.topDrop
        lineCap: rightBlock.capCenter
        // beside refresh, the previous and the next hour
        stepButtons: true
        canStepBack: dv.canHourBack
        canStepForward: dv.canHourForward
        stepBackText: i18n("Previous hour")
        stepForwardText: i18n("Next hour")
        onStepped: (delta) => dv.selectIndex(dv.index + delta)
    }

    // The day pills move under the header when the room beside the date line would
    // take more than two rows of them (as in the graph layout).
    readonly property bool pillsUnderHeader: rightBlock.pillRows > 2

    implicitWidth:  Math.max(Kirigami.Units.gridUnit * 34, content.implicitWidth + pad * 2)
    implicitHeight: content.implicitHeight + pad + Math.round(pad * 1.0)
    // the other layouts' minimum, so they all squeeze to the same width; and all of its
    // height, as nothing in it scrolls (the wheel moves the hour)
    Layout.minimumWidth: Kirigami.Units.gridUnit * 32 + pad * 2
    Layout.minimumHeight: implicitHeight

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: dv.pad
        anchors.rightMargin: dv.pad
        anchors.bottomMargin: dv.pad
        anchors.topMargin: dv.headerY
        spacing: Kirigami.Units.smallSpacing

        // ── Header ── (placed from the shared header geometry, as in the graph layout)
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            // Out to the view's right edge, past the content's padding: the day pills and
            // the layout buttons reach a pill's padding past the refresh glyph's edge, and
            // a row ending at the padding doesn't hand the input on that strip to them.
            Layout.rightMargin: -dv.pad
            Layout.alignment: Qt.AlignTop
            spacing: Kirigami.Units.largeSpacing

            // Icon, temperature and condition: the elements are all below.
            HeaderHero {
                id: heroRow
                Layout.alignment: Qt.AlignTop
                Layout.leftMargin: toolbar.heroRowX - dv.pad
                Layout.topMargin: toolbar.heroRowY - dv.headerY
                weatherRoot: dv.weatherRoot
                toolbar: toolbar
                metrics: []
                animate: dv.weatherRoot ? dv.weatherRoot.fullHeaderAnim : false
                animCanBuild: dv.onScreen && dv.visible
                animPlaying: dv.onScreen
            }

            Item { Layout.fillWidth: true }

            HeaderRightBlock {
                id: rightBlock
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
                Layout.topMargin: toolbar.buttonCenterY - dv.headerY - capCenter
                Layout.rightMargin: toolbar.rightInset
                pillsInBlock: !dv.pillsUnderHeader
                weatherRoot: dv.weatherRoot
                toolbar: toolbar
                originX: content.x + headerRow.x
                leftBound: content.x + headerRow.x + heroRow.x + heroRow.heroTempWidth + Kirigami.Units.largeSpacing * 2
                pillsLeftBound: content.x + headerRow.x + heroRow.x + heroRow.width + headerRow.spacing * 2
                locationFontSize: weatherRoot ? weatherRoot.locationFontSize : 26
                providerFontSize: weatherRoot ? weatherRoot.providerFontSize : 16
                pillCount: dv.dayCount
                selectedDay: dv.selectedDay
                onDayClicked: (index) => dv.goToDay(index)
                onDayStepped: (delta) => dv.stepDay(delta)
            }
        }

        // The day pills on a row of their own (see pillsUnderHeader), right-aligned.
        Item {
            id: underHeaderRow
            visible: dv.pillsUnderHeader
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            // out to the view's edge, as the header row (see there)
            Layout.rightMargin: -dv.pad
            implicitHeight: underHeaderPills.implicitHeight
            // where the plates end: level with the pills in the header block
            readonly property real plateEnd: width - (toolbar.rightInset - rightBlock.pillsOverhang)
            DayPills {
                id: underHeaderPills
                x: underHeaderRow.plateEnd - implicitWidth
                wrapWidth: underHeaderRow.plateEnd
                weatherRoot: dv.weatherRoot
                count: dv.dayCount
                selectedDay: dv.selectedDay
                onDayClicked: (index) => dv.goToDay(index)
                onDayStepped: (delta) => dv.stepDay(delta)
            }
        }

        // ── Elements, a row at a time ──
        ColumnLayout {
            id: rowsColumn
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 52
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.topMargin: Kirigami.Units.largeSpacing * 2 + toolbar.contentGap
            spacing: Math.round(Kirigami.Units.gridUnit * 1.3)

            // For each column, the widest reading in it: the column's readings start
            // where that one centres, so they line up.
            readonly property var columnWidths: {
                var out = [0, 0, 0];
                for (var r = 0; r < dv.rows.length; ++r)
                    for (var c = 0; c < dv.rows[r].length; ++c) {
                        var id = dv.rows[r][c];
                        if (id !== "sun" && id !== "moon") out[c] = Math.max(out[c], dv.blockWidth(id));
                    }
                return out;
            }

            Repeater {
                model: dv.rows
                delegate: Item {
                    id: rowItem
                    required property var modelData
                    required property int index
                    readonly property real colW: width / 3
                    Layout.fillWidth: true
                    implicitHeight: {
                        var h = 0;
                        for (var i = 0; i < cells.count; ++i) {
                            var cell = cells.itemAt(i);
                            if (cell) h = Math.max(h, cell.implicitHeight);
                        }
                        return h;
                    }
                    Repeater {
                        id: cells
                        model: rowItem.modelData
                        delegate: DetailedElement {
                            id: cell
                            required property var modelData
                            required property int index
                            readonly property bool special: modelData === "sun" || modelData === "moon"
                            // the room its column leaves its text
                            readonly property real room: rowItem.colW - dv.iconSize - dv.iconGap
                                                         - Kirigami.Units.smallSpacing
                            // the sun and the moon centre in their cell; the readings line up
                            // in their column
                            readonly property real spanW: special ? implicitWidth : rowsColumn.columnWidths[index]
                            x: Math.round(index * rowItem.colW + Math.max(0, (rowItem.colW - spanW) / 2))
                            // the sun and the moon end level, their last lines on one line;
                            // the other elements sit in the middle of the row
                            y: special ? rowItem.height - height : Math.round((rowItem.height - height) / 2)
                            width: implicitWidth
                            height: implicitHeight
                            weatherRoot: dv.weatherRoot
                            elementId: modelData
                            sample: dv.sample
                            isNow: dv.isNow
                            dayIdx: dv.selectedDay
                            refDate: dv.refDate
                            refUtcMs: dv.refUtcMs
                            fontPx: dv.fontPx
                            fontWeight: dv.fontWeight
                            iconGap: dv.iconGap
                            iconCanBuild: dv.onScreen && dv.visible
                            iconPlaying: dv.onScreen
                            textWidth: Math.min(dv.textWidths[modelData] || 0, Math.max(0, room))
                            Connections {
                                target: dv
                                function onEntrance() {
                                    cell.enter((rowItem.index + cell.index) * dv.entranceStagger, dv.entranceDuration);
                                }
                            }
                        }
                    }
                }
            }
        }

        // the rows keep together at the top of a taller popup
        Item { Layout.fillHeight: true }
    }
}
