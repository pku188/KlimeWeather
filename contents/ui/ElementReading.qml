/*
 * A reading drawn with icons: each part's icon (ReadingIcon) and its value after it
 * (see main.qml metricParts). Used by the panel's readings and by the Weather
 * Elements in their icon style.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Row {
    id: reading
    property var weatherRoot: null
    property var parts: []
    // the values' font — the font everything else in the widget uses
    property int fontPx: 14
    property int fontWeight: Font.Normal
    property color color: Kirigami.Theme.textColor
    // the flat, coloured icons rather than the monochrome ones in `color`
    property bool coloredIcons: false
    // a monochrome icon's opacity, a step softer than its value
    property real iconOpacity: 0.8
    // Width each icon is centred in: the Weather Elements give every icon the same
    // slot, so their values start level in a column. 0 = each artwork's own width.
    property real iconSlot: 0
    readonly property int innerSpacing: Math.round(fontPx * 0.3)

    spacing: Math.round(fontPx * 0.6)   // between parts (sunrise … sunset)

    Repeater {
        model: reading.parts
        delegate: Row {
            id: part
            required property var modelData
            spacing: reading.innerSpacing
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            ReadingIcon {
                anchors.verticalCenter: parent.verticalCenter
                weatherRoot: reading.weatherRoot
                name: part.modelData.icon
                colored: reading.coloredIcons
                tint: reading.color
                opacity: reading.coloredIcons ? 1 : reading.iconOpacity
                fontPx: reading.fontPx
                slotWidth: reading.iconSlot
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.StyledText
                text: part.modelData.text
                color: reading.color
                font.pixelSize: reading.fontPx
                font.weight: reading.fontWeight
            }
        }
    }
}
