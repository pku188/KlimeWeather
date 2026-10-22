/*
 * The Weather graph's zoom, 12 / 24 / 48 hours: zoom in and zoom out, left of the
 * refresh button (WeatherToolbar). At either
 * end of the range the button that would go further is disabled: no hover plate, no
 * tooltip, dimmed.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls

Row {
    id: zoom
    property var root: null   // weatherRoot reference
    // the glyphs' size: the toolbar's (Appearance → Common → Toolbar icon size)
    property int iconSize: root ? root.toolbarIconSize : 24
    spacing: 2

    ToolbarButton {
        glyphSize: zoom.iconSize
        iconName: "zoom-in"
        enabled: zoom.root && zoom.root.graphZoom > 0
        disabledOpacity: 0.5
        onClicked: if (zoom.root) zoom.root.zoomGraphIn()
        ToolTip.text: (zoom.root && zoom.root.graphZoom === 2) ? i18n("Zoom in to 24 hours")
                                                               : i18n("Zoom in to 12 hours")
    }
    ToolbarButton {
        glyphSize: zoom.iconSize
        iconName: "zoom-out"
        enabled: zoom.root && zoom.root.graphZoom < 2
        disabledOpacity: 0.5
        onClicked: if (zoom.root) zoom.root.zoomGraphOut()
        ToolTip.text: (zoom.root && zoom.root.graphZoom === 0) ? i18n("Zoom out to 24 hours")
                                                               : i18n("Zoom out to 48 hours")
    }
}
