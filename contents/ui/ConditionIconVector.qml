/*
 * The animated form of a condition icon: one of the pack's SMIL-animated SVGs,
 * drawn by Qt Quick's VectorImage. ConditionIcon loads this file only where a
 * view animates icons.
 *
 * Needs Qt 6.10 (VectorImage's animation controls). On an older Qt this file
 * fails to load, and ConditionIcon simply keeps showing the static icon.
 *
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.VectorImage

VectorImage {
    property bool playing: false
    fillMode: VectorImage.PreserveAspectFit
    // anti-aliased edges without multisampling, which the popup doesn't have
    preferredRendererType: VectorImage.CurveRenderer
    animations.paused: !playing
}
