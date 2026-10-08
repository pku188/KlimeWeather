/*
 * The right-hand side of the popup header, shared by both layouts: the location (a
 * button that opens the location settings) level with the toolbar buttons, under it
 * the weather-source button, and under that the day pills — all right-aligned.
 *
 * The location ends just before the graph layout's zoom-in button, in both layouts
 * (WeatherToolbar.fullButtonsLeft), so it holds its spot when the layout switches. A
 * longer name grows to the left, over the free space above the Weather Elements, and
 * only elides once it would reach the temperature (`leftBound`).
 *
 * The card layout has no day pills: it passes pillsShown: false and their row is
 * left out. The graph layout takes them out too (pillsInBlock: false) when they are
 * too long for the room beside the Weather Elements, and shows them on a row of
 * their own under the header instead.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: block
    property var weatherRoot: null
    property Item toolbar: null            // the view's WeatherToolbar (shared header geometry)
    // Where the parent row starts, and the x the location must stay right of, both in
    // the view's coordinates (the toolbar's coordinates too, as it fills the view).
    property real originX: 0
    property real leftBound: 0
    // the x the source button must stay right of (the Weather Elements' right edge),
    // in the view's coordinates too
    property real sourceLeftBound: 0
    property int locationFontSize: 26
    property int providerFontSize: 16
    property bool pillsShown: true
    property bool pillsInBlock: true
    property int pillCount: 0
    property int selectedDay: -1
    signal dayClicked(int index)
    signal dayStepped(int delta)

    // Middle of the location's capitals from the block's top; the view aligns the
    // block so this sits level with the toolbar buttons.
    readonly property real capCenter: locationLine.y + locationButton.capCenter
    // How far the pills' plates reach past the block's right edge (they end where the
    // source button's plate does), and the width they need inside the block.
    readonly property real pillsOverhang: sourceButton.sidePad
    readonly property real pillsWidth: pills.implicitWidth - pillsOverhang

    spacing: 0

    Item {
        id: locationLine
        Layout.fillWidth: true
        // The location is placed by hand below and may extend past the block's left
        // edge, so it must not widen the block.
        implicitWidth: 0
        implicitHeight: locationButton.implicitHeight

        // All in this item's coordinates (it starts at the block's left edge).
        readonly property real viewX: block.originX + block.x
        // Air between the name and the zoom-in glyph: a step more than the day pills
        // and the source used to keep between their text when they shared a row (a
        // pill's and the source's side padding, and the row spacing between them).
        readonly property real gap: sourceButton.sidePad * 2 + Kirigami.Units.largeSpacing
                                    + Kirigami.Units.smallSpacing
        // the zoom-in button's glyph starts 2 px into the button (its hover plate)
        readonly property real rightLimit: (block.toolbar ? block.toolbar.fullButtonsLeft + 2 : viewX + width)
                                           - gap - viewX
        readonly property real leftLimit: block.leftBound - viewX

        LocationButton {
            id: locationButton
            width: Math.min(implicitWidth, Math.max(0, locationLine.rightLimit - locationLine.leftLimit))
            height: implicitHeight
            x: Math.max(locationLine.leftLimit, locationLine.rightLimit - width)
            root: block.weatherRoot
            fontSize: block.locationFontSize
        }
    }

    // The source, placed by hand from the view's right edge — like the toolbar
    // buttons, it never moves. In a narrow popup the header row runs out of room and
    // is pushed past the edge; a source laid out in it went along. Here it holds its
    // spot and shortens its name instead, down to the logo alone, keeping clear of
    // the Weather Elements.
    Item {
        id: sourceLine
        Layout.fillWidth: true
        Layout.topMargin: block.toolbar ? block.toolbar.sourceRowGap : 0
        implicitWidth: 0   // placed by hand: it must not widen the block
        implicitHeight: sourceButton.implicitHeight

        // All in this item's coordinates (it starts at the block's left edge).
        readonly property real viewX: block.originX + block.x
        // where the source name ends: the toolbar's inset from the view's right edge
        // (its plate reaches sidePad further, level with the outer edge of a glyph)
        readonly property real nameEnd: (block.toolbar ? block.toolbar.width - block.toolbar.rightInset
                                                       : viewX + width) - viewX
        readonly property real leftLimit: block.sourceLeftBound - viewX

        ProviderButton {
            id: sourceButton
            width: Math.max(logoOnlyWidth,
                            Math.min(implicitWidth, sourceLine.nameEnd + sidePad - sourceLine.leftLimit))
            height: implicitHeight
            x: sourceLine.nameEnd + sidePad - width
            root: block.weatherRoot
            fontSize: block.providerFontSize
        }
    }

    DayPills {
        id: pills
        visible: block.pillsShown && block.pillsInBlock
        Layout.alignment: Qt.AlignRight
        Layout.topMargin: Kirigami.Units.smallSpacing
        // the last pill's plate ends where the source button's does, so their names
        // end level too (the two share a side padding)
        Layout.rightMargin: -sourceButton.sidePad
        weatherRoot: block.weatherRoot
        count: block.pillCount
        selectedDay: block.selectedDay
        onDayClicked: (index) => block.dayClicked(index)
        onDayStepped: (delta) => block.dayStepped(delta)
    }

    // Stale marker (see main.qml weatherStale): when the shown data has aged past the
    // threshold, say how old it is instead of passing it off as current.
    Label {
        Layout.alignment: Qt.AlignRight
        visible: block.weatherRoot && block.weatherRoot.weatherStale
        text: block.weatherRoot ? block.weatherRoot.staleAgeText() : ""
        opacity: 0.6
        font.italic: true
        font.pixelSize: Math.round(block.locationFontSize * 0.5)
    }
}
