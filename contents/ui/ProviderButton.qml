/*
 * The weather source, shown in the header as the logo mark of the provider it comes
 * from and the name of the forecast (the service whose model it is: "CHMI" through
 * Open-Meteo, Open-Meteo itself for its Best match), and switched by clicking it
 * between the default and the alternative forecast (General settings). It always
 * shows the forecast in use, never the one a click would switch to (that is what the
 * tooltip says). With no alternative it only shows it: no hover, no click. Shaped like
 * the graph layout's day pills, so it reads as part of the same header.
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
    // the forecast in use, and whether a click switches to another
    readonly property string sourceName: root && root.source ? root.source.name : (source ? source.displayName : "")
    readonly property bool switches: root ? root.hasAlternative : false

    // Same side padding as a day pill, and at least a pill's height, so the button sits
    // with them as one set.
    readonly property int sidePad: Math.round(Kirigami.Units.gridUnit * 0.55)
    // The marks are drawn 24 px tall, which is their size at the default 16 px text.
    readonly property int logoHeight: Math.round(fontSize * 1.5)
    implicitHeight: Math.max(Math.round(Kirigami.Units.gridUnit * 1.7), logoHeight + 4)
    implicitWidth: row.implicitWidth + sidePad * 2
    // the narrowest it goes: the logo alone, its name elided away
    readonly property real logoOnlyWidth: Math.round(logoHeight * (source ? source.logoAspect : 1)) + sidePad * 2
    hoverEnabled: true

    background: Rectangle {
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                       !btn.switches ? 0 : btn.pressed ? 0.16 : (btn.hovered ? 0.08 : 0))
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
                id: nameLabel
                // elides if a narrow popup squeezes the button (the logo stays whole)
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: btn.sourceName
                font.pixelSize: btn.fontSize
            }
        }
    }

    onClicked: if (root && switches) root.toggleProvider()
    Accessible.name: sourceName
    Accessible.description: ToolTip.text
    ToolTip.visible: hovered && switches
    ToolTip.text: switches && root.otherSource ? i18n("Switch to %1", root.otherSource.text) : ""
}
