/*
 * The elements not in a settings page's list (an ElementsModel), by name, seven
 * entries tall whatever their number, and under them the button that adds the picked
 * one — at the end of the list, shown. A double click adds one too.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: addList
    property ElementsModel elements: null
    property string buttonText: ""
    property string emptyText: ""

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    // An entry, never shown: what one is tall. Measured on one that isn't in the list,
    // so neither the count nor the last entry changes the list's height.
    ItemDelegate {
        id: rowProbe
        opacity: 0
        enabled: false
        bottomPadding: Kirigami.Units.smallSpacing
        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            ElementIcon { elementId: "temp" }
            Label { text: "Xg" }
        }
    }

    Connections {
        target: addList.elements
        function onSynced() { list.currentIndex = -1; }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        ScrollView {
            id: scroll
            Layout.preferredWidth: Kirigami.Units.gridUnit * 13
            Layout.preferredHeight: rowProbe.implicitHeight * 7 + topPadding + bottomPadding
            Component.onCompleted: if (background) background.visible = true
            ListView {
                id: list
                clip: true
                currentIndex: -1
                model: addList.elements ? addList.elements.available : []
                delegate: ItemDelegate {
                    id: entry
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    // the style pads the last entry of a list more at the bottom; here
                    // they are all alike, seven to the list
                    bottomPadding: Kirigami.Units.smallSpacing
                    highlighted: ListView.isCurrentItem
                    onClicked: list.currentIndex = index
                    onDoubleClicked: addList.elements.add(modelData.id)
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        ElementIcon { elementId: entry.modelData.id }
                        Label {
                            Layout.fillWidth: true
                            text: entry.modelData.text
                            elide: Text.ElideRight
                        }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.largeSpacing * 2
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: addList.emptyText
                    opacity: 0.6
                }
            }
        }
        Button {
            Layout.alignment: Qt.AlignRight
            text: addList.buttonText
            icon.name: "list-add"
            enabled: !!addList.elements && list.currentIndex >= 0
                     && list.currentIndex < addList.elements.available.length
            onClicked: addList.elements.add(addList.elements.available[list.currentIndex].id)
        }
    }
}
