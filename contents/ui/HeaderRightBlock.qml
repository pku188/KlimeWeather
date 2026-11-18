/*
 * The right-hand side of the popup header, shared by the three layouts, in three lines:
 * the weather alert mark while there is an alert, the location (a button that opens
 * the location settings) and the weather source, level with the refresh button; under
 * them the layout buttons — Forecast, Graph, Details; and under those the day pills.
 *
 * The source ends before the top-right buttons (the view's own and refresh, see
 * WeatherToolbar), and the location before the source, by about the same gap (the
 * source a little nearer the buttons), and the alert mark under half that before the
 * location — in every layout (WeatherToolbar.buttonsLeft). A longer name grows to the
 * left, over the free space above the Weather Elements, and only elides once it would
 * reach the temperature (`leftBound`); a name too long for the room beside a full
 * source makes the source shorten to its logo first.
 *
 * The layout buttons and the day pills end level with the refresh button's plate,
 * and wrap onto a second row when the room between the Weather Elements
 * (`pillsLeftBound`) and that edge is too narrow for one. The layout buttons, short
 * names on purpose ("Forecast", "Graph", "Details"; the settings' tabs have the long
 * ones), are on the same line in every layout. The Daily
 * forecast has no day pills (pillsShown: false); the Weather graph and the Detailed
 * view take them out too (pillsInBlock: false) when even two rows are not enough —
 * or, past five days, when their sliding window doesn't fit on one — and show them on
 * a row of their own under the header instead.
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
    // the x the day pills and the layout buttons must stay right of (the Weather
    // Elements' right edge), in the view's coordinates too
    property real pillsLeftBound: 0
    property int locationFontSize: 26
    property int providerFontSize: 16
    property bool pillsShown: true
    property bool pillsInBlock: true
    // Keep room under the day pills for the dates they show past five days, also when
    // they show none (the graph layout: see SimpleView's plotH).
    property bool pillsKeepSecondLine: false
    // how much taller the pills' row is with their dates
    readonly property int pillsSecondLineHeight: pills.secondLineHeight
    property int pillCount: 0
    property int selectedDay: -1
    signal dayClicked(int index)
    signal dayStepped(int delta)

    // Middle of the location's capitals from the block's top; the view aligns the
    // block so this sits level with the toolbar buttons.
    readonly property real capCenter: locationLine.y + locationButton.capCenter
    // How far the pills' plates end past where the names end (nameEnd): the graph's
    // row of pills under the header ends this far past the block, level with the
    // pills in it.
    readonly property real pillsOverhang: plateEnd - nameEnd
    // Whether the day pills fit beside the Weather Elements: on at most two rows, or
    // past five days on one (see DayPills). The Weather graph and the Detailed view
    // move them under the header where they don't.
    readonly property bool pillsFit: pills.fitsBeside

    // The block's left edge in the view's coordinates. Everything in it is placed by
    // hand from the view and may extend past that edge, so nothing widens the block.
    readonly property real viewX: originX + x
    // The block's top in the view's coordinates: the views put capCenter on the
    // toolbar's buttonCenterY.
    readonly property real viewY: toolbar ? toolbar.buttonCenterY - capCenter : 0
    // In the block's coordinates, where the source's name ends: level with the outer
    // edge of the refresh glyph.
    readonly property real nameEnd: (toolbar ? toolbar.width - toolbar.rightInset : viewX + width) - viewX
    // where the pills' and the layout buttons' plates end: level with the refresh
    // button's plate
    readonly property real plateEnd: toolbar ? toolbar.buttonsRight - viewX : nameEnd

    spacing: 0

    Item {
        id: locationLine
        Layout.fillWidth: true
        implicitWidth: 0
        implicitHeight: locationButton.implicitHeight

        // All in this item's coordinates (it starts at the block's left edge).
        // Air between a name and what follows it: a pill's and the source's side
        // padding and a row's spacings.
        readonly property real gap: sourceButton.sidePad * 2 + Kirigami.Units.largeSpacing
                                    + Kirigami.Units.smallSpacing
        // the refresh button's glyph starts 2 px into the button (its hover plate)
        readonly property real glyphLeft: (block.toolbar ? block.toolbar.buttonsLeft + 2 : block.viewX + width)
                                          - block.viewX
        readonly property real leftLimit: block.leftBound - block.viewX
        // the alert mark's gap before the location — half the gap, less 4 px — and the
        // room it takes, gap included
        readonly property real alertGap: Math.round(gap / 2) - 4
        readonly property real alertRoom: alertMark.visible ? alertMark.width + alertGap : 0
        // where the source's name ends — a little nearer the refresh button than the
        // gap — and where it starts at its full width
        readonly property real sourceNameEnd: glyphLeft - gap + Kirigami.Units.smallSpacing
        readonly property real fullSourceNameStart: sourceNameEnd - (sourceButton.implicitWidth - sourceButton.sidePad * 2)

        ProviderButton {
            id: sourceButton
            // the logo alone when a full source leaves the location less than its name
            readonly property bool logoOnly: locationLine.fullSourceNameStart - locationLine.gap
                                             - locationLine.leftLimit - locationLine.alertRoom < locationButton.implicitWidth
            width: logoOnly ? logoOnlyWidth : implicitWidth
            height: implicitHeight
            x: locationLine.sourceNameEnd + sidePad - width
            // centred on the location's capitals, the line the toolbar buttons are on
            y: Math.round(locationButton.capCenter - height / 2)
            root: block.weatherRoot
            fontSize: block.providerFontSize
        }

        LocationButton {
            id: locationButton
            readonly property real rightLimit: sourceButton.x + sourceButton.sidePad - locationLine.gap
            width: Math.min(implicitWidth, Math.max(0, rightLimit - locationLine.leftLimit - locationLine.alertRoom))
            height: implicitHeight
            x: rightLimit - width
            root: block.weatherRoot
            fontSize: block.locationFontSize
        }

        // the weather alert, alertGap before the location, centred on its capitals as the
        // toolbar buttons are
        AlertIndicator {
            id: alertMark
            weatherRoot: block.weatherRoot
            width: implicitWidth
            height: implicitHeight
            x: locationButton.x - locationLine.alertGap - width
            y: Math.round(locationButton.capCenter - height / 2)
        }
    }

    // The layout buttons, the same line in every layout: secondRowGap under whichever
    // reaches lower, the location or the refresh button (larger toolbar icons).
    Item {
        id: layoutLine
        Layout.fillWidth: true
        Layout.topMargin: (block.toolbar ? Math.max(0, block.toolbar.buttonsBottom
                                                       - (block.viewY + locationLine.implicitHeight))
                                           + block.toolbar.secondRowGap
                                         : Kirigami.Units.smallSpacing)
        implicitWidth: 0
        implicitHeight: layoutButtons.implicitHeight

        PillRow {
            id: layoutButtons
            readonly property var root: block.weatherRoot
            x: block.plateEnd - implicitWidth
            wrapWidth: block.plateEnd - (block.pillsLeftBound - block.viewX)
            // in the order of popupLayouts: the layouts' short names, which the buttons
            // always show (the long ones in a narrow popup wrapped, or swapped back and
            // forth with these)
            labels: [i18nc("the Daily forecast layout's button", "Forecast"),
                     i18nc("the Weather graph layout's button", "Graph"),
                     i18nc("the Detailed view layout's button", "Details")]
            selectedIndex: root ? root.popupLayouts.indexOf(root.popupLayout) : -1
            fontPx: root ? root.layoutButtonFontSize : Kirigami.Theme.defaultFont.pixelSize
            onPicked: (index) => { if (root) root.setLayout(root.popupLayouts[index]); }
            // and the wheel keeps switching them until the pointer moves (main.qml
            // layoutWheelHeld)
            onStepped: (delta) => { if (root) { root.layoutWheelHeld = true; root.stepLayout(delta); } }
        }
    }

    // The day pills, as far under the layout buttons as those are under the first
    // line. No room is kept without them: the layout buttons above stay where they are
    // either way. With pillsKeepSecondLine, room for their dates is kept under pills
    // that have none, so the block is as tall either way.
    Item {
        id: pillsLine
        readonly property bool shown: block.pillsShown && block.pillsInBlock
        Layout.fillWidth: true
        Layout.topMargin: shown ? (block.toolbar ? block.toolbar.secondRowGap : Kirigami.Units.smallSpacing) : 0
        implicitWidth: 0
        implicitHeight: shown ? Math.max(pills.rowHeight, pills.implicitHeight)
                                + (block.pillsKeepSecondLine ? pills.secondLineRoom : 0) : 0
        DayPills {
            id: pills
            visible: pillsLine.shown
            // rows are right-aligned within the pills' own width
            x: block.plateEnd - implicitWidth
            // from the room beside the Weather Elements to the plates' end
            wrapWidth: block.plateEnd - (block.pillsLeftBound - block.viewX)
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
