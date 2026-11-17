/*
 * The day pills of the graph layout and the Detailed view (today + the view's other
 * days): a PillRow of the days' names. Tapping one picks that day; the mouse wheel
 * over them steps a day per notch, down = later, matching the direction the view
 * itself scrolls.
 *
 * Past five days (Forecast days over 5) they show five days at a time, between two
 * arrows: a sliding window. The days shown follow the selected day, moving only as
 * far as it takes, so the wheel slides them a day at a time once it passes either
 * end. An arrow picks the nearest day left out on its side, which brings it in; at
 * either end of the forecast that side's arrow is greyed out. Each day carries its
 * date under its name, which also keeps the pills about as wide wherever the window
 * is. On one row only: where it doesn't fit beside the Weather Elements, the views move
 * it under the header (fitsBeside). Up to five days, the names alone.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

PillRow {
    id: days
    property var weatherRoot: null
    property int count: 0
    property int selectedDay: -1
    signal dayClicked(int index)
    signal dayStepped(int delta)

    // the days there are pills for: as many as asked, as far as the forecast goes
    readonly property int dayCount: weatherRoot && weatherRoot.dailyData
                                    ? Math.min(count, weatherRoot.dailyData.length) : 0
    // how many days the window shows, and whether there are more than that
    readonly property int windowSize: 5
    readonly property bool windowed: dayCount > windowSize
    // The first day shown. Moves as little as it takes to keep the selected day in,
    // and keeps the window full at the end.
    property int firstDay: 0
    function keepSelectedShown() {
        if (!windowed) { firstDay = 0; return; }
        var first = Math.max(0, Math.min(firstDay, dayCount - windowSize)), sel = selectedDay;
        if (sel >= 0 && sel < dayCount) {
            if (sel < first) first = sel;
            else if (sel >= first + windowSize) first = sel - windowSize + 1;
        }
        firstDay = first;
    }
    onSelectedDayChanged: keepSelectedShown()
    onDayCountChanged: keepSelectedShown()
    Component.onCompleted: keepSelectedShown()

    readonly property int _first: windowed ? firstDay : 0
    readonly property int _shown: windowed ? windowSize : dayCount
    // the pill index of the first day: after the left arrow when windowed
    readonly property int _lead: windowed ? 1 : 0
    readonly property bool _moreBefore: windowed && _first > 0
    readonly property bool _moreAfter: windowed && _first + windowSize < dayCount

    function _date(i) { return weatherRoot ? weatherRoot.dailyDate(i) : ""; }
    labels: {
        var root = days.weatherRoot, out = [];
        if (!root) return out;
        if (days.windowed) out.push("");
        for (var i = days._first; i < days._first + days._shown; ++i) out.push(root.dayName(i, true));
        if (days.windowed) out.push("");
        return out;
    }
    // windowed, each day's date under its name, in the system's date format
    subLabels: {
        if (!windowed) return [];
        var out = [""];
        for (var i = _first; i < _first + windowSize; ++i) out.push(_date(i));
        out.push("");
        return out;
    }
    icons: {
        if (!windowed) return [];
        var out = ["arrow-left"];
        for (var i = 0; i < windowSize; ++i) out.push("");
        out.push("arrow-right");
        return out;
    }
    disabled: {
        if (!windowed) return [];
        var out = [!_moreBefore];
        for (var i = 0; i < windowSize; ++i) out.push(false);
        out.push(!_moreAfter);
        return out;
    }
    selectedIndex: selectedDay >= _first && selectedDay < _first + _shown ? selectedDay - _first + _lead : -1
    fontPx: weatherRoot ? weatherRoot.dayPillFontSize : Kirigami.Theme.defaultFont.pixelSize + 2
    onPicked: (index) => {
        if (days.windowed && index === 0) {
            if (!days._moreBefore) return;
            // The days brought in can be narrower and the row shorter, which would
            // move this arrow from under the pointer: the row keeps its width (and the
            // arrow its place) until the pointer leaves it.
            days.holdWidth();
            days.dayClicked(days._first - 1);
        } else if (days.windowed && index === days.labels.length - 1) {
            if (days._moreAfter) days.dayClicked(days._first + days.windowSize);
        } else {
            days.dayClicked(days._first + index - days._lead);
        }
    }
    onStepped: (delta) => days.dayStepped(delta)
    // a held row (see onPicked) lets go with the popup too, which can close under a
    // pointer that never left the row
    Connections {
        target: days.weatherRoot
        function onExpandedChanged() { days.releaseHold(); }
    }

    // The widest the row gets, windowed, over every place the window can be: whether
    // it fits beside the Weather Elements is decided at that width, so sliding the
    // window never moves the pills under the header and back.
    readonly property real widestWidth: {
        if (!windowed || !weatherRoot) return 0;
        var _font = fontPx, root = weatherRoot, widest = 0;
        for (var f = 0; f + windowSize <= dayCount; ++f) {
            var w = 2 * pillWidth("", "", "arrow") + (windowSize + 1) * spacing;
            for (var i = f; i < f + windowSize; ++i) w += pillWidth(root.dayName(i, true), _date(i), "");
            widest = Math.max(widest, w);
        }
        return widest;
    }
    // Whether the pills fit beside the Weather Elements (wrapWidth): windowed on one
    // row at its widest, otherwise on at most two rows.
    readonly property bool fitsBeside: windowed ? (wrapWidth <= 0 || widestWidth <= wrapWidth) : rows <= 2
}
