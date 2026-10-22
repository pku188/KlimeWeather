/*
 * A settings page's editable list of elements — the Panel Elements, the Detailed view
 * Elements — mirrored from its cfg_ JSON (`json`) into a ListModel the rows show, with
 * the ones not in it listed by name to add from. Every change is handed back as JSON
 * (`edited`), which the page stores in its cfg_ key.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Item {
    id: elements
    visible: false

    // every element there is, the stored JSON → [{ id, shown }] and back, and a name
    // for each id
    property var allIds: []
    property var parse: function (json) { return []; }
    property var stringify: function (list) { return JSON.stringify(list); }
    property var nameOf: function (id) { return id; }
    property string json: ""
    signal edited(string json)
    // the list was taken from json again: the add list drops its selection
    signal synced()

    readonly property alias model: listModel   // { elementId, shown }, in order
    // the elements not in the list, by name: [{ id, text }]
    property var available: []
    // the ids shown, in order
    property var shownIds: []

    // Dragging a row: where it came from and where it would land; the rows between
    // make room for it (see ElementRows).
    property int dragFrom: -1
    property int dragTo: -1
    property real dragPitch: 0
    property bool rowsAnimate: false

    ListModel { id: listModel }

    function _list() {
        var out = [];
        for (var i = 0; i < listModel.count; ++i)
            out.push({ id: listModel.get(i).elementId, shown: listModel.get(i).shown });
        return out;
    }
    // The model from json — rebuilt only when that says something else, so a change
    // made here doesn't recreate the rows — and the lists that follow it.
    function sync() {
        var list = parse(json);
        if (stringify(list) !== stringify(_list())) {
            listModel.clear();
            for (var i = 0; i < list.length; ++i)
                listModel.append({ elementId: list[i].id, shown: list[i].shown });
        }
        var on = {};
        list.forEach(function (el) { on[el.id] = true; });
        shownIds = list.filter(function (el) { return el.shown; }).map(function (el) { return el.id; });
        var avail = allIds.filter(function (id) { return !on[id]; })
                          .map(function (id) { return { id: id, text: elements.nameOf(id) }; });
        avail.sort(function (a, b) { return a.text.localeCompare(b.text); });
        available = avail;
        synced();
    }
    onJsonChanged: sync()
    Component.onCompleted: sync()
    function _store() {
        edited(stringify(_list()));
        sync();
    }
    function toggle(i) {
        listModel.setProperty(i, "shown", !listModel.get(i).shown);
        _store();
    }
    function remove(i) {
        listModel.remove(i);
        _store();
    }
    // a new element goes at the end of the list, shown
    function add(id) {
        listModel.append({ elementId: id, shown: true });
        _store();
    }
    function move(from, to) {
        listModel.move(from, to, 1);
        _store();
    }
}
