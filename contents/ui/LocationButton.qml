/*
 * The location name in the popup header, as a button that opens the widget's
 * settings on the Location page. Hover and press show a rounded plate that reaches a
 * little past the text, so the text itself stays exactly where the header puts it.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

AbstractButton {
    id: btn
    property var root: null   // weatherRoot reference
    property int fontSize: 26

    // Where the capital letters start, and their vertical middle, from the button's top.
    // The header uses the middle to put the name level with the toolbar buttons at any
    // font size.
    readonly property real capTop: row.y + label.y + label.baselineOffset + capMetrics.tightBoundingRect.y
    readonly property real capCenter: capTop + capMetrics.tightBoundingRect.height / 2

    padding: 0
    hoverEnabled: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    background: Item {
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -Kirigami.Units.smallSpacing * 2
            anchors.rightMargin: -Kirigami.Units.smallSpacing * 2
            radius: 8   // as the card layout's day tabs
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                           btn.pressed ? 0.16 : (btn.hovered ? 0.08 : 0))
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    contentItem: Item {
        RowLayout {
            id: row
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "mark-location"
                roundToIconSize: false   // render at the exact size, not snapped to 16/22/32
                // scale the pin with the font so they stay balanced
                Layout.preferredWidth:  Math.round(btn.fontSize * 1.17)
                Layout.preferredHeight: Math.round(btn.fontSize * 1.17)
            }
            Label {
                id: label
                // gives way first in a popup too narrow for the header
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: btn.root ? btn.root.locationShortName : ""
                font.bold: true
                font.pixelSize: btn.fontSize
            }
        }
    }
    TextMetrics { id: capMetrics; font: label.font; text: "H" }

    onClicked: if (root) root.openLocationSettings()
    Accessible.name: label.text
    Accessible.description: ToolTip.text
    ToolTip.visible: hovered
    ToolTip.text: i18n("Change location")
}
