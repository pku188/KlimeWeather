/*
 * The header chrome shared by FullView and SimpleView: the pin in the top-left
 * corner, a button row in the top-right corner — zoom in and zoom out (graph layout
 * only), switch layout, refresh — and the header geometry both layouts place their
 * content by, so the icon, temperature, location and source sit in the same spots in
 * either layout.
 *
 * All of it is laid out for 24 px toolbar glyphs; a different Toolbar icon size
 * (Appearance → Common) moves the header with the buttons by the difference. So does
 * a location font too large for the buttons' line (see topDrop).
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Item {
    id: bar
    property real pad: 0
    property string switchTooltip: ""
    property string switchIcon: ""   // glyph for the layout switch: the layout it switches TO
    property bool showZoom: false   // graph layout only — see the first button
    property var root: null   // weatherRoot reference
    // Middle of the location line's capitals from that line's top (the view's
    // HeaderRightBlock.capCenter). The line is centred on the top buttons; see topDrop.
    property real lineCap: 0

    // The glyphs' size, and how far it is from the 24 px the geometry below is laid
    // out for.
    readonly property int iconSize: root ? root.toolbarIconSize : 24
    readonly property int iconGrowth: iconSize - 24
    // a button: its glyph and the 2 px hover plate around it
    readonly property int buttonSize: iconSize + 4
    // The highest the location may reach: where it starts with the default icons and
    // font, just above the view's top edge.
    readonly property int lineTopMin: -Math.round(Kirigami.Units.gridUnit / 6)
    // How far the buttons — and with them the whole header — go down to keep the
    // location below lineTopMin. It is centred on the buttons, so small icons beside a
    // large location font lifted the name out of the popup.
    readonly property int topDrop: Math.max(0, Math.round(lineTopMin + lineCap - (-4 + buttonSize / 2)))

    // ── Geometry, in the view's own coordinates ──────────────────────────────
    // How far the header content moves right to clear the pin, which grows to the
    // right with the icon size. Zero when the pin is hidden (desktop), so the header
    // keeps its original position there.
    readonly property int headerShift: pin.visible ? Math.round(Kirigami.Units.gridUnit * 1.2) + iconGrowth : 0
    // Top-left corner of the row holding the weather icon, temperature and Weather
    // Elements. Both views convert these into their own layout margins. It goes down
    // by half the icon growth, as the location's line does (it is centred on the top
    // buttons), so the location keeps its distance from the Weather Elements — and by
    // the whole topDrop, which moves the line down with the buttons.
    readonly property int heroRowX: Math.round(pad) - Math.round(Kirigami.Units.gridUnit * 0.6) + headerShift
    readonly property int heroDrop: Math.round(iconGrowth / 2) + topDrop
    readonly property int heroRowY: Math.round(Kirigami.Units.gridUnit * 1.2) + heroDrop
    // Extra space after the temperature, before the Weather Elements. The condition
    // under the temperature may run into it (see HeaderHero).
    readonly property int headerGap: Math.round(Kirigami.Units.gridUnit * 1)
    // Pull of the condition text up under the icon and temperature: the big
    // temperature line carries a deep descent below its digits. Not all the way up —
    // the icon's artwork reaches low on some conditions (a sun's rays), and the
    // condition reads as stuck to it without a little air in between.
    // And 4 px of that pull given back, so the condition never hugs the icon. A fixed
    // offset, the same in both layouts, rather than lining it up with the Weather
    // Elements: those differ in count and height between the layouts (a wind line
    // is a little taller), so anything tied to them would sit differently in each.
    readonly property int conditionPull: -Math.round(Kirigami.Units.gridUnit * 0.5) + 4
    // Vertical centre of the corner buttons' glyphs; the location sits on this line.
    readonly property real buttonCenterY: row.y + buttonSize / 2
    // Left edge the row has with all four buttons — the graph layout's zoom-in button —
    // whether or not the zoom buttons are shown. The location lines up with it in both
    // layouts, so it keeps its spot when the layout switches.
    readonly property real fullButtonsLeft: row.x + row.width - 4 * buttonSize - 3 * row.spacing
    // Bottom edge of the corner buttons.
    readonly property real buttonsBottom: row.y + buttonSize
    // Space between the first line — the location and the corner buttons, whichever
    // reaches lower — and the source button and day pills below it. 3 px more than
    // the 9 px the two lines first had between them, which read as cramped once the
    // pills could wrap under each other.
    readonly property int secondRowGap: Math.round(Kirigami.Units.gridUnit * 0.15) + 9
    // Gap between the right-hand block (source button) and the view's right edge.
    // Lines the text up with the outer edge of the rightmost button's glyph.
    readonly property int rightInset: Math.round(pad * 0.35) + 4

    // Spans the whole view so both corners can be anchored. It has no input handling
    // of its own, so presses, hover and wheel still reach the view underneath.
    anchors.fill: parent
    z: 10

    PinButton {
        id: pin
        // Level with the top buttons' glyphs: those buttons add a 2 px plate margin
        // around the same size of glyph the pin draws edge to edge.
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: row.anchors.topMargin + 2
        anchors.leftMargin: Math.round(bar.pad * 0.35)
        root: bar.root
        size: bar.iconSize
        // pinning is meaningless on the desktop (the widget is always shown) — only
        // the panel popup can be dismissed, so show the pin there only
        visible: !(root && root.planar)
    }

    Row {
        id: row
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -4 + bar.topDrop
        anchors.rightMargin: Math.round(bar.pad * 0.35)
        spacing: 2

        // Graph zoom, 12 / 24 / 48 hours — meaningless in the card layout, so these only
        // appear on the graph. Leftmost, so the layout switch and refresh sit in the
        // same spots in both layouts. At either end of the range the button that would
        // go further is disabled: no hover plate, no tooltip, dimmed.
        ToolbarButton {
            visible: bar.showZoom
            glyphSize: bar.iconSize
            iconName: "zoom-in"
            enabled: bar.root && bar.root.graphZoom > 0
            disabledOpacity: 0.5
            onClicked: if (bar.root) bar.root.zoomGraphIn()
            ToolTip.text: (bar.root && bar.root.graphZoom === 2) ? i18n("Zoom in to 24 hours")
                                                                 : i18n("Zoom in to 12 hours")
        }
        ToolbarButton {
            visible: bar.showZoom
            glyphSize: bar.iconSize
            iconName: "zoom-out"
            enabled: bar.root && bar.root.graphZoom < 2
            disabledOpacity: 0.5
            onClicked: if (bar.root) bar.root.zoomGraphOut()
            ToolTip.text: (bar.root && bar.root.graphZoom === 0) ? i18n("Zoom out to 24 hours")
                                                                 : i18n("Zoom out to 48 hours")
        }
        ToolbarButton {
            glyphSize: bar.iconSize
            iconName: bar.switchIcon
            onClicked: if (bar.root) bar.root.toggleLayout()
            ToolTip.text: bar.switchTooltip
        }
        ToolbarButton {
            glyphSize: bar.iconSize
            iconName: "refresh"
            enabled: bar.root && !bar.root.loading
            onClicked: if (bar.root) bar.root.fetchWeather()
            ToolTip.text: i18n("Refresh")
        }
    }
}
