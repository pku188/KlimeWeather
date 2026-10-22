/*
 * A step back and a step forward, left of the refresh button where the Weather graph
 * has its zoom (WeatherToolbar): the Detailed view's previous and next hour, the Daily
 * forecast's hourly cards a mouse wheel notch either way. The wheel does both too, but a touchpad's fine steps make
 * that hard to do a step at a time. At either end the button that would go further is
 * disabled: no hover plate, no tooltip, dimmed.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls

Row {
    id: steps
    property var root: null   // weatherRoot reference
    property bool canBack: false
    property bool canForward: false
    property string backText: ""
    property string forwardText: ""
    signal stepped(int delta)
    // the glyphs' size: the toolbar's (Appearance → Common → Toolbar icon size)
    property int iconSize: root ? root.toolbarIconSize : 24
    spacing: 2

    ToolbarButton {
        glyphSize: steps.iconSize
        iconName: "arrow-back"
        enabled: steps.canBack
        disabledOpacity: 0.5
        onClicked: steps.stepped(-1)
        ToolTip.text: steps.backText
    }
    ToolbarButton {
        glyphSize: steps.iconSize
        iconName: "arrow-forward"
        enabled: steps.canForward
        disabledOpacity: 0.5
        onClicked: steps.stepped(1)
        ToolTip.text: steps.forwardText
    }
}
