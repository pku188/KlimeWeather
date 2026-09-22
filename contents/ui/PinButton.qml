/*
 * "Keep window open" toggle for the popup's top-left corner, drawn like the Breeze
 * title bar's "On all desktops" button: a bare pin while the popup closes on focus
 * loss, the pin cut out of a disc while it is kept open. Hovering shows the disc too,
 * previewing the state a click switches to (and matching the title-bar button).
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

ToolButton {
    id: pin
    property var root: null   // weatherRoot reference
    readonly property bool active: root ? root.keepOpen : false

    // the glyphs are drawn on a 24 px grid; showing them at that size keeps them crisp
    width: 24; height: 24
    padding: 0
    flat: true
    // No hover/pressed plate: the glyph swap is the feedback, as on the title bar.
    background: Item {}
    contentItem: Kirigami.Icon {
        source: Qt.resolvedUrl("../icons/toolbar/"
                               + ((pin.active || pin.hovered) ? "pin-pinned.svg" : "pin-unpinned.svg"))
        // single-colour glyph, tinted to the theme's text colour
        isMask: true
        color: Kirigami.Theme.textColor
        roundToIconSize: false
    }

    // Deliberately not `checkable`: a toggle writes `checked` itself, which would break
    // a binding to keepOpen. Both layouts carry their own pin and the hidden one is kept
    // alive, so each must follow the shared setting rather than its own click history.
    onClicked: if (root) root.setKeepOpen(!root.keepOpen)
    Accessible.name: ToolTip.text
    ToolTip.visible: hovered
    ToolTip.text: active ? i18n("Unpin window") : i18n("Keep window open")
}
