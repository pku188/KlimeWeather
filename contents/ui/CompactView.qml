/*
 * Compact (panel/tray) representation: the Panel Elements (Appearance → Panel) shown,
 * in their order — by default the weather icon and the temperature.
 *
 * On a horizontal panel they sit on one line, as wide as they need. On a vertical one
 * they wrap: each goes on the line before when it fits beside what is there within
 * the panel's width, else on a new line, and every line is centred. Sizes are a % of
 * the panel's thickness either way — its height, or a vertical panel's width.
 *
 * The Element separator goes between every two elements but the weather icon and the
 * temperature, which stay together in either order: in the middle of the space
 * between them on a line, and on a vertical panel on a row of its own between lines.
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: compact

    property var weatherRoot

    readonly property bool vertical: !!weatherRoot && weatherRoot.panelVertical
    readonly property real thickness: vertical ? width : height
    readonly property int iconPx: Math.round(thickness * (weatherRoot ? weatherRoot.panelIconPercent : 130) / 100)
    readonly property int tempPx: Math.round(thickness * (weatherRoot ? weatherRoot.panelFontPercent : 72) / 100)
    readonly property int secondaryPx: Math.round(thickness * (weatherRoot ? weatherRoot.panelSecondaryPercent : 37) / 100)
    // Space between two elements on a line: none beside the weather icon, whose
    // artwork leaves the edges of its box empty, else a quarter of the panel's
    // thickness — and the Element spacing's pixels added (Appearance → Panel). A
    // separator gets half of that space on each side, the added pixels on both. A
    // vertical panel's lines are a tenth of its thickness apart, plus those pixels.
    // Nothing closer than touching.
    readonly property int gap: Math.round(thickness / 4)
    readonly property int spacing: weatherRoot ? weatherRoot.panelElementSpacing : 0
    readonly property string separator: weatherRoot ? weatherRoot.panelSeparator : ""
    readonly property int lineGap: Math.max(0, Math.round(thickness / 10) + spacing)
    function gapBetween(a, b) {
        return Math.max(0, (a.elementId === "icon" || b.elementId === "icon" ? 0 : gap) + spacing);
    }
    function gapBeside(el) {
        return Math.max(0, (el.elementId === "icon" ? 0 : Math.round(gap / 2)) + spacing);
    }

    // The elements shown, in order. With no location just the pin, which opens the
    // settings; with every element hidden the weather icon, so there is always
    // something to click.
    readonly property var shownIds: {
        if (!weatherRoot) return [];
        if (!weatherRoot.hasLocation) return ["icon"];
        var ids = weatherRoot.panelElements.filter(function (el) { return el.shown; })
                                           .map(function (el) { return el.id; });
        return ids.length > 0 ? ids : ["icon"];
    }

    // The panel gives the widget exactly what the elements take along the panel, so
    // nothing is clipped and nothing overlaps the neighbours; across it, the panel's
    // thickness.
    property real contentWidth: 0
    property real contentHeight: 0
    Layout.minimumWidth:    vertical ? 0 : contentWidth
    Layout.preferredWidth:  vertical ? -1 : contentWidth
    Layout.maximumWidth:    vertical ? Infinity : contentWidth
    Layout.minimumHeight:   vertical ? contentHeight : 0
    Layout.preferredHeight: vertical ? contentHeight : -1
    Layout.maximumHeight:   vertical ? contentHeight : Infinity

    MouseArea {
        anchors.fill: parent
        onClicked: if (weatherRoot) weatherRoot.expanded = !weatherRoot.expanded
    }

    Repeater {
        id: elements
        model: compact.shownIds
        delegate: PanelElement {
            required property string modelData
            weatherRoot: compact.weatherRoot
            elementId: modelData
            iconPx: compact.iconPx
            tempPx: compact.tempPx
            secondaryPx: compact.secondaryPx
            maxWidth: compact.vertical ? compact.width : Infinity
            onImplicitWidthChanged: compact.scheduleLayout()
            onImplicitHeightChanged: compact.scheduleLayout()
            onPresentChanged: compact.scheduleLayout()
        }
        onItemAdded: compact.scheduleLayout()
        onItemRemoved: compact.scheduleLayout()
    }
    // The separators, one for every gap there can be: the layout shows those it needs.
    // In the secondary font, so they scale with it.
    Repeater {
        id: separators
        model: compact.separator.length > 0 ? Math.max(0, compact.shownIds.length - 1) : 0
        delegate: Text {
            visible: false
            text: compact.separator
            color: Kirigami.Theme.textColor
            font.pixelSize: compact.secondaryPx
            font.weight: compact.weatherRoot ? compact.weatherRoot.panelSecondaryFontWeight : Font.Normal
            onImplicitWidthChanged: compact.scheduleLayout()
        }
        onItemAdded: compact.scheduleLayout()
        onItemRemoved: compact.scheduleLayout()
    }
    onWidthChanged: scheduleLayout()
    onHeightChanged: scheduleLayout()
    onGapChanged: scheduleLayout()
    onSpacingChanged: scheduleLayout()

    function scheduleLayout() { Qt.callLater(layoutElements) }
    // Places the elements and separators (see the top of the file) and sets the size
    // they take.
    function layoutElements() {
        var items = [], seps = [], i, it;
        for (i = 0; i < elements.count; ++i) {
            it = elements.itemAt(i);
            if (it && it.present) items.push(it);
        }
        for (i = 0; i < separators.count; ++i) {
            it = separators.itemAt(i);
            if (it) { it.visible = false; seps.push(it); }
        }
        var useSep = seps.length > 0;
        var sepW = useSep ? seps[0].implicitWidth : 0, sepH = useSep ? seps[0].implicitHeight : 0;
        var nextSep = 0;
        function placeSep(x, y) {
            var sep = seps[nextSep++];
            if (!sep) return;
            sep.x = x;
            sep.y = y;
            sep.visible = true;
        }
        // whether a separator goes between two neighbours: not between the weather icon
        // and the temperature
        function separated(a, b) {
            return useSep && !((a.elementId === "icon" && b.elementId === "temp")
                               || (a.elementId === "temp" && b.elementId === "icon"));
        }
        // the room between two neighbours on a line
        function between(a, b) {
            return separated(a, b) ? compact.gapBeside(a) + sepW + compact.gapBeside(b) : compact.gapBetween(a, b);
        }
        // Places one line's elements from `x`, centred on a line `height` tall at `y`.
        function placeLine(line, x, y, height) {
            for (var k = 0; k < line.length; ++k) {
                var el = line[k];
                if (k > 0) {
                    if (separated(line[k - 1], el)) {
                        x += compact.gapBeside(line[k - 1]);
                        placeSep(x, y + Math.round((height - sepH) / 2));
                        x += sepW + compact.gapBeside(el);
                    } else {
                        x += compact.gapBetween(line[k - 1], el);
                    }
                }
                el.x = x;
                el.y = y + Math.round((height - el.implicitHeight) / 2);
                x += el.implicitWidth;
            }
        }
        // the lines: one on a horizontal panel
        var lines = [], line = null;
        for (i = 0; i < items.length; ++i) {
            it = items[i];
            var room = line ? between(line.items[line.items.length - 1], it) : 0;
            if (line && (!compact.vertical || line.width + room + it.implicitWidth <= compact.width)) {
                line.items.push(it);
                line.width += room + it.implicitWidth;
                line.height = Math.max(line.height, it.implicitHeight);
            } else {
                line = { items: [it], width: it.implicitWidth, height: it.implicitHeight };
                lines.push(line);
            }
        }
        if (!compact.vertical) {
            // one line, centred across the panel's height (the icon may reach past it)
            var w = lines.length > 0 ? lines[0].width : 0;
            if (lines.length > 0)
                placeLine(lines[0].items, Math.max(0, Math.round((compact.width - w) / 2)), 0, compact.height);
            compact.contentWidth = w;
            compact.contentHeight = compact.height;
            return;
        }
        // A separator between two lines gets a row of its own, a little lower than its
        // text: the mark sits in the middle of the line, the text reaches above it.
        var sepRow = useSep ? Math.round(compact.secondaryPx * 0.7) : 0;
        // whether a separator goes between line i - 1 and line i
        function lineSeparated(i) {
            var above = lines[i - 1].items;
            return separated(above[above.length - 1], lines[i].items[0]);
        }
        var h = 0;
        for (i = 0; i < lines.length; ++i)
            h += (i > 0 ? compact.lineGap + (lineSeparated(i) ? sepRow + compact.lineGap : 0) : 0) + lines[i].height;
        var y = Math.max(0, Math.round((compact.height - h) / 2));
        for (i = 0; i < lines.length; ++i) {
            if (i > 0) {
                y += compact.lineGap;
                if (lineSeparated(i)) {
                    placeSep(Math.round((compact.width - sepW) / 2), y + Math.round((sepRow - sepH) / 2));
                    y += sepRow + compact.lineGap;
                }
            }
            placeLine(lines[i].items, Math.round((compact.width - lines[i].width) / 2), y, lines[i].height);
            y += lines[i].height;
        }
        compact.contentWidth = compact.width;
        compact.contentHeight = h;
    }

    // No stale marker in the panel: the panel is glanced at, not read, and a dot there
    // says something is wrong without saying what. The "Updated Xh ago" line in both
    // popup layouts carries it instead (weatherRoot.weatherStale / staleAgeStr).
}
