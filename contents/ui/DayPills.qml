/*
 * The graph layout's day pills (today + the graph's other days). Tapping one picks
 * that day; the mouse wheel over them steps a day per notch, down = later, matching
 * the direction the graph itself scrolls.
 *
 * Each pill is sized for its name in BOLD whether or not it is selected, so selecting
 * a day never changes a row's width — the rows would otherwise shift a few pixels with
 * every selection.
 *
 * Pills that run past `wrapWidth` wrap onto a new row, the way right-aligned text
 * wraps on a web page: each row is filled in order, as many pills as fit, and every
 * row ends at the right edge. A narrow popup then shows all its days on two rows
 * instead of cutting the last ones off.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "wheel.js" as Wheel

Item {
    id: pills
    property var weatherRoot: null
    property int count: 0
    property int selectedDay: -1
    // The widest a row may grow before the next pill wraps; 0 keeps them on one row.
    property real wrapWidth: 0
    signal dayClicked(int index)
    signal dayStepped(int delta)

    readonly property int spacing: Kirigami.Units.smallSpacing
    // A pill's height, which is a row's height too.
    readonly property int rowHeight: Math.round(Kirigami.Units.gridUnit * 1.7)
    // How many rows the pills take at the current wrapWidth.
    readonly property int rows: _rows

    property int _rows: 0
    property real _w: 0
    implicitWidth: _w
    implicitHeight: _rows > 0 ? _rows * rowHeight + (_rows - 1) * spacing : 0

    // Places the pills: rows filled in order, each one right-aligned. Imperative
    // rather than a positioner because Flow can only right-align by reversing the
    // order, which would read the days backwards.
    function relayout() {
        var n = rep.count, i, it;
        var rowsOut = [], row = [], rowW = 0;
        for (i = 0; i < n; ++i) {
            it = rep.itemAt(i);
            if (!it) return;   // still being built; itemAdded calls again
            var w = row.length ? rowW + spacing + it.width : it.width;
            if (row.length && wrapWidth > 0 && w > wrapWidth) {
                rowsOut.push({ items: row, width: rowW });
                row = [it];
                rowW = it.width;
            } else {
                row.push(it);
                rowW = w;
            }
        }
        if (row.length) rowsOut.push({ items: row, width: rowW });
        var widest = 0;
        for (i = 0; i < rowsOut.length; ++i) widest = Math.max(widest, rowsOut[i].width);
        for (i = 0; i < rowsOut.length; ++i) {
            var x = widest - rowsOut[i].width;
            for (var j = 0; j < rowsOut[i].items.length; ++j) {
                it = rowsOut[i].items[j];
                it.x = x;
                it.y = i * (rowHeight + spacing);
                x += it.width + spacing;
            }
        }
        _w = widest;
        _rows = rowsOut.length;
    }
    onWrapWidthChanged: Qt.callLater(relayout)
    onSpacingChanged: Qt.callLater(relayout)

    // Deltas accumulate, so a touchpad's many small ticks add up to one day rather
    // than firing a day per tick (see wheel.js).
    WheelHandler {
        id: pillsWheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: (wheel) => {
            wheel.accepted = true;
            var ad = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            var dir = Wheel.step(pillsWheel, ad);
            if (dir !== 0) pills.dayStepped(dir);
        }
    }

    Repeater {
        id: rep
        model: (pills.weatherRoot && pills.weatherRoot.dailyData)
               ? pills.weatherRoot.dailyData.slice(0, pills.count) : []
        onItemAdded: Qt.callLater(pills.relayout)
        onItemRemoved: Qt.callLater(pills.relayout)
        delegate: Rectangle {
            id: pill
            required property int index
            readonly property bool selected: index === pills.selectedDay
            width: Math.ceil(boldName.advanceWidth) + Math.round(Kirigami.Units.gridUnit * 1.1)
            height: pills.rowHeight
            radius: height / 2
            color: selected
                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.16)
                : (pillHover.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.08) : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }
            // a new font size or day name changes the row widths
            onWidthChanged: Qt.callLater(pills.relayout)
            HoverHandler { id: pillHover }
            TapHandler { onTapped: pills.dayClicked(pill.index) }
            TextMetrics {
                id: boldName
                font.family: pillLabel.font.family
                font.pixelSize: pillLabel.font.pixelSize
                font.bold: true
                text: pillLabel.text
            }
            Label {
                id: pillLabel
                anchors.centerIn: parent
                text: pills.weatherRoot ? pills.weatherRoot.dayName(pill.index, true) : ""
                font.bold: pill.selected
                font.pixelSize: pills.weatherRoot ? pills.weatherRoot.dayPillFontSize
                                                  : Kirigami.Theme.defaultFont.pixelSize + 2
            }
        }
    }
}
