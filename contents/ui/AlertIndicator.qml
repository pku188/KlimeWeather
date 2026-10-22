/*
 * Severe-weather alert indicator — a severity-coloured warning mark (its own SVG,
 * contents/icons/alert.svg) shown left of the location in the header when the alert
 * feed has an active alert, as large as the toolbar's icons (Appearance → Common →
 * Toolbar icon size). Hover shows the full alert headline + description: its text
 * selectable (and copied as it is selected, for a middle-click paste), its web
 * addresses links that open in the browser.
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: indicator

    property var weatherRoot
    readonly property var alert: weatherRoot ? weatherRoot.topAlert : null
    // the toolbar glyphs' size
    property int size: weatherRoot ? weatherRoot.toolbarIconSize : 24

    visible: weatherRoot && weatherRoot.showAlerts && alert !== null
    source: Qt.resolvedUrl("../icons/alert.svg")
    isMask: true
    color: alert ? weatherRoot.alertColor(alert.severity) : "transparent"
    roundToIconSize: false   // the exact toolbar size, not snapped to 16/22/32
    implicitWidth: size
    implicitHeight: size

    HoverHandler { id: hov }

    // Hovering the icon OR the tooltip keeps it up (so a tooltip that lands over
    // the small icon doesn't steal the hover and flicker). Visibility is driven
    // imperatively with two timers: a short SHOW delay, and a small HIDE grace so
    // the instant with neither hovered — crossing the gap from the icon onto the
    // tooltip — doesn't blink it off.
    readonly property bool _wantTip: (hov.hovered || tipHov.hovered) && indicator.alert !== null
    on_WantTipChanged: {
        if (_wantTip) { hideTimer.stop(); showTimer.restart(); }
        else          { showTimer.stop(); hideTimer.restart(); }
    }
    Timer { id: showTimer; interval: 150; onTriggered: tip.visible = true }
    Timer { id: hideTimer; interval: 130; onTriggered: tip.visible = false }

    // The alert's text as rich text: the rest escaped, the line breaks kept, and each
    // web address a link (the punctuation that ends a sentence after one left out).
    function _richDetail(t) {
        var esc = String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        esc = esc.replace(/(https?:\/\/[^\s<>"]*[^\s<>".,;:!?)\]'])/g, '<a href="$1">$1</a>');
        return esc.replace(/\n/g, "<br>");
    }
    readonly property string _detail: weatherRoot ? weatherRoot.alertDetail() : ""

    ToolTip {
        id: tip
        parent: indicator
        delay: 0   // timing is handled by the timers above
        // The popup sizes itself to the content's IMPLICIT size, so cap the wrapper:
        // width caps the wrap, height caps the box — a long alert scrolls inside the
        // ScrollView (wheel works because the pointer is over the hovered tooltip)
        // instead of running off-screen.
        contentItem: Item {
            implicitWidth: Math.min(measure.implicitWidth, Kirigami.Units.gridUnit * 19)
            implicitHeight: Math.min(tipText.implicitHeight, Kirigami.Units.gridUnit * 22)
            HoverHandler { id: tipHov }
            // the text's width on one line, which the wrapped text below can't tell
            Label {
                id: measure
                visible: false
                text: indicator._detail
                font: tipText.font
            }
            ScrollView {
                id: tipScroll
                anchors.fill: parent
                contentWidth: availableWidth   // vertical scroll only
                // Selectable, unlike a Label. Long addresses break anywhere rather than
                // run out of the box.
                TextEdit {
                    id: tipText
                    width: tipScroll.availableWidth
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.RichText
                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                    text: indicator._richDetail(indicator._detail)
                    font: tip.font
                    color: tip.palette.toolTipText
                    selectionColor: tip.palette.highlight
                    selectedTextColor: tip.palette.highlightedText
                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                    HoverHandler { cursorShape: tipText.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
                }
            }
        }
    }
}
