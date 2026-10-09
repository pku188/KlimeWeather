/*
 * The header chrome shared by FullView and SimpleView: the pin in the top-left
 * corner, the buttons in the top-right corner — switch layout and refresh, and under
 * them zoom in and zoom out (graph layout only), on one line with the day pills — and
 * the header geometry both layouts place their content by, so the icon, temperature
 * and location sit in the same spots in either layout.
 *
 * All of it is laid out for 24 px toolbar glyphs; a different Toolbar icon size
 * (Appearance → Common) moves the header with the buttons by the difference. So does
 * location or source text too tall for the top buttons' line (see topDrop).
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
    property bool showZoom: false   // graph layout only — see the zoom buttons
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
    // The highest the location line may reach: where its tallest button (the source)
    // starts with the default icons and fonts, just above the view's top edge.
    readonly property int lineTopMin: -Math.round(Kirigami.Units.gridUnit / 3)
    // How far the top buttons — and with them the whole header — go down to keep the
    // location line below lineTopMin. The line is centred on the buttons, so small
    // icons beside large location or source text lifted the text out of the popup
    // (the MET Norway logo first, the tallest of them).
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
    // Vertical centre of the top buttons' glyphs; the location sits on this line.
    readonly property real buttonCenterY: topRow.y + buttonSize / 2
    // Left edge of the top buttons. The same in both layouts — the zoom buttons sit
    // under them, not beside them — so the location and source line up with it and
    // keep their spot when the layout switches.
    readonly property real buttonsLeft: topRow.x
    // The line the graph's zoom buttons and day pills share, under the top buttons:
    // halfway between where the zoom buttons (a row right under the top buttons) and
    // the pills (just under those) sat when each had a line of its own.
    readonly property int pillRowHeight: Math.round(Kirigami.Units.gridUnit * 1.7)
    readonly property real stripCenterY: {
        var zoomTop = topRow.y + buttonSize + topRow.spacing;
        var zoomMid = zoomTop + buttonSize / 2;
        var pillsMid = zoomTop + buttonSize + Kirigami.Units.smallSpacing + pillRowHeight / 2;
        return Math.round((zoomMid + pillsMid) / 2);
    }
    // Left edge of the zoom buttons; the day pills end left of it.
    readonly property real zoomLeft: zoomRow.x
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
        anchors.topMargin: topRow.anchors.topMargin + 2
        anchors.leftMargin: Math.round(bar.pad * 0.35)
        root: bar.root
        size: bar.iconSize
        // pinning is meaningless on the desktop (the widget is always shown) — only
        // the panel popup can be dismissed, so show the pin there only
        visible: !(root && root.planar)
    }

    // Layout switch and refresh, in the same spots in both layouts.
    Row {
        id: topRow
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -4 + bar.topDrop
        anchors.rightMargin: Math.round(bar.pad * 0.35)
        spacing: 2

        ToolbarButton {
            glyphSize: bar.iconSize
            iconName: bar.switchIcon
            onClicked: if (bar.root) bar.root.toggleLayout()
            ToolTip.text: bar.switchTooltip
        }
        ToolbarButton {
            id: refreshButton
            glyphSize: bar.iconSize
            iconName: "refresh"
            enabled: bar.root && !bar.root.loading
            onClicked: if (bar.root) bar.root.fetchWeather()
            ToolTip.text: i18n("Refresh")
        }
    }

    // Graph zoom, 12 / 24 / 48 hours — meaningless in the card layout, so these only
    // appear on the graph: under the buttons above, on the day pills' line. At either
    // end of the range the button that would go further is disabled: no hover plate,
    // no tooltip, dimmed.
    Row {
        id: zoomRow
        visible: bar.showZoom
        anchors.right: parent.right
        anchors.rightMargin: topRow.anchors.rightMargin
        y: Math.round(bar.stripCenterY - height / 2)
        spacing: topRow.spacing

        ToolbarButton {
            glyphSize: bar.iconSize
            iconName: "zoom-in"
            enabled: bar.root && bar.root.graphZoom > 0
            disabledOpacity: 0.5
            onClicked: if (bar.root) bar.root.zoomGraphIn()
            ToolTip.text: (bar.root && bar.root.graphZoom === 2) ? i18n("Zoom in to 24 hours")
                                                                 : i18n("Zoom in to 12 hours")
        }
        ToolbarButton {
            glyphSize: bar.iconSize
            iconName: "zoom-out"
            enabled: bar.root && bar.root.graphZoom < 2
            disabledOpacity: 0.5
            onClicked: if (bar.root) bar.root.zoomGraphOut()
            ToolTip.text: (bar.root && bar.root.graphZoom === 0) ? i18n("Zoom out to 24 hours")
                                                                 : i18n("Zoom out to 48 hours")
        }
    }
}
