/*
 * The weather source, shown in the header as the provider's logo mark and name, and
 * switched by clicking it. It always shows the source in use, never the one a click
 * would switch to (that is what the tooltip says). Shaped like the graph layout's day
 * pills, which it sits beside there, so it reads as part of the same set.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

AbstractButton {
    id: btn
    property var root: null   // weatherRoot reference
    property int fontSize: 16   // the name's pixel size; the logo scales with it
    readonly property var source: root ? root.provider : null

    // Same side padding as a day pill, and at least a pill's height, so the button sits
    // with them as one set.
    readonly property int sidePad: Math.round(Kirigami.Units.gridUnit * 0.55)
    // The marks are drawn 24 px tall, which is their size at the default 16 px text.
    readonly property int logoHeight: Math.round(fontSize * 1.5)
    implicitHeight: Math.max(Math.round(Kirigami.Units.gridUnit * 1.7), logoHeight + 4)
    implicitWidth: row.implicitWidth + sidePad * 2
    hoverEnabled: true

    background: Rectangle {
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                       btn.pressed ? 0.16 : (btn.hovered ? 0.08 : 0))
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    contentItem: Item {
        RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: btn.sidePad
            anchors.rightMargin: btn.sidePad
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                Layout.preferredHeight: btn.logoHeight
                Layout.preferredWidth: Math.round(btn.logoHeight * (btn.source ? btn.source.logoAspect : 1))
                source: btn.source ? Qt.resolvedUrl("../icons/providers/" + btn.source.logo) : ""
                isMask: true
                color: Kirigami.Theme.textColor
                roundToIconSize: false
            }
            Label {
                // elides if a narrow popup squeezes the button (the logo stays whole)
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: btn.source ? btn.source.displayName : ""
                font.pixelSize: btn.fontSize
            }
        }
    }

    onClicked: if (root) root.toggleProvider()
    Accessible.name: btn.source ? btn.source.displayName : ""
    Accessible.description: ToolTip.text
    ToolTip.visible: hovered
    ToolTip.text: root ? i18n("Switch to %1", root.nextProviderName) : ""
}
