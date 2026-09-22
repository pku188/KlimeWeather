/*
 * The condition text ("Overcast") under the header's icon and temperature, shared by
 * both layouts. It is held to `maxWidth` (the icon+temperature row) and wraps between
 * words. Only when a single word cannot fit that width does the font shrink, and then
 * just enough for that word — splitting a word, or letting it run into the Weather
 * Elements beside the temperature, both read worse.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Label {
    id: label
    property int baseSize: 26
    property real maxWidth: 0

    readonly property string longestWord: text.split(/\s+/).reduce(function (a, b) {
        return b.length > a.length ? b : a;
    }, "")

    Layout.preferredWidth: maxWidth
    wrapMode: Text.WordWrap
    font.bold: true
    font.pixelSize: (maxWidth > 0 && wordMetrics.advanceWidth > maxWidth)
                    ? Math.max(10, Math.floor(baseSize * maxWidth / wordMetrics.advanceWidth))
                    : baseSize

    // Measured at the configured size, independent of the font actually shown (which
    // is derived from this), so the two never feed each other.
    TextMetrics {
        id: wordMetrics
        font.family: label.font.family
        font.bold: true
        font.pixelSize: label.baseSize
        text: label.longestWord
    }
}
