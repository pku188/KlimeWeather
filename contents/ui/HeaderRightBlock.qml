/*
 * The right-hand side of the popup header, shared by both layouts: the location (a
 * button that opens the location settings) level with the toolbar buttons, and under
 * it the day pills and the weather-source button.
 *
 * The location starts where the day pills start. A name too long to fit before the
 * toolbar buttons does not run into them: it moves left instead, into the free space
 * above the pills and the Weather Elements, and only elides once it would reach the
 * temperature (`leftBound`).
 *
 * The card layout has no day pills, so it passes pillsShown: false and keeps them as
 * an invisible, disabled placeholder. The location and source button then take
 * exactly the spots they have in the graph layout.
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
    property int locationFontSize: 26
    property int providerFontSize: 16
    property bool pillsShown: true
    property int pillCount: 0
    property int selectedDay: -1
    signal dayClicked(int index)
    signal dayStepped(int delta)

    // Middle of the location's capitals from the block's top; the view aligns the
    // block so this sits level with the toolbar buttons.
    readonly property real capCenter: locationLine.y + locationButton.capCenter

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
        readonly property real pillsLeft: sourceRow.x + pills.x
        readonly property real rightLimit: (block.toolbar ? block.toolbar.buttonsLeft : viewX + width)
                                           - Kirigami.Units.largeSpacing - Kirigami.Units.smallSpacing - viewX
        readonly property real leftLimit: block.leftBound - viewX

        LocationButton {
            id: locationButton
            width: Math.min(implicitWidth, Math.max(0, locationLine.rightLimit - locationLine.leftLimit))
            height: implicitHeight
            x: Math.max(locationLine.leftLimit, Math.min(locationLine.pillsLeft, locationLine.rightLimit - width))
            root: block.weatherRoot
            fontSize: block.locationFontSize
        }
    }

    RowLayout {
        id: sourceRow
        Layout.alignment: Qt.AlignRight
        Layout.topMargin: block.toolbar ? block.toolbar.sourceRowGap : 0
        // may shrink in a narrow popup, where the source name elides
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth
        // the source name's end lines up with the block's edge; its plate reaches past
        Layout.rightMargin: -sourceButton.sidePad
        spacing: Kirigami.Units.largeSpacing

        DayPills {
            id: pills
            Layout.alignment: Qt.AlignVCenter
            // As a placeholder (card layout) it gives up its room first in a narrow
            // popup, before the source name has to elide.
            Layout.fillWidth: !block.pillsShown
            Layout.minimumWidth: block.pillsShown ? implicitWidth : 0
            Layout.maximumWidth: implicitWidth
            weatherRoot: block.weatherRoot
            count: block.pillCount
            selectedDay: block.selectedDay
            opacity: block.pillsShown ? 1 : 0
            enabled: block.pillsShown
            onDayClicked: (index) => block.dayClicked(index)
            onDayStepped: (delta) => block.dayStepped(delta)
        }
        ProviderButton {
            id: sourceButton
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            Layout.minimumWidth: block.pillsShown ? 0 : implicitWidth
            root: block.weatherRoot
            fontSize: block.providerFontSize
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
