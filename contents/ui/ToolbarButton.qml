/*
 * Icon button for the popup's top-right toolbar (zoom, switch layout, refresh). The
 * glyph is one of the single-colour SVGs in contents/icons/toolbar/, tinted to the
 * theme's text colour; hover and press show a round plate behind it, in the same
 * translucent text colour the day tabs and pills use for their hover.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

AbstractButton {
    id: btn
    // file name in contents/icons/toolbar/, without ".svg"
    property string iconName: ""
    // how faint the glyph gets while disabled (e.g. refresh during a fetch)
    property real disabledOpacity: 0.4

    // The glyphs are drawn on a 24 px grid and shown at exactly that size to stay crisp;
    // the padding leaves room for the hover plate around them.
    readonly property int glyphSize: 24
    padding: 2
    width: glyphSize + padding * 2
    height: width
    hoverEnabled: true

    background: Rectangle {
        radius: width / 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                       btn.pressed ? 0.16 : (btn.hovered ? 0.08 : 0))
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    contentItem: Kirigami.Icon {
        source: btn.iconName.length ? Qt.resolvedUrl("../icons/toolbar/" + btn.iconName + ".svg") : ""
        isMask: true
        color: Kirigami.Theme.textColor
        roundToIconSize: false
        opacity: btn.enabled ? 1 : btn.disabledOpacity
    }

    Accessible.name: ToolTip.text
    ToolTip.visible: hovered
}
