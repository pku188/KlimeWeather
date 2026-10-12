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
 * The icon is hidden by capturing it (hideSource), not with visible: false: in a
 * Plasma panel popup (Qt 6.12) an animation inside an invisible item no longer makes
 * the window draw a new frame, and the icons froze (see AnimatedIconCache).
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
    }
    // the icon as a texture for the effect below, which is all that draws it
    ShaderEffectSource {
        id: artTexture
        anchors.fill: parent
        sourceItem: art
        hideSource: true
        live: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: artTexture
        brightness: 1.0
        colorization: 1.0
        colorizationColor: tinted.tint
    }
}
