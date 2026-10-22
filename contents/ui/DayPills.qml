/*
 * The day pills of the graph layout and the Detailed view (today + the view's other
 * days): a PillRow of the days' names. Tapping one picks that day; the mouse wheel
 * over them steps a day per notch, down = later, matching the direction the view
 * itself scrolls.
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

    labels: {
        var root = days.weatherRoot;
        if (!root || !root.dailyData) return [];
        var out = [];
        for (var i = 0; i < Math.min(days.count, root.dailyData.length); ++i) out.push(root.dayName(i, true));
        return out;
    }
    selectedIndex: selectedDay
    fontPx: weatherRoot ? weatherRoot.dayPillFontSize : Kirigami.Theme.defaultFont.pixelSize + 2
    onPicked: (index) => days.dayClicked(index)
    onStepped: (delta) => days.dayStepped(delta)
}
