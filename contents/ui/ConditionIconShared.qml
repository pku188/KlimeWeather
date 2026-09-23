/*
 * One animated condition icon, played once and shown by every ConditionIcon that
 * draws the same picture at the same size (AnimatedIconCache hands them out). It
 * is never drawn itself: `texture` renders it off screen, and each user draws
 * that texture — so ten cards of "rain" cost one animation, and a graph slot
 * that takes a new hour just points at another texture instead of rebuilding.
 *
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: shared
    property string key
    property url svg
    property bool tinted: false
    // plays while any of its users would (AnimatedIconCache keeps this up to date)
    property bool playing: false
    // the ConditionIcons showing it, kept by AnimatedIconCache
    property var users: []
    // what the users draw
    readonly property Item texture: tex
    // false where the animated form can't load (Qt before 6.10): users stay static
    readonly property bool ok: vector.status === Loader.Ready

    Loader {
        id: vector
        anchors.fill: parent
        source: shared.tinted ? "ConditionIconVectorTinted.qml" : "ConditionIconVector.qml"
    }
    Binding { target: vector.item; property: "source"; value: shared.svg; when: vector.item !== null }
    Binding { target: vector.item; property: "playing"; value: shared.playing; when: vector.item !== null }
    Binding { target: vector.item; property: "tint"; value: Kirigami.Theme.textColor; when: vector.item !== null && shared.tinted }

    ShaderEffectSource {
        id: tex
        width: shared.width
        height: shared.height
        sourceItem: vector.item
        hideSource: true
        live: true
        visible: false   // a texture only; the users draw it
    }
}
