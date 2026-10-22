/*
 * A settings page's list of elements (an ElementsModel) as rows: drag handle, icon and
 * name, then show / hide and remove. A row drags up or down from anywhere on it; the
 * rows it passes make room, and it lands where it is let go. A hidden element stays in
 * the list, dimmed. A Repeater, not a ListView — the page already scrolls.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: rows
    property ElementsModel elements: null
    property var nameOf: function (id) { return id; }
    property string hideText: ""
    property string showText: ""
    // shown when no element is
    property string emptyText: ""

    spacing: Kirigami.Units.smallSpacing

    Repeater {
        model: rows.elements ? rows.elements.model : null
        delegate: Rectangle {
            id: elementRow
            required property int index
            required property string elementId
            required property bool shown
            readonly property bool dragged: rowDrag.active
            readonly property ElementsModel elements: rows.elements
            // making room for the dragged row: a row's height up or down
            readonly property real shift: {
                var f = elements.dragFrom, t = elements.dragTo;
                if (f < 0 || index === f) return 0;
                if (f < t && index > f && index <= t) return -elements.dragPitch;
                if (f > t && index < f && index >= t) return elements.dragPitch;
                return 0;
            }

            Layout.fillWidth: true
            implicitHeight: rowContent.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: 6
            z: dragged ? 1 : 0
            // the dragged row opaque, so the rows it passes don't show through
            color: dragged
                ? Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor,
                                                    Kirigami.Theme.highlightColor, 0.3)
                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, rowHover.hovered ? 0.10 : 0.05)
            Behavior on color { ColorAnimation { duration: 100 } }
            transform: Translate {
                y: elementRow.dragged ? rowDrag.activeTranslation.y : elementRow.shift
                Behavior on y {
                    enabled: elementRow.elements.rowsAnimate && elementRow.index !== elementRow.elements.dragFrom
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
            }

            RowLayout {
                id: rowContent
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: "drag-handle-symbolic"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    opacity: 0.6
                }
                // a hidden element's icon and name dimmed
                ElementIcon {
                    elementId: elementRow.elementId
                    opacity: elementRow.shown ? 1 : 0.4
                }
                Label {
                    Layout.fillWidth: true
                    text: rows.nameOf(elementRow.elementId)
                    elide: Text.ElideRight
                    opacity: elementRow.shown ? 1 : 0.5
                }
                ToolButton {
                    icon.name: elementRow.shown ? "view-visible-symbolic" : "view-hidden-symbolic"
                    onClicked: elementRow.elements.toggle(elementRow.index)
                    ToolTip.visible: hovered
                    ToolTip.text: elementRow.shown ? rows.hideText : rows.showText
                    HoverHandler { cursorShape: Qt.ArrowCursor }
                }
                ToolButton {
                    icon.name: "edit-delete"
                    onClicked: elementRow.elements.remove(elementRow.index)
                    ToolTip.visible: hovered
                    ToolTip.text: i18n("Remove")
                    HoverHandler { cursorShape: Qt.ArrowCursor }
                }
            }

            HoverHandler { id: rowHover; cursorShape: Qt.OpenHandCursor }
            DragHandler {
                id: rowDrag
                target: null
                xAxis.enabled: false
                cursorShape: Qt.ClosedHandCursor
                onActiveChanged: {
                    var els = elementRow.elements;
                    if (active) {
                        els.rowsAnimate = true;
                        els.dragPitch = elementRow.height + rows.spacing;
                        els.dragFrom = elementRow.index;
                        els.dragTo = elementRow.index;
                        return;
                    }
                    // dropped: everything takes its new place at once
                    var from = els.dragFrom, to = els.dragTo;
                    els.rowsAnimate = false;
                    els.dragFrom = -1;
                    els.dragTo = -1;
                    if (from >= 0 && to >= 0 && from !== to) els.move(from, to);
                }
                onActiveTranslationChanged: {
                    var els = elementRow.elements;
                    if (!active || els.dragPitch <= 0) return;
                    els.dragTo = Math.max(0, Math.min(els.model.count - 1,
                        elementRow.index + Math.round(activeTranslation.y / els.dragPitch)));
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: rows.emptyText.length > 0 && !!rows.elements && rows.elements.shownIds.length === 0
        wrapMode: Text.WordWrap
        text: rows.emptyText
        opacity: 0.6
    }
}
