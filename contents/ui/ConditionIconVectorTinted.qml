/*
 * The animated monochrome icon, recoloured to `tint` (the theme's text colour).
 * The artwork is black: brightness lifts it to white and colorization then turns
 * white into exactly the tint, so it reads on light and dark themes alike.
 * A separate file so the other packs never load the effects module.
 *
 * The effect is an item of its own drawing the hidden icon, not a layer effect on
 * the icon: ConditionIconShared captures this item into a texture, and a capture
 * takes an item's content without its layer effect — the icons came out black.
 *
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Effects

Item {
    id: tinted
    property alias source: art.source
    property alias playing: art.playing
    property color tint: "white"

    ConditionIconVector {
        id: art
        anchors.fill: parent
        visible: false   // drawn through the effect below
    }
    MultiEffect {
        anchors.fill: parent
        source: art
        brightness: 1.0
        colorization: 1.0
        colorizationColor: tinted.tint
    }
}
