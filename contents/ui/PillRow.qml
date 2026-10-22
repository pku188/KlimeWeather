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
    signal picked(int index)
    signal stepped(int delta)

    readonly property int spacing: Kirigami.Units.smallSpacing
    // A pill's height, which is a row's height too; it grows with a large font.
    readonly property int rowHeight: Math.max(Math.round(Kirigami.Units.gridUnit * 1.7), Math.round(fontPx * 1.9))
    // How far a pill's plate reaches past its label on either side.
    readonly property int sidePad: Math.round(Kirigami.Units.gridUnit * 1.1 / 2)

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
    function _pillWidth(label) { return Math.ceil(boldFont.advanceWidth(String(label))) + sidePad * 2; }

    readonly property var pillWidths: labels.map(function (l) { return pills._pillWidth(l); })

    // Where the pills go: rows filled in order, as many pills as fit, each row
    // right-aligned. { xs, ys } per pill, the widest row's width and the rows.
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
        for (i = 0; i < rowsOut.length; ++i) {
            var x = widest - rowsOut[i].width;
            for (var j = 0; j < rowsOut[i].items.length; ++j) {
                var k = rowsOut[i].items[j];
                xs[k] = x;
                ys[k] = i * (rowHeight + spacing);
                x += pillWidths[k] + spacing;
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
            x: pills.placement.xs[index] || 0
            y: pills.placement.ys[index] || 0
            width: pills.pillWidths[index] || 0
            height: pills.rowHeight
            radius: height / 2
            color: selected
                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.16)
                : (pillHover.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, 0.08) : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }
            HoverHandler { id: pillHover }
            TapHandler { onTapped: pills.picked(pill.index) }
            Label {
                anchors.centerIn: parent
                text: String(pills.labels[pill.index])
                font.bold: pill.selected
                font.pixelSize: pills.fontPx
            }
        }
    }
}
