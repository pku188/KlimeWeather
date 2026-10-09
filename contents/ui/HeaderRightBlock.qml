/*
 * The right-hand side of the popup header, shared by both layouts: the location (a
 * button that opens the location settings) and the weather-source button side by side,
 * level with the toolbar buttons, and under them the day pills, right-aligned.
 *
 * The source ends just before the layout-switch button, which sits in the same spot in
 * both layouts (WeatherToolbar.buttonsLeft), so the pair holds its spot when the layout
 * switches. The location sits to the source's left, as far from it as the source is
 * from the switch glyph. The pair grows to the left, over the free space above the
 * Weather Elements, and stops at the temperature (`leftBound`): the source gives way
 * first, down to its logo alone, and only then does the location elide.
 *
 * The day pills share a line with the graph layout's zoom buttons (which are under
 * the other toolbar buttons), ending left of them, and wrap onto a second row when the
 * room between the Weather Elements (`pillsLeftBound`) and the zoom buttons is too
 * narrow for one. The card layout has no day pills:
 * it passes pillsShown: false and their row is left out. The graph layout takes them
 * out too (pillsInBlock: false) when even two rows are not enough, and shows them on a
 * row of their own under the header instead.
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
    // the x the day pills must stay right of (past the Weather Elements' right edge),
    // in the view's coordinates too
    property real pillsLeftBound: 0
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
    readonly property real capCenter: locationLine.y + locationLine.capLine
    // A pill's side padding, the source button's too: how far a plate reaches past
    // its name. The graph's row of pills under the header ends this far past the
    // block, so its last name ends level with the outer edge of the refresh glyph.
    readonly property real pillsOverhang: sourceButton.sidePad
    // How many rows the pills take beside the Weather Elements (2 = wrapped once). The
    // graph layout moves them under the header when this goes past two.
    readonly property int pillRows: pills.rows

    spacing: 0

    // The location and the source, placed by hand: the source from the toolbar, the
    // location from the source. Both may extend past the block's left edge.
    Item {
        id: locationLine
        Layout.fillWidth: true
        implicitWidth: 0   // placed by hand: it must not widen the block
        // Tall enough for both; their capitals' middles share one line (capLine), so
        // the smaller source sits centred beside the location like a toolbar button.
        readonly property real capLine: Math.max(locationButton.capCenter, sourceButton.capCenter)
        implicitHeight: Math.max(locationButton.y + locationButton.height,
                                 sourceButton.y + sourceButton.height)

        // All in this item's coordinates (it starts at the block's left edge).
        readonly property real viewX: block.originX + block.x
        // Air between the source's name and the layout-switch glyph, and between the
        // location and the source's logo: a step more than the day pills and the
        // source used to keep between their text when they shared a row (a pill's and
        // the source's side padding, and the row spacing between them).
        readonly property real gap: sourceButton.sidePad * 2 + Kirigami.Units.largeSpacing
                                    + Kirigami.Units.smallSpacing
        // where the source's name ends; the switch glyph starts 2 px into its button
        // (the hover plate)
        readonly property real rightLimit: (block.toolbar ? block.toolbar.buttonsLeft + 2 : viewX + width)
                                           - gap - viewX
        readonly property real leftLimit: block.leftBound - viewX
        // from the location's start to the source's name end
        readonly property real room: Math.max(0, rightLimit - leftLimit)
        // From the end of the location to the start of the source's plate (which
        // reaches sidePad past the logo): `gap` between the location and the logo.
        readonly property real pairGap: gap - sourceButton.sidePad

        ProviderButton {
            id: sourceButton
            // gives way first, down to the logo alone, so the location keeps its name
            width: Math.max(logoOnlyWidth,
                            Math.min(implicitWidth, locationLine.room - locationButton.implicitWidth
                                                    - locationLine.pairGap + sidePad))
            height: implicitHeight
            x: locationLine.rightLimit + sidePad - width
            y: locationLine.capLine - capCenter
            root: block.weatherRoot
            fontSize: block.providerFontSize
        }

        LocationButton {
            id: locationButton
            // elides only once the source is down to its logo
            width: Math.min(implicitWidth,
                            Math.max(0, locationLine.room - locationLine.pairGap
                                        - sourceButton.width + sourceButton.sidePad))
            height: implicitHeight
            x: sourceButton.x - locationLine.pairGap - width
            y: locationLine.capLine - capCenter
            root: block.weatherRoot
            fontSize: block.locationFontSize
        }
    }

    DayPills {
        id: pills
        visible: block.pillsShown && block.pillsInBlock
        Layout.alignment: Qt.AlignRight
        // The first row is centred on the zoom buttons' line. The views put the
        // block's capCenter on toolbar.buttonCenterY, which gives the block's top in
        // the toolbar's (view) coordinates.
        Layout.topMargin: block.toolbar
                          ? block.toolbar.stripCenterY - rowHeight / 2
                            - (block.toolbar.buttonCenterY - block.capCenter) - locationLine.implicitHeight
                          : Kirigami.Units.smallSpacing
        // Where the plates end, in view coordinates: the last pill's name ends `gap`
        // before the zoom-in glyph — the air between the source's name and the switch
        // glyph above — and its plate a pill's side padding past the name. The glyph
        // starts 2 px into its button (the hover plate).
        readonly property real plateEnd: block.toolbar
            ? block.toolbar.zoomLeft + 2 - locationLine.gap + block.pillsOverhang
            : block.originX + block.x + block.width
        Layout.rightMargin: (block.toolbar ? block.toolbar.width - block.toolbar.rightInset
                                           : block.originX + block.x + block.width) - plateEnd
        // from the room beside the Weather Elements to the plates' right end
        wrapWidth: plateEnd - block.pillsLeftBound
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
