/*
 * The right-hand side of the popup header, shared by both layouts: the location (a
 * button that opens the location settings) level with the toolbar buttons, and under
 * it the day pills and the weather-source button.
 *
 * The location ends just before the graph layout's zoom-in button, in both layouts
 * (WeatherToolbar.fullButtonsLeft), so it holds its spot when the layout switches. A
 * longer name grows to the left, over the free space above the Weather Elements, and
 * only elides once it would reach the temperature (`leftBound`).
 *
 * The source is pinned to the view's right edge, like the toolbar buttons above it:
 * it holds its spot in both layouts and at any width, and in a popup too narrow for
 * its name it shortens to the logo alone, keeping clear of the Weather Elements
 * (`sourceLeftBound`). The day pills sit to its left on the same line and wrap onto a
 * second row when the room between the Weather Elements (`pillsLeftBound`) and the
 * source is too narrow for one. The card layout has no day pills: it passes
 * pillsShown: false. The graph layout takes them out too (pillsInBlock: false) when
 * even two rows are not enough, and shows them on a row of their own under the
 * header instead.
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
    // the x the source must stay right of (the Weather Elements' right edge), and the x
    // the day pills must, in the view's coordinates too
    property real sourceLeftBound: 0
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
    readonly property real capCenter: locationLine.y + locationButton.capCenter
    // A pill's side padding, the source button's too: how far a plate reaches past
    // its name. The graph's row of pills under the header ends this far past the
    // block, so its last name ends level with the outer edge of the refresh glyph.
    readonly property real pillsOverhang: sourceButton.sidePad
    // How many rows the pills take beside the Weather Elements (2 = wrapped once). The
    // graph layout moves them under the header when this goes past two.
    readonly property int pillRows: pills.rows

    // The block's left edge in the view's coordinates. Everything in it is placed by
    // hand from the view and may extend past that edge, so nothing widens the block.
    readonly property real viewX: originX + x
    // The block's top in the view's coordinates: the views put capCenter on the
    // toolbar's buttonCenterY.
    readonly property real viewY: toolbar ? toolbar.buttonCenterY - capCenter : 0

    spacing: 0

    Item {
        id: locationLine
        Layout.fillWidth: true
        implicitWidth: 0
        implicitHeight: locationButton.implicitHeight

        // All in this item's coordinates (it starts at the block's left edge).
        // Air between the name and the zoom-in glyph: a pill's and the source's side
        // padding and a row's spacings, the most the two lines below keep between
        // their text.
        readonly property real gap: sourceButton.sidePad * 2 + Kirigami.Units.largeSpacing
                                    + Kirigami.Units.smallSpacing
        // the zoom-in button's glyph starts 2 px into the button (its hover plate)
        readonly property real rightLimit: (block.toolbar ? block.toolbar.fullButtonsLeft + 2 : block.viewX + width)
                                           - gap - block.viewX
        readonly property real leftLimit: block.leftBound - block.viewX

        LocationButton {
            id: locationButton
            width: Math.min(implicitWidth, Math.max(0, locationLine.rightLimit - locationLine.leftLimit))
            height: implicitHeight
            x: locationLine.rightLimit - width
            root: block.weatherRoot
            fontSize: block.locationFontSize
        }
    }

    // The source and the day pills, on one line.
    Item {
        id: secondLine
        Layout.fillWidth: true
        // secondRowGap under whichever reaches lower: the location or the corner
        // buttons (larger toolbar icons), which the source sits right under
        Layout.topMargin: (block.toolbar ? Math.max(0, block.toolbar.buttonsBottom
                                                       - (block.viewY + locationLine.implicitHeight))
                                           + block.toolbar.secondRowGap
                                         : Kirigami.Units.smallSpacing)
        implicitWidth: 0
        // the line itself: the taller of the source and a row of pills, both centred on it
        readonly property real lineHeight: Math.max(sourceButton.implicitHeight, pills.rowHeight)
        implicitHeight: pills.visible ? Math.max(lineHeight, (lineHeight - pills.rowHeight) / 2 + pills.implicitHeight)
                                      : lineHeight

        // In this item's coordinates (it starts at the block's left edge), where the
        // source's name ends: level with the outer edge of the refresh glyph.
        readonly property real nameEnd: (block.toolbar ? block.toolbar.width - block.toolbar.rightInset
                                                       : block.viewX + width) - block.viewX

        ProviderButton {
            id: sourceButton
            // shortens to the logo rather than run into the Weather Elements
            width: Math.max(logoOnlyWidth,
                            Math.min(implicitWidth, secondLine.nameEnd + sidePad
                                                    - (block.sourceLeftBound - block.viewX)))
            height: implicitHeight
            x: secondLine.nameEnd + sidePad - width
            y: (secondLine.lineHeight - height) / 2
            root: block.weatherRoot
            fontSize: block.providerFontSize
        }

        DayPills {
            id: pills
            visible: block.pillsShown && block.pillsInBlock
            // the plates end a row's spacing before the source's plate
            readonly property real plateEnd: sourceButton.x - Kirigami.Units.largeSpacing
            // rows are right-aligned within the pills' own width
            x: plateEnd - implicitWidth
            // the first row on the line, the next under it
            y: (secondLine.lineHeight - rowHeight) / 2
            // from the room beside the Weather Elements to the plates' end
            wrapWidth: plateEnd - (block.pillsLeftBound - block.viewX)
            weatherRoot: block.weatherRoot
            count: block.pillCount
            selectedDay: block.selectedDay
            onDayClicked: (index) => block.dayClicked(index)
            onDayStepped: (delta) => block.dayStepped(delta)
        }
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
