/*
 * The icon before a reading: Meteocons' monochrome icon in the text colour, or the
 * Element icon pack's when coloured (see ReadingImage). An Image, so every copy of an
 * icon at one size shares one rendering — the hourly cards hold a couple hundred.
 *
 * Sized against the reading's font. It takes the width of its artwork — or of a fixed
 * slot, which lines the values up in a column — and the height of the reading's line:
 * the icon box, larger than both, overflows them, its empty margins unseen.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: icon
    property var weatherRoot: null
    property string name: ""          // a Meteocons reading icon (contents/icons/meteocons/readings)
    property bool colored: false
    property color tint: Kirigami.Theme.textColor
    property int fontPx: 14           // the reading's font
    property real slotWidth: 0        // 0 = the artwork's own width

    readonly property int boxSize: Math.round(fontPx * 2.2 * (weatherRoot ? weatherRoot.readingIconScale(name) : 1))
    implicitWidth: slotWidth > 0 ? slotWidth
                                 : Math.ceil(boxSize * (weatherRoot ? weatherRoot.readingIconSpan(name) : 1))
    implicitHeight: fontPx

    ReadingImage {
        anchors.centerIn: parent
        width: icon.boxSize
        height: width
        weatherRoot: icon.weatherRoot
        name: icon.name
        colored: icon.colored
        tint: icon.tint
    }
}
