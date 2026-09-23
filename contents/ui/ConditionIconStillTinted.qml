/*
 * The static monochrome icon, recoloured to `tint` (the theme's text colour) the
 * same way ConditionIconVectorTinted does it: brightness lifts the black artwork
 * to white, and colorization turns white into exactly the tint. The Image feeds
 * the effect directly as a texture, so this costs no extra render pass.
 *
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Effects

Item {
    id: still
    property url source
    property color tint: "white"
    Image {
        id: art
        anchors.fill: parent
        sourceSize: Qt.size(width, height)
        source: still.source
        visible: false   // drawn through the effect below
    }
    MultiEffect {
        anchors.fill: parent
        source: art
        brightness: 1.0
        colorization: 1.0
        colorizationColor: still.tint
    }
}
