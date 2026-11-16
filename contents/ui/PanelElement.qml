/*
 * One element on the panel (see CompactView): the weather icon, the temperature, the
 * location's or the condition's name, or a reading with its icon (main.qml
 * panelMetricParts).
 *
 * On a vertical panel it keeps within the panel's width (`maxWidth`). A name wraps
 * onto more lines between its words, and a reading puts each icon above its value,
 * which wraps the same way; only a word too wide for the panel on its own shrinks
 * them, as it does the temperature. The weather icon may reach past the width, as it
 * reaches past a horizontal panel's height: its artwork leaves the edges of its box
 * empty.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: element
    property var weatherRoot: null
    property string elementId: ""
    property int iconPx: 24        // the weather icon's box
    property int tempPx: 16        // the temperature's font
    property int secondaryPx: 9    // every other element's font
    property real maxWidth: Infinity
    readonly property bool narrow: isFinite(maxWidth)

    readonly property bool isName: elementId === "location" || elementId === "condition"
    readonly property bool isReading: elementId !== "icon" && elementId !== "temp" && !isName
    readonly property var parts: isReading && weatherRoot ? weatherRoot.panelMetricParts(elementId) : []
    readonly property string text: {
        if (!weatherRoot) return "";
        if (elementId === "temp") return weatherRoot.temperatureText;
        if (elementId === "location") return weatherRoot.locationShortName;
        if (elementId === "condition" && weatherRoot.heroCode >= 0)
            return weatherRoot.conditionText(weatherRoot.heroCode, weatherRoot.heroDay);
        return "";
    }
    // Whether it has anything to show: one without data takes no room on the panel.
    // The temperature keeps its "—" until the first forecast, as it always has.
    readonly property bool present: {
        if (!weatherRoot) return false;
        if (elementId === "icon") return true;
        if (!weatherRoot.hasLocation) return false;
        if (isReading) return parts.length > 0;
        return text.length > 0 && (elementId === "temp" || text !== "—");
    }

    visible: present
    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: element.elementId === "icon" ? iconComponent
                       : element.elementId === "temp" ? tempComponent
                       : element.isName ? nameComponent
                       : element.narrow ? narrowReadingComponent : readingComponent
    }

    // ── the weather icon ──
    // The Meteocons sun glyph fills its box more than the other condition icons
    // (same "over-full artwork" issue main.qml's heroScale/iconZoom correct for
    // elsewhere), so it reads oversized in the panel at the same box size next
    // to e.g. clouds. Scale it down a touch; every other condition, and the theme
    // and custom packs, are untouched.
    function panelIconScale() {
        if (!weatherRoot || !(_source === "pack" ? weatherRoot.iconPackIsMeteocons
                                                 : _source !== "element" || weatherRoot.elementWeatherPack(true) !== null))
            return 1.0;
        var code = weatherRoot.heroCode, day = weatherRoot.heroDay;
        if ((code === 0 || code === 1) && day !== 0) return 0.85;   // clear sky / sunny (day)
        return 1.0;
    }
    // Where the icon comes from:
    //   "mono"    — without the panel's "Use colored icons": Meteocons' monochrome
    //               icon in the panel's text colour;
    //   "pack"    — with it, the Weather icon pack's (the system theme's, the custom
    //               folder's, or a Meteocons colour style);
    //   "element" — with it and a monochrome Weather icon pack, which has no colours to
    //               show: the Element icon pack's weather icon (main.qml
    //               elementWeatherIcon), Meteocons' flat or line one or the custom
    //               Element folder's own;
    //   "line"    — as "element", for a custom Element folder without the icon (or no
    //               folder): Meteocons' line one.
    readonly property bool _hasIcon: !!weatherRoot && weatherRoot.hasLocation && weatherRoot.heroCode >= 0
    readonly property string _source: {
        if (!_hasIcon) return "";
        if (!weatherRoot.panelColorIcon) return "mono";
        if (!weatherRoot.iconPackIsMask) return "pack";
        if (weatherRoot.elementWeatherPack(true) !== null) return "element";
        return weatherRoot.readingIconDir !== "" && !_elementMissing ? "element" : "line";
    }
    // panel-only: the moon-behind-cloud icon for an overcast night (the popup keeps
    // its own overcast-night artwork)
    readonly property string _override: weatherRoot && weatherRoot.heroCode === 3 && weatherRoot.heroDay === 0
                                        ? "wi-night-alt-partly-cloudy" : ""
    // the custom Element folder's icon, while it is the one to show
    readonly property string _elementSource: _hasIcon && weatherRoot.panelColorIcon && weatherRoot.iconPackIsMask
        ? weatherRoot.elementWeatherIcon(weatherRoot.heroCode, weatherRoot.heroDay, weatherRoot.heroCloud,
                                         true, _override || undefined) : ""
    // the custom Element folder lacks the icon (see the Image below)
    property bool _elementMissing: false
    on_ElementSourceChanged: _elementMissing = false
    // A missing local file fails while the Image's source is still being bound, so the
    // switch to the line icon waits a turn — at once, it is a binding loop and the icon
    // stayed empty.
    function _markMissing() { _elementMissing = true; }
    // Meteocons' line and monochrome icons are drawn bolder on the panel than the files
    // (main.qml boldWeatherIcon, iconweights.js `panel`): their thin lines read faint at
    // a panel's size. The style to draw so — "monochrome", in the panel's text colour,
    // or "line", its clouds grey on a light panel — or "" for a file or a theme's icon.
    readonly property string _boldStyle: {
        switch (_source) {
        case "mono":    return "monochrome";
        case "line":    return "line";
        case "pack":    return weatherRoot.iconPackId === "meteocons-line" ? "line" : "";
        case "element": return weatherRoot.readingIconPack === "meteocons-line" ? "line" : "";
        }
        return "";
    }
    function panelIconSource() {
        if (!weatherRoot) return "";
        if (!weatherRoot.hasLocation) return "mark-location";   // no location set → pin, not fake weather
        var code = weatherRoot.heroCode, day = weatherRoot.heroDay, cloud = weatherRoot.heroCloud;
        if (_boldStyle)
            return weatherRoot.boldWeatherIcon(_boldStyle, _override || weatherRoot.conditionStem(code, day, cloud),
                                               Kirigami.Theme.textColor);
        if (_source === "pack") return weatherRoot.conditionIcon(code, day, cloud, _override || undefined);
        if (_source === "element") return _elementSource;
        return weatherRoot.conditionIcon(-1, 1, NaN);
    }
    Component {
        id: iconComponent
        // A pack's colored icons render flat via a plain Image (no icon-engine
        // recolouring), and so do the bold ones, already in the panel's colours; theme
        // packs need Kirigami.Icon to resolve "weather-*" names, so the two swap by
        // visibility. With no forecast yet every pack falls back to the theme's
        // "weather-none-available" name, which only the Kirigami.Icon can load; so does
        // the "mark-location" pin of a widget with no location.
        Item {
            readonly property bool flat: element._hasIcon
                                         && !(element._source === "pack" && element.weatherRoot.iconPackIsTheme)
            implicitWidth: flat ? icon.width : themeIcon.width
            implicitHeight: implicitWidth
            Image {
                id: icon
                visible: parent.flat
                anchors.centerIn: parent
                height: Math.round(element.iconPx * element.panelIconScale())
                width: height
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: visible ? element.panelIconSource() : ""
                // the custom Element folder lacks the icon: Meteocons' line one instead
                onStatusChanged: if (status === Image.Error && element._source === "element"
                                     && element.weatherRoot.elementWeatherPack(true) === null)
                                     Qt.callLater(element._markMissing)
            }
            Kirigami.Icon {
                id: themeIcon
                visible: !parent.flat
                anchors.centerIn: parent
                height: element.iconPx
                width: height
                color: Kirigami.Theme.textColor
                source: visible ? element.panelIconSource() : ""
            }
        }
    }

    // ── the temperature ──
    // On a vertical panel it shrinks to the panel's width when wider: its width at the
    // full size, measured, gives the size that fits.
    TextMetrics {
        id: tempMetrics
        font.pixelSize: element.tempPx
        font.weight: element.weatherRoot ? element.weatherRoot.panelTempFontWeight : Font.Normal
        text: element.elementId === "temp" ? element.text : ""
    }
    Component {
        id: tempComponent
        Text {
            text: element.text
            color: Kirigami.Theme.textColor
            font.pixelSize: Math.max(1, Math.floor(element.tempPx
                                     * Math.min(1, element.maxWidth / Math.max(1, tempMetrics.advanceWidth))))
            font.weight: tempMetrics.font.weight
        }
    }

    // ── on a vertical panel: the secondary font shrunk for a word too wide ──
    FontMetrics {
        id: secondaryMetrics
        font.pixelSize: element.secondaryPx
        font.weight: element.weatherRoot ? element.weatherRoot.panelSecondaryFontWeight : Font.Normal
    }
    // the widest word of `texts` (rich text: its tags dropped) at the full size
    function widestWord(texts) {
        var w = 0;
        texts.forEach(function (t) {
            String(t).replace(/<[^>]*>/g, "").replace(/&#160;|&nbsp;/g, " ").split(/\s+/).forEach(function (word) {
                if (word.length > 0) w = Math.max(w, secondaryMetrics.advanceWidth(word));
            });
        });
        return w;
    }
    // The secondary font's size there: full, unless a word (or a reading's icon, `minWidth`
    // at the full size) is wider than the panel.
    function narrowPx(texts, minWidth) {
        var w = Math.max(widestWord(texts), minWidth || 0);
        return Math.max(1, Math.floor(secondaryPx * Math.min(1, maxWidth / Math.max(1, w))));
    }

    // ── the location's or the condition's name ──
    // On a vertical panel it wraps between its words onto as many lines as it needs.
    Component {
        id: nameComponent
        Item {
            implicitWidth: name.width
            implicitHeight: name.implicitHeight
            Text {
                id: name
                width: Math.min(implicitWidth, element.maxWidth)
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: element.text
                color: Kirigami.Theme.textColor
                font.pixelSize: element.narrow ? element.narrowPx([element.text], 0) : element.secondaryPx
                font.weight: secondaryMetrics.font.weight
            }
        }
    }

    // ── a reading ──
    // In the secondary font, its icons coloured with the panel's "Use colored icons":
    // each value after its icon, or on a vertical panel under it.
    readonly property bool colored: !!weatherRoot && weatherRoot.panelColorIcon
    Component {
        id: readingComponent
        ElementReading {
            weatherRoot: element.weatherRoot
            parts: element.parts
            fontPx: element.secondaryPx
            fontWeight: secondaryMetrics.font.weight
            color: Kirigami.Theme.textColor
            coloredIcons: element.colored
            iconOpacity: 1
        }
    }
    Component {
        id: narrowReadingComponent
        Column {
            id: stack
            // the widest icon at the full size, as ReadingIcon sizes it
            readonly property real iconWidth: {
                var w = 0, root = element.weatherRoot;
                if (!root) return 0;
                element.parts.forEach(function (part) {
                    w = Math.max(w, Math.ceil(Math.round(element.secondaryPx * 2.2 * root.readingIconScale(part.icon))
                                              * root.readingIconSpan(part.icon)));
                });
                return w;
            }
            readonly property int px: element.narrowPx(element.parts.map(function (part) { return part.text; }), iconWidth)
            spacing: Math.round(px * 0.3)
            Repeater {
                model: element.parts
                delegate: Column {
                    id: part
                    required property var modelData
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    spacing: Math.round(stack.px * 0.15)
                    // the artwork reaches past a line's height: its own room above the value
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: icon.implicitWidth
                        height: Math.round(stack.px * 1.4)
                        ReadingIcon {
                            id: icon
                            anchors.centerIn: parent
                            weatherRoot: element.weatherRoot
                            name: part.modelData.icon
                            colored: element.colored
                            tint: Kirigami.Theme.textColor
                            fontPx: stack.px
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, element.maxWidth)
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.StyledText
                        text: part.modelData.text
                        color: Kirigami.Theme.textColor
                        font.pixelSize: stack.px
                        font.weight: secondaryMetrics.font.weight
                    }
                }
            }
        }
    }
}
