/*
 * A row of pill buttons — the day buttons (DayPills) and the layout buttons under
 * them (HeaderRightBlock). Tapping one picks it; the mouse wheel over them steps one
 * along per notch, down = the next.
 *
 * Each pill is sized for its label in BOLD whether or not it is selected, so selecting
 * one never changes a row's width — the rows would otherwise shift a few pixels with
 * every selection.
 *
 * Pills that run past `wrapWidth` wrap onto a new row, the way right-aligned text
 * wraps on a web page: each row is filled in order, as many pills as fit, and every
 * row ends at the right edge. A narrow popup then shows them all on two rows instead
 * of cutting the last ones off.
 *
 * A pill can be an arrow instead of a label (`icons`), round, and greyed out
 * (`disabled`), when it then takes no clicks. A pill can also carry a second line under
 * its label (`subLabels`), smaller and dimmed, as the Daily forecast's tabs show their
 * dates; the row is then two lines high.
 *
 * Where each pill goes is worked out from the labels (`placement`), not from the
 * pills once they are built, so no frame shows them with new labels in old places:
 * placed a moment later, a narrowing popup's first frame at its new width drew the
 * pills over each other.

 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "wheel.js" as Wheel

Item {
    id: pills
    property var labels: []
    property int selectedIndex: -1
    property int fontPx: Kirigami.Theme.defaultFont.pixelSize + 2
    // The widest a row may grow before the next pill wraps; 0 keeps them on one row.
    property real wrapWidth: 0
    // A second line under each pill's label, "" for none: smaller and dimmed (the day
    // buttons' dates past five days).
    property var subLabels: []
    // An icon drawn instead of each pill's label, "" for none (the day buttons'
    // arrows), and whether each pill is greyed out.
    property var icons: []
    property var disabled: []
    signal picked(int index)
    signal stepped(int delta)

    readonly property int spacing: Kirigami.Units.smallSpacing
    // A one-line pill's height; it grows with a large font.
    readonly property int lineHeight: Math.max(Math.round(Kirigami.Units.gridUnit * 1.7), Math.round(fontPx * 1.9))
    // Whether any pill has a second line, and a pill's height, which is a row's height
    // too: one line's, with the second line's under it (pulled up a little, as under
    // the Daily forecast's tab names).
    readonly property bool twoLines: subLabels.some(function (s) { return !!s; })
    readonly property int subPull: Math.round(Kirigami.Units.smallSpacing / 2)
    readonly property int twoLineHeight: lineHeight + Math.ceil(subFont.height) - subPull
    readonly property int rowHeight: twoLines ? twoLineHeight : lineHeight
    // How much taller a row of these pills is with a second line than without, and
    // how much of that they lack now: room a view can keep for it, so it doesn't
    // change size when the pills get their dates (past five days).
    readonly property int secondLineHeight: twoLineHeight - lineHeight
    readonly property int secondLineRoom: twoLines ? 0 : secondLineHeight
    // How far a pill's plate reaches past its label on either side.
    readonly property int sidePad: Math.round(Kirigami.Units.gridUnit * 1.1 / 2)
    readonly property int iconPx: Math.round(fontPx * 1.1)

    // The pills' font in bold, which they are measured in: from a Label, so it is
    // theirs exactly.
    Label {
        id: boldProbe
        visible: false
        font.pixelSize: pills.fontPx
        font.bold: true
    }
    FontMetrics {
        id: boldFont
        font: boldProbe.font
    }
    // The second line's font: a step smaller than the label, as the Daily forecast
    // tabs' date is under the day's name.
    readonly property int subFontPx: Math.round(fontPx * 5 / 6)
    Label {
        id: subProbe
        visible: false
        font.pixelSize: pills.subFontPx
    }
    FontMetrics {
        id: subFont
        font: subProbe.font
    }
    // A pill's width: an icon's as wide as a line is high (round on one line).
    function pillWidth(label, sub, icon) {
        if (icon) return lineHeight;
        var w = boldFont.advanceWidth(String(label));
        if (sub) w = Math.max(w, subFont.advanceWidth(String(sub)));
        return Math.ceil(w) + sidePad * 2;
    }

    readonly property var pillWidths: {
        var _font = fontPx;   // measured in it: a new size measures again
        return labels.map(function (l, i) { return pills.pillWidth(l, pills.subLabels[i], pills.icons[i]); });
    }

    // While set, the row is at least this wide, with its first pill at the left edge:
    // holdWidth() keeps a pill the pointer is on where it is while the pills change
    // under it, until the pointer leaves the row.
    // Let go at once by releaseHold(), and whenever the pills are other pills (how many
    // there are) or the room changes: held on, the first pill would stand apart from
    // pills that no longer hold their old widths.
    property real _heldWidth: 0
    function holdWidth() { _heldWidth = implicitWidth; }
    function releaseHold() { _heldWidth = 0; }
    readonly property int _count: labels.length
    on_CountChanged: releaseHold()
    onWrapWidthChanged: releaseHold()
    HoverHandler {
        onHoveredChanged: if (!hovered) pills.releaseHold()
    }

    // Where the pills go: rows filled in order, as many pills as fit, each row
    // right-aligned. { xs, ys } per pill, the width and the rows.
    readonly property var placement: {
        var rowsOut = [], row = [], rowW = 0, i;
        for (i = 0; i < pillWidths.length; ++i) {
            var pw = pillWidths[i], w = row.length ? rowW + spacing + pw : pw;
            if (row.length && wrapWidth > 0 && w > wrapWidth) {
                rowsOut.push({ items: row, width: rowW });
                row = [i];
                rowW = pw;
            } else {
                row.push(i);
                rowW = w;
            }
        }
        if (row.length) rowsOut.push({ items: row, width: rowW });
        var widest = 0, xs = [], ys = [];
        for (i = 0; i < rowsOut.length; ++i) widest = Math.max(widest, rowsOut[i].width);
        // a held width (one row only): the room it leaves goes after the first pill
        var held = rowsOut.length === 1 && _heldWidth > widest ? _heldWidth - widest : 0;
        widest += held;
        for (i = 0; i < rowsOut.length; ++i) {
            var x = widest - rowsOut[i].width - held;
            for (var j = 0; j < rowsOut[i].items.length; ++j) {
                var k = rowsOut[i].items[j];
                xs[k] = x;
                ys[k] = i * (rowHeight + spacing);
                x += pillWidths[k] + spacing + (j === 0 ? held : 0);
            }
        }
        return { xs: xs, ys: ys, width: widest, rows: rowsOut.length };
    }
    // How many rows the pills take at the current wrapWidth.
    readonly property int rows: placement.rows
    implicitWidth: placement.width
    implicitHeight: rows > 0 ? rows * rowHeight + (rows - 1) * spacing : 0

    // Deltas accumulate, so a touchpad's many small ticks add up to one step rather
    // than firing a step per tick (see wheel.js).
    WheelHandler {
        id: pillsWheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: (wheel) => {
            wheel.accepted = true;
            var ad = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            var dir = Wheel.step(pillsWheel, ad);
            if (dir !== 0) pills.stepped(dir);
        }
    }

    Repeater {
        // by count: new labels (a day's name at midnight) take over in the pills there
        model: pills.labels.length
        delegate: Rectangle {
            id: pill
            required property int index
            readonly property bool selected: index === pills.selectedIndex
            readonly property string icon: pills.icons[index] ? String(pills.icons[index]) : ""
            readonly property bool off: pills.disabled[index] === true
            x: pills.placement.xs[index] || 0
            y: pills.placement.ys[index] || 0
            width: pills.pillWidths[index] || 0
            height: pills.rowHeight
            // round ends on one line; on two, corners as round as a one-line pill's
            radius: pills.lineHeight / 2
            color: selected
                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.16)
                : (pillHover.hovered && !off ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.08) : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }
            HoverHandler { id: pillHover }
            TapHandler {
                enabled: !pill.off
                onTapped: pills.picked(pill.index)
            }
            // the label, and its second line under it
            Column {
                visible: pill.icon === ""
                anchors.centerIn: parent
                spacing: -pills.subPull
                opacity: pill.off ? 0.3 : 1
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(pills.labels[pill.index])
                    font.bold: pill.selected
                    font.pixelSize: pills.fontPx
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: text !== ""
                    text: pills.subLabels[pill.index] ? String(pills.subLabels[pill.index]) : ""
                    font.pixelSize: pills.subFontPx
                    opacity: 0.55
                }
            }
            Kirigami.Icon {
                visible: pill.icon !== ""
                anchors.centerIn: parent
                width: pills.iconPx
                height: width
                source: pill.icon
                isMask: true
                color: Kirigami.Theme.textColor
                opacity: pill.off ? 0.3 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }
}
