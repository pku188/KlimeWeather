/*
 * The popup's animated condition icons, one per picture: every ConditionIcon that
 * shows the same SVG at the same size (and tint) shares one ConditionIconShared.
 * A week of hourly cards holds only a handful of different conditions, so this
 * keeps the animations to that handful, and a recycled graph slot switches to
 * another condition at once — no rebuild, and no frame of the old picture.
 *
 * Lives in the full representation (main.qml), which hands it to root.iconCache.
 * An icon nobody shows any more is dropped after a quiet spell, so a scroll that
 * passes a condition doesn't build it twice.
 *
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Item {
    id: cache
    visible: false   // its icons are only ever drawn through their textures

    property var _entries: ({})

    function key(svg, px, tinted) {
        return svg + "|" + px + (tinted ? "|tinted" : "");
    }
    // the shared icon for `k`, or null when nobody has built it yet
    function find(k) {
        return _entries[k] || null;
    }
    function create(k, svg, px, tinted) {
        var h = holder.createObject(cache, { key: k, svg: svg, width: px, height: px, tinted: tinted });
        _entries[k] = h;
        return h;
    }
    function attach(h, user) {
        if (h.users.indexOf(user) < 0) h.users.push(user);
        refresh(h);
    }
    function detach(h, user) {
        var i = h.users.indexOf(user);
        if (i >= 0) h.users.splice(i, 1);
        refresh(h);
        if (h.users.length === 0) sweep.restart();
    }
    // a shared icon moves while any of its users would
    function refresh(h) {
        var play = false;
        for (var i = 0; i < h.users.length && !play; ++i)
            play = h.users[i].wantsToPlay;
        h.playing = play;
    }

    Component {
        id: holder
        ConditionIconShared {}
    }
    Timer {
        id: sweep
        interval: 10000
        onTriggered: {
            for (var k in cache._entries) {
                var h = cache._entries[k];
                if (h.users.length === 0) {
                    delete cache._entries[k];
                    h.destroy();
                }
            }
        }
    }
}
