/*
 * The graph layout's day pills (today + the graph's other days). Tapping one picks
 * that day; the mouse wheel over them steps a day per notch, down = later, matching
 * the direction the graph itself scrolls.
 *
 * Each pill is sized for its name in BOLD whether or not it is selected, so selecting
 * a day never changes the row's width — the location above lines up with the row's
 * left edge and would otherwise shift a few pixels with every selection.
 *
 * The card layout has no day pills, but keeps an invisible, disabled copy in the same
 * place (see HeaderRightBlock), so its header matches the graph layout's exactly.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "wheel.js" as Wheel

Row {
    id: pills
    property var weatherRoot: null
    property int count: 0
    property int selectedDay: -1
    signal dayClicked(int index)
    signal dayStepped(int delta)

    spacing: Kirigami.Units.smallSpacing

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
        model: (pills.weatherRoot && pills.weatherRoot.dailyData)
               ? pills.weatherRoot.dailyData.slice(0, pills.count) : []
        delegate: Rectangle {
            id: pill
            required property int index
            readonly property bool selected: index === pills.selectedDay
            width: Math.ceil(boldName.advanceWidth) + Math.round(Kirigami.Units.gridUnit * 1.1)
            height: Math.round(Kirigami.Units.gridUnit * 1.7)
            radius: height / 2
            color: selected
                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.16)
                : (pillHover.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.08) : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }
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
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
            }
        }
    }
}
