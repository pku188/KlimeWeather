/*
 * A reading's icon as an Image (main.qml readingIcon): in colour, the Element icon
 * pack's (Appearance → Common) — Meteocons' flat style, its line style with its greys
 * drawn in `tint`, or the user's own folder — else Meteocons' monochrome one drawn in
 * `tint`. An icon the custom folder doesn't have shows Meteocons' flat one instead of
 * nothing.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Image {
    id: img
    property var weatherRoot: null
    property string name: ""
    property bool colored: false
    property color tint: Kirigami.Theme.textColor
    // the monochrome line icons drawn less bold (the Detailed view's; see readingIcon)
    property bool lighter: false

    readonly property string wanted: weatherRoot && name ? weatherRoot.readingIcon(name, colored, tint, lighter) : ""
    property bool _missing: false
    onWantedChanged: _missing = false
    onStatusChanged: if (status === Image.Error && colored && !_missing) _missing = true

    sourceSize: Qt.size(width, height)
    source: _missing && weatherRoot ? weatherRoot.readingIconFlat(name) : wanted
}
