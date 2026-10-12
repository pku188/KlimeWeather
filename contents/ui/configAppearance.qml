/*
 * Appearance settings — a Common tab for what both layouts share, then one tab
 * each for the card layout, the graph layout and the panel.
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import "../icons/meteocons/readings/monochrome.js" as MonoReadings
import "panelelements.js" as PanelElements

Item {
    id: page
    // shared by the three scroll-animation spins below
    readonly property string slideTip: i18n("How long the graph takes to glide to its new position after one scroll notch. A bigger scroll step covers more ground, so it wants a longer glide to feel the same. 0 jumps straight there.")
    // on the card layout's Weather Elements lists
    readonly property string elementsHoverTip: i18n("The element header readouts follow whichever hour you hover.")
    // shared by the panel's size spins
    readonly property string panelSizeTip: i18n("A percentage of the panel's thickness: its height, or a vertical panel's width.")

    // cfg_* are auto-bound to the config keys by Plasma. ids live anywhere in
    // this file (file-wide scope), so the controls can sit inside the tabs while
    // their aliases stay here at the page root.

    // shared
    property string cfg_iconPack
    property string cfg_customIconDir
    // Detailed layout (forecast days moved here from the General page)
    property alias cfg_dailyDays:          dailyDaysSpin.value
    property alias cfg_heroIconSize:       heroSpin.value
    property alias cfg_tempFontSize:       tempSpin.value
    property alias cfg_dailyNameFontSize:  dailyNameSpin.value
    property alias cfg_dailyIconSize:      dailySpin.value
    property alias cfg_dailyTempFontSize:  dailyTempSpin.value
    property alias cfg_windArrowSize:      windArrowSpin.value
    property alias cfg_showDayDate:        dayDateCheck.checked
    property alias cfg_hourlyCardsFirst:   hourlyFirstCheck.checked
    property alias cfg_hourlyIconSize:     hourlySpin.value
    property alias cfg_hourlyTempFontSize: hourlyTempSpin.value
    property alias cfg_hourlyCardFontSize: hourlyCardSpin.value
    property alias cfg_conditionFontSize:  condFontSpin.value
    property alias cfg_locationFontSize:   locFontSpin.value
    property alias cfg_providerFontSize:   providerFontSpin.value
    property alias cfg_toolbarIconSize:    toolbarIconSpin.value
    property int   cfg_cardAnimation
    // the older per-part switches, read only while cardAnimation was never chosen
    property bool  cfg_animatedDailyIcons
    property bool  cfg_animatedHourlyIcons
    property string cfg_headerMetric1
    property string cfg_headerMetric2
    property string cfg_headerMetric3
    property string cfg_headerMetric4
    property alias  cfg_headerInfoFontSize: elementsFontSpin.value
    property int    cfg_headerInfoFontWeight
    property alias  cfg_cardsPerScroll:     cardScrollSpin.value
    property alias  cfg_cardSlideMs:        cardSlideSpin.value
    property alias  cfg_cardDealDurationPercent: cardDealSpin.value
    // Simple layout (forecast days moved here from General). The graph zoom has no
    // entry here: it is toggled from the graph's own toolbar, and declaring it would let
    // Apply write back the value this page loaded, undoing a toolbar zoom made meanwhile.
    property alias cfg_simpleHourlyIconSize:   simpleIconSpin.value
    property alias cfg_simpleHourFontSize:     simpleHourSpin.value
    property alias cfg_simpleGraphTempFontSize: simpleGraphTempSpin.value
    property alias cfg_simpleDayMarkerFontSize: simpleDayMarkerSpin.value
    property alias cfg_dayPillFontSize:         dayPillSpin.value
    property alias cfg_simpleDailyDays:         graphDaysSpin.value
    property alias cfg_graphScrollHoursDay:     graphScrollDaySpin.value
    property alias cfg_graphScrollHoursDetail:  graphScrollDetailSpin.value
    property alias cfg_graphScrollHoursWide:    graphScrollWideSpin.value
    property alias cfg_graphSlideMsDetail:      graphSlideDetailSpin.value
    property alias cfg_graphSlideMsDay:         graphSlideDaySpin.value
    property alias cfg_graphSlideMsWide:        graphSlideWideSpin.value
    property int   cfg_graphAnimation
    // the older per-part switches, read only while graphAnimation was never chosen
    property bool  cfg_simpleAnimatedIcons
    property bool  cfg_simpleHeaderAnim
    property int   cfg_graphColorMode
    property alias cfg_precipBandOpacity:      precipBandSpin.value
    property int   cfg_precipLabelMode
    property alias cfg_showDayMarkerDate:      dayMarkerDateCheck.checked
    property string cfg_simpleHeaderMetric1
    property string cfg_simpleHeaderMetric2
    property string cfg_simpleHeaderMetric3
    property string cfg_simpleHeaderMetric4
    property string cfg_hourlyMetric1
    property string cfg_hourlyMetric2
    property string cfg_hourlyMetric1Fallback
    property string cfg_hourlyMetric1Fallback2
    property string cfg_hourlyMetric2Fallback
    property string cfg_hourlyMetric2Fallback2
    property int    cfg_detailDayStartHour
    // Panel (compact view)
    property alias cfg_panelIconPercent:   panelIconSpin.value
    property alias cfg_panelFontPercent:   panelFontSpin.value
    property alias cfg_panelColorIcon:     panelColorCheck.checked
    property string cfg_panelElements
    // the older "Panel display", read only while the Panel Elements were never edited
    property int   cfg_panelDisplay
    property bool  cfg_panelDetailed
    property int   cfg_panelSecondLine
    property int   cfg_panelTempFontWeight
    property int   cfg_panelSecondLineFontWeight
    property alias cfg_panelElementSpacing: panelSpacingSpin.value
    property int   cfg_panelElementSeparator
    property string cfg_panelElementSeparatorText
    property alias cfg_dayMarkerIconColored: dayMarkerColorCheck.checked
    property alias cfg_readingIconsColored: readingColorCheck.checked
    property alias cfg_weatherSpecificColors: weatherColorsCheck.checked
    property int   cfg_headerElementsStyle
    property alias cfg_panelSecondLinePercent: panelSecondarySpin.value

    // The option lists below are sorted by their translated names, "None" first.
    function sortedOptions(list) {
        var none = list.filter(function (o) { return o.id === "none"; });
        var rest = list.filter(function (o) { return o.id !== "none"; });
        rest.sort(function (a, b) { return a.text.localeCompare(b.text); });
        return none.concat(rest);
    }
    function findMetricIndex(arr, id) {
        for (var i = 0; i < arr.length; ++i)
            if (arr[i].id === id) return i;
        return 0;
    }
    function detailMetricIndexOf(id)  { return findMetricIndex(detailMetricOptions,  id) }
    function hourlyMetricIndexOf(id)  { return findMetricIndex(hourlyMetricOptions,  id) }
    // Weather Elements options (id ↔ label), shared by the card and graph headers.
    readonly property var detailMetricOptions: sortedOptions([
        { text: i18n("None"),                   id: "none"       },
        { text: i18n("Feels like"),             id: "feelsLike"  },
        { text: i18n("Dew point"),              id: "dewPoint"   },
        { text: i18n("Humidity"),               id: "humidity"   },
        { text: i18n("UV Index"),               id: "uv"         },
        { text: i18n("High / low temperature"), id: "hiLo"       },
        { text: i18n("Precipitation (hourly)"), id: "precipRate" },
        { text: i18n("Precipitation (daily)"),  id: "precipSum"  },
        { text: i18n("Wind"),                   id: "wind"       },
        { text: i18n("Snowfall today"),         id: "snowSum"    },
        { text: i18n("Cloud cover"),            id: "cloud"      },
        { text: i18n("Air pressure"),           id: "pressure"   },
        { text: i18n("Sunrise / sunset"),       id: "sun"        }
    ])
    // Per-hour options for the Detailed hourly-card readouts (chance/amount are
    // per-hour, unlike the header's daily-total precip/snow sums), and their fallbacks.
    readonly property var hourlyMetricOptions: sortedOptions([
        { text: i18n("None"),          id: "none"      },
        { text: i18n("Wind"),          id: "wind"      },
        { text: i18n("Wind + gust"),   id: "windGust"  },
        { text: i18n("Precip chance"), id: "precip"    },
        { text: i18n("Precip amount"), id: "precipAmt" },
        { text: i18n("Snowfall"),      id: "snow"      },
        { text: i18n("Feels like"),    id: "feelsLike" },
        { text: i18n("Dew point"),     id: "dewPoint"  },
        { text: i18n("Humidity"),      id: "humidity"  },
        { text: i18n("UV Index"),      id: "uv"        },
        { text: i18n("Cloud cover"),   id: "cloud"     },
        { text: i18n("Air pressure"),  id: "pressure"  }
    ])
    // ── Panel Elements (cfg_panelElements JSON ↔ ListModel mirror) ──
    // Each element's name; a reading's as in the Weather Elements.
    function panelElementName(id) {
        switch (id) {
        case "icon":       return i18n("Weather icon");
        case "temp":       return i18n("Temperature");
        case "location":   return i18n("Location");
        case "condition":  return i18n("Condition");
        case "hiLo":       return i18n("High / low temperature");
        case "precipRate": return i18n("Precipitation (hourly)");
        case "wind":       return i18n("Wind (speed / gust)");
        case "feelsLike":  return i18n("Feels like");
        case "humidity":   return i18n("Humidity");
        case "precipSum":  return i18n("Precipitation (daily)");
        case "uv":         return i18n("UV Index");
        case "pressure":   return i18n("Air pressure");
        case "sun":        return i18n("Sunrise / sunset");
        case "dewPoint":   return i18n("Dew point");
        case "snowSum":    return i18n("Snowfall");
        case "cloud":      return i18n("Cloud cover");
        }
        return id;
    }
    // The Meteocons reading icon each list entry shows (main.qml readingIcon): a
    // reading's own, the one before it on the panel, a cloud with the sun for the
    // weather icon and a thermometer for the temperature. The location and the
    // condition take theirs from the icon theme (PanelElementIcon).
    readonly property var panelElementIcons: ({
        icon: "partly-cloudy-day", temp: "thermometer", hiLo: "thermometer", precipRate: "umbrella", wind: "wind",
        feelsLike: "thermometer", humidity: "humidity", precipSum: "raindrops",
        uv: "uv-index", pressure: "barometer", sun: "sunrise", dewPoint: "thermometer-raindrop",
        snowSum: "snowflake", cloud: "cloudy"
    })
    // A monochrome reading icon in `tint`, as a data URL (as main.qml readingIcon).
    property var _monoUrls: ({})
    function monoReadingIcon(name, tint) {
        var hex = "" + tint, key = name + hex;
        if (!_monoUrls[key]) {
            var svg = MonoReadings.svg[name];
            if (!svg) return "";
            _monoUrls[key] = "data:image/svg+xml;utf8," + encodeURIComponent(svg.replace(/currentColor/g, hex));
        }
        return _monoUrls[key];
    }
    // An element's icon in the lists, in the text colour.
    component PanelElementIcon: Item {
        id: elementIcon
        property string elementId: ""
        readonly property string reading: page.panelElementIcons[elementId] || ""
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: implicitWidth
        // the reading icons' artwork leaves the edges of their box empty
        Image {
            visible: elementIcon.reading.length > 0
            anchors.centerIn: parent
            width: Math.round(parent.width * 1.6)
            height: width
            sourceSize: Qt.size(width, height)
            source: visible ? page.monoReadingIcon(elementIcon.reading, Kirigami.Theme.textColor) : ""
        }
        Kirigami.Icon {
            visible: elementIcon.reading.length === 0
            anchors.fill: parent
            source: elementIcon.elementId === "location" ? "mark-location-symbolic" : "draw-text-symbolic"
        }
    }

    ListModel { id: panelModel }   // { elementId, shown }, in the panel's order
    // An entry of the list to add from, never shown: what one is tall (see addScroll).
    ItemDelegate {
        id: addRowProbe
        opacity: 0
        enabled: false
        bottomPadding: Kirigami.Units.smallSpacing
        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            PanelElementIcon { elementId: "temp" }
            Label { text: "Xg" }
        }
    }
    // the elements not on the panel, by name, for the list to add from: [{ id, text }]
    property var panelAvailable: []
    // the ids shown on the panel, for the settings that apply to them
    property var panelShownIds: []
    readonly property bool panelShowsIcon: panelShownIds.length === 0 || panelShownIds.indexOf("icon") >= 0
    readonly property bool panelShowsTemp: panelShownIds.indexOf("temp") >= 0
    readonly property bool panelShowsReading: panelShownIds.some(function (id) {
        return PanelElements.readings.indexOf(id) >= 0;
    })
    readonly property bool panelShowsSecondary: panelShownIds.some(function (id) {
        return id !== "icon" && id !== "temp";
    })
    // spacing and separators need two elements to go between
    readonly property bool panelShowsSeveral: panelShownIds.length > 1

    function _panelModelList() {
        var out = [];
        for (var i = 0; i < panelModel.count; ++i)
            out.push({ id: panelModel.get(i).elementId, shown: panelModel.get(i).shown });
        return out;
    }
    // The model from cfg_panelElements — rebuilt only when that says something else,
    // so a change made here doesn't recreate the rows — and the lists that follow it.
    function _syncPanel() {
        var list = PanelElements.parse(cfg_panelElements, cfg_panelDisplay, cfg_panelDetailed, cfg_panelSecondLine);
        if (PanelElements.stringify(list) !== PanelElements.stringify(_panelModelList())) {
            panelModel.clear();
            for (var i = 0; i < list.length; ++i)
                panelModel.append({ elementId: list[i].id, shown: list[i].shown });
        }
        var on = {};
        list.forEach(function (el) { on[el.id] = true; });
        panelShownIds = list.filter(function (el) { return el.shown; }).map(function (el) { return el.id; });
        var avail = PanelElements.all.filter(function (id) { return !on[id]; })
                                     .map(function (id) { return { id: id, text: panelElementName(id) }; });
        avail.sort(function (a, b) { return a.text.localeCompare(b.text); });
        panelAvailable = avail;
        if (addList) addList.currentIndex = -1;
    }
    onCfg_panelElementsChanged: _syncPanel()
    Component.onCompleted: _syncPanel()
    function _storePanel() {
        cfg_panelElements = PanelElements.stringify(_panelModelList());
        _syncPanel();
    }
    function togglePanelElement(i) {
        panelModel.setProperty(i, "shown", !panelModel.get(i).shown);
        _storePanel();
    }
    function removePanelElement(i) {
        panelModel.remove(i);
        _storePanel();
    }
    // a new element goes at the end of the list, shown
    function addPanelElement(id) {
        panelModel.append({ elementId: id, shown: true });
        _storePanel();
    }
    function movePanelElement(from, to) {
        panelModel.move(from, to, 1);
        _storePanel();
    }
    // The last character of `text` as it is seen: a letter with its accents, or an
    // emoji with what belongs to it — a skin tone, the variation selector that makes
    // it colourful, the emoji joined to it (a family, a profession), the second letter
    // of a flag. JavaScript here counts in UTF-16 units, so even 😄 is two of them.
    function lastCharacter(text) {
        var clusters = [], i = 0;
        while (i < text.length) {
            var hi = text.charCodeAt(i), cp = hi, len = 1;
            if (hi >= 0xD800 && hi <= 0xDBFF && i + 1 < text.length) {
                var lo = text.charCodeAt(i + 1);
                if (lo >= 0xDC00 && lo <= 0xDFFF) { cp = (hi - 0xD800) * 0x400 + (lo - 0xDC00) + 0x10000; len = 2; }
            }
            var ch = text.substr(i, len);
            i += len;
            var last = clusters.length > 0 ? clusters[clusters.length - 1] : null;
            var mark = (cp >= 0x0300 && cp <= 0x036F) || (cp >= 0x1AB0 && cp <= 0x1AFF)
                    || (cp >= 0x1DC0 && cp <= 0x1DFF) || (cp >= 0x20D0 && cp <= 0x20FF)   // accents, keycap
                    || (cp >= 0xFE00 && cp <= 0xFE0F) || (cp >= 0xFE20 && cp <= 0xFE2F)   // variation selectors
                    || (cp >= 0x1F3FB && cp <= 0x1F3FF)                                   // skin tones
                    || (cp >= 0xE0020 && cp <= 0xE007F)                                   // tags (subdivision flags)
                    || cp === 0x200D;                                                     // zero-width joiner
            var flagHalf = cp >= 0x1F1E6 && cp <= 0x1F1FF;
            if (last && (mark || last.joined || (flagHalf && last.flagHalves === 1))) {
                last.text += ch;
                last.joined = cp === 0x200D;
                if (flagHalf) last.flagHalves = 2;
            } else {
                clusters.push({ text: ch, joined: false, flagHalves: flagHalf ? 1 : 0 });
            }
        }
        return clusters.length > 0 ? clusters[clusters.length - 1].text : "";
    }

    // Dragging a row: where it came from and where it would land; the rows between
    // make room for it (see the rows' shift).
    property int panelDragFrom: -1
    property int panelDragTo: -1
    property real panelDragPitch: 0
    property bool panelRowsAnimate: false

    FolderDialog {
        id: iconFolderDialog
        title: i18n("Choose icon folder")
        onAccepted: page.cfg_customIconDir = selectedFolder
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton { text: i18n("Common") }
            TabButton { text: i18n("Cards") }
            TabButton { text: i18n("Graph") }
            TabButton { text: i18n("Panel") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // ── Common to both layouts ──
            // The header is built the same way in the card and graph layouts — same
            // icon, temperature, condition, location and source button, in the same
            // spots — so these size them in both rather than twice over.
            ScrollView {
                contentWidth: availableWidth
                Kirigami.FormLayout {
                    Layout.alignment: Qt.AlignTop
                    // The condition-icon pack applies to both layouts and the panel,
                    // which is what makes it a Common setting.
                    ConfigComboBox {
                        id: iconPackCombo
                        Kirigami.FormData.label: i18n("Icon pack:")
                        textRole: "text"
                        // each option stores its pack id (matches the registry in main.qml);
                        // a saved id missing here (the retired "basmilius") selects the
                        // first entry, which is also what main.qml falls back to
                        model: [
                            { text: i18n("Meteocons (fill)"),       id: "meteocons-fill"       },
                            { text: i18n("Meteocons (flat)"),       id: "meteocons-flat"       },
                            { text: i18n("Meteocons (line)"),       id: "meteocons-line"       },
                            { text: i18n("Meteocons (monochrome)"), id: "meteocons-monochrome" },
                            { text: i18n("System theme"),           id: "system"               },
                            { text: i18n("Custom folder…"),         id: "custom"               }
                        ]
                        Component.onCompleted: {
                            for (var i = 0; i < model.length; ++i)
                                if (model[i].id === page.cfg_iconPack) { currentIndex = i; break; }
                        }
                        onActivated: page.cfg_iconPack = model[currentIndex].id
                    }
                    RowLayout {
                        Kirigami.FormData.label: i18n("Custom folder:")
                        visible: page.cfg_iconPack === "custom"
                        Button {
                            text: i18n("Choose…")
                            icon.name: "folder-open"
                            onClicked: iconFolderDialog.open()
                        }
                        Label {
                            Layout.fillWidth: true
                            // cap the layout contribution so a long path can't inflate the
                            // form width (elide trims rendering, not implicitWidth)
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                            elide: Text.ElideMiddle
                            opacity: 0.7
                            text: page.cfg_customIconDir
                                  ? page.cfg_customIconDir.replace(/^file:\/\//, "")
                                  : i18n("(none selected)")
                        }
                    }
                    Label {
                        visible: page.cfg_iconPack === "custom"
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: i18n("Folder with SVGs named like the bundled set (wi-day-sunny.svg, wi-night-clear.svg, …). Tip: copy contents/icons/meteocons/fill/static/ as a starting point so every condition is covered, then edit.")
                    }
                    ConfigSpinBox {
                        id: heroSpin
                        Kirigami.FormData.label: i18n("Header icon size:")
                        from: 48
                        to: 200
                        stepSize: 4
                    }
                    ConfigSpinBox {
                        id: tempSpin
                        Kirigami.FormData.label: i18n("Temperature font:")
                        from: 24
                        to: 120
                        stepSize: 2
                    }
                    ConfigSpinBox {
                        id: condFontSpin
                        Kirigami.FormData.label: i18n("Condition font:")
                        from: 12
                        to: 64
                        stepSize: 1
                    }
                    ConfigSpinBox {
                        id: locFontSpin
                        Kirigami.FormData.label: i18n("Location font:")
                        from: 12
                        to: 64
                        stepSize: 1
                    }
                    ConfigSpinBox {
                        id: providerFontSpin
                        Kirigami.FormData.label: i18n("Weather source font:")
                        from: 8
                        to: 40
                        stepSize: 1
                        ToolTip.visible: hovered
                        ToolTip.text: i18n("Sizes the MET Norway / Open-Meteo button; its logo scales with the text.")
                    }
                    ConfigSpinBox {
                        id: toolbarIconSpin
                        Kirigami.FormData.label: i18n("Toolbar icon size:")
                        from: 16
                        to: 40
                        stepSize: 1
                        ToolTip.visible: hovered
                        ToolTip.text: i18n("Sizes the buttons in the popup's corners: keep open, zoom, layout switch and refresh.")
                    }
                    ConfigSpinBox {
                        id: elementsFontSpin
                        Kirigami.FormData.label: i18n("Weather Elements font:")
                        from: 7
                        to: 32
                        stepSize: 1
                    }
                    ConfigComboBox {
                        id: elementsWeightCombo
                        Kirigami.FormData.label: i18n("Weather Elements font style:")
                        textRole: "text"
                        // the value is the font weight itself
                        model: [
                            { text: i18n("Regular"),  value: 400 },
                            { text: i18n("SemiBold"), value: 600 },
                            { text: i18n("Bold"),     value: 700 }
                        ]
                        Component.onCompleted: {
                            for (var i = 0; i < model.length; ++i)
                                if (model[i].value === page.cfg_headerInfoFontWeight) { currentIndex = i; break; }
                        }
                        onActivated: page.cfg_headerInfoFontWeight = model[currentIndex].value
                        ToolTip.visible: hovered
                        ToolTip.text: i18n("SemiBold needs a font that has it. Where yours doesn't, the nearest weight it has is used — normally Bold.")
                    }
                    ConfigComboBox {
                        id: elementsStyleCombo
                        Kirigami.FormData.label: i18n("Weather Elements style:")
                        textRole: "text"
                        model: [
                            { text: i18n("Text"),  value: 0 },
                            { text: i18n("Icons"), value: 1 }
                        ]
                        Component.onCompleted: currentIndex = page.cfg_headerElementsStyle === 1 ? 1 : 0
                        onActivated: page.cfg_headerElementsStyle = model[currentIndex].value
                        ToolTip.visible: hovered
                        ToolTip.text: i18n("Icons shows each element's icon — the one the hourly cards use — in place of its label.")
                    }
                    CheckBox {
                        id: readingColorCheck
                        Kirigami.FormData.label: i18n("Weather Elements icon color:")
                        text: i18n("Use colored icons")
                        // the Weather Elements have icons only in their icon style
                        enabled: elementsStyleCombo.currentIndex === 1
                        ToolTip.visible: hovered
                        ToolTip.text: i18n("Colors the icons before the Weather Elements.")
                    }
                    CheckBox {
                        id: weatherColorsCheck
                        Kirigami.FormData.label: i18n("Font color:")
                        text: i18n("Use weather specific color")
                        ToolTip.visible: hovered
                        ToolTip.text: i18n("Colors the Weather Elements' values — blue for precipitation, green to red for the UV index, and so on — and the daily tabs' low and high temperatures. Off, they follow your theme.")
                    }
                    ConfigSpinBox {
                        id: windArrowSpin
                        Kirigami.FormData.label: i18n("Wind direction arrow:")
                        from: 10
                        to: 48
                        stepSize: 1
                        ToolTip.visible: hovered
                        ToolTip.text: i18n("Size of the arrow that follows a wind reading, on the hourly cards and in both layouts' Weather Elements.")
                    }
                }
            }

            // ── Detailed layout ──
            ScrollView {
                contentWidth: availableWidth
                RowLayout {
                    spacing: Kirigami.Units.gridUnit * 2
                    Kirigami.FormLayout {
                        Layout.alignment: Qt.AlignTop
                        ConfigSpinBox {
                            id: dailyDaysSpin
                            Kirigami.FormData.label: i18n("Forecast days:")
                            from: 1
                            to: 7
                        }
                        ConfigSpinBox {
                            id: cardScrollSpin
                            Kirigami.FormData.label: i18n("Cards per scroll:")
                            from: 1
                            to: 12
                        }
                        ConfigSpinBox {
                            id: cardSlideSpin
                            Kirigami.FormData.label: i18n("Scroll animation:")
                            from: 0
                            to: 2000
                            stepSize: 50
                            // the unit lives on the value, as with the graph's scroll animation
                            textFromValue: (value, locale) => i18n("%1 ms", value)
                            valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("How long the cards take to glide to their new place after one scroll notch. More cards per scroll covers more ground, so it wants a longer glide to feel the same. 0 jumps straight there.")
                        }
                        ConfigSpinBox {
                            id: dailyNameSpin
                            Kirigami.FormData.label: i18n("Daily tab name font:")
                            from: 8
                            to: 32
                            stepSize: 1
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("The day name. The date under it follows at a slightly smaller size.")
                        }
                        ConfigSpinBox {
                            id: dailySpin
                            Kirigami.FormData.label: i18n("Daily tab icon size:")
                            from: 12
                            to: 64
                            stepSize: 2
                        }
                        ConfigSpinBox {
                            id: dailyTempSpin
                            Kirigami.FormData.label: i18n("Daily tab temperature font:")
                            from: 8
                            to: 32
                            stepSize: 1
                        }
                        ConfigSpinBox {
                            id: hourlySpin
                            Kirigami.FormData.label: i18n("Hourly icon size:")
                            from: 16
                            to: 80
                            stepSize: 2
                        }
                        ConfigSpinBox {
                            id: hourlyTempSpin
                            Kirigami.FormData.label: i18n("Hourly temperature font:")
                            from: 8
                            to: 40
                            stepSize: 1
                        }
                        ConfigSpinBox {
                            id: hourlyCardSpin
                            Kirigami.FormData.label: i18n("Hourly card font:")
                            from: 7
                            to: 32
                            stepSize: 1
                        }
                        ConfigComboBox {
                            id: dayStartCombo
                            Kirigami.FormData.label: i18n("Day starts at:")
                            textRole: "text"
                            // hour a non-today day opens at (detailDayStartHour): 6 AM skips
                            // the overnight cards, Midnight opens at 00:00
                            model: [
                                { text: i18n("6 AM"),     value: 6 },
                                { text: i18n("Midnight"), value: 0 }
                            ]
                            Component.onCompleted: {
                                for (var i = 0; i < model.length; ++i)
                                    if (model[i].value === page.cfg_detailDayStartHour) { currentIndex = i; break; }
                            }
                            onActivated: page.cfg_detailDayStartHour = model[currentIndex].value
                        }
                        ConfigComboBox {
                            id: forecastAnimCombo
                            Kirigami.FormData.label: i18n("Animation:")
                            textRole: "text"
                            // each option adds to the one above it (main.qml cardAnimation)
                            model: [
                                { text: i18n("None"),                       value: 0 },
                                { text: i18n("Header icon"),                value: 1 },
                                { text: i18n("Header and daily tab icons"), value: 2 },
                                { text: i18n("Full layout"),                value: 3 }
                            ]
                            // never chosen: what main.qml derives from the older switches
                            Component.onCompleted: currentIndex = page.cfg_cardAnimation >= 0
                                ? Math.min(3, page.cfg_cardAnimation)
                                : (page.cfg_animatedHourlyIcons ? 3 : page.cfg_animatedDailyIcons ? 2 : 0)
                            onActivated: page.cfg_cardAnimation = model[currentIndex].value
                        }
                        ConfigSpinBox {
                            id: cardDealSpin
                            Kirigami.FormData.label: i18n("Card entrance duration:")
                            // Percentage of the original pace, so lower is faster and 0
                            // is no entrance at all — see dealPercent in FullView.qml.
                            from: 0
                            to: 150
                            stepSize: 10
                            textFromValue: (value, locale) => i18n("%1%", value)
                            valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("How long the hourly cards take to fly in when a day opens, as a percentage of the original pace: lower is faster, 0 turns the animation off.")
                        }
                        CheckBox {
                            id: dayDateCheck
                            Kirigami.FormData.label: i18n("Day tabs:")
                            text: i18n("Show the date under each day")
                        }
                        CheckBox {
                            id: hourlyFirstCheck
                            Kirigami.FormData.label: i18n("Hourly cards:")
                            text: i18n("Show above the day tabs")
                        }

                    }
                    Kirigami.FormLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.leftMargin: Kirigami.Units.gridUnit * 4
                        // section titles as on the Location page
                        Kirigami.Separator {
                            Kirigami.FormData.label: i18n("Weather Elements")
                            Kirigami.FormData.isSection: true
                        }
                        ConfigComboBox {
                            id: detMetric1
                            Kirigami.FormData.label: i18n("Element 1:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric1)
                            onActivated: page.cfg_headerMetric1 = page.detailMetricOptions[currentIndex].id
                            ToolTip.visible: hovered
                            ToolTip.text: page.elementsHoverTip
                        }
                        ConfigComboBox {
                            id: detMetric2
                            Kirigami.FormData.label: i18n("Element 2:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric2)
                            onActivated: page.cfg_headerMetric2 = page.detailMetricOptions[currentIndex].id
                            ToolTip.visible: hovered
                            ToolTip.text: page.elementsHoverTip
                        }
                        ConfigComboBox {
                            id: detMetric3
                            Kirigami.FormData.label: i18n("Element 3:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric3)
                            onActivated: page.cfg_headerMetric3 = page.detailMetricOptions[currentIndex].id
                            ToolTip.visible: hovered
                            ToolTip.text: page.elementsHoverTip
                        }
                        ConfigComboBox {
                            id: detMetric4
                            Kirigami.FormData.label: i18n("Element 4:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric4)
                            onActivated: page.cfg_headerMetric4 = page.detailMetricOptions[currentIndex].id
                            ToolTip.visible: hovered
                            ToolTip.text: page.elementsHoverTip
                        }
                        Kirigami.Separator {
                            Kirigami.FormData.label: i18n("Hourly cards")
                            Kirigami.FormData.isSection: true
                        }
                        ConfigComboBox {
                            id: hourMetric1
                            Kirigami.FormData.label: i18n("Element 1:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric1)
                            onActivated: page.cfg_hourlyMetric1 = page.hourlyMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: hourMetric1Fallback
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric1Fallback)
                            onActivated: page.cfg_hourlyMetric1Fallback = page.hourlyMetricOptions[currentIndex].id
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Shows the main metric, or the fallback on hours the main one has nothing to show.")
                        }
                        ConfigComboBox {
                            id: hourMetric1Fallback2
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric1Fallback2)
                            onActivated: page.cfg_hourlyMetric1Fallback2 = page.hourlyMetricOptions[currentIndex].id
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Shows the main metric, or the fallback on hours the main one has nothing to show.")
                        }
                        ConfigComboBox {
                            id: hourMetric2
                            Kirigami.FormData.label: i18n("Element 2:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric2)
                            onActivated: page.cfg_hourlyMetric2 = page.hourlyMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: hourMetric2Fallback
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric2Fallback)
                            onActivated: page.cfg_hourlyMetric2Fallback = page.hourlyMetricOptions[currentIndex].id
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Shows the main metric, or the fallback on hours the main one has nothing to show.")
                        }
                        ConfigComboBox {
                            id: hourMetric2Fallback2
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric2Fallback2)
                            onActivated: page.cfg_hourlyMetric2Fallback2 = page.hourlyMetricOptions[currentIndex].id
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Shows the main metric, or the fallback on hours the main one has nothing to show.")
                        }
                    }
                }
            }

            // ── Simple layout ──
            ScrollView {
                contentWidth: availableWidth
                RowLayout {
                    spacing: Kirigami.Units.gridUnit * 2
                    Kirigami.FormLayout {
                    Layout.alignment: Qt.AlignTop
                    // No "forecast days" here any more: the graph is fixed at today
                    // + 2 days, the span both providers can draw as a real curve.
                    // The card layout's own day count lives in its tab.
                    // One step per zoom level: the two views show a very different
                    // number of hours, so a single shared value would feel wrong in
                    // one of them.
                    // The steps move in whole label intervals (every hour is labelled at
                    // 12 hours, every 2nd at 24, every 4th at 48). A step that doesn't
                    // divide that way lands the window on the other parity, so every
                    // temperature label on screen changes at once: measured at 25 of 25
                    // labels for an odd step in the 24-hour view, against none for an even
                    // one. Typed-in values are still accepted; the arrows just keep to the
                    // steps that stay smooth.
                    ConfigSpinBox {
                        id: graphDaysSpin
                        Kirigami.FormData.label: i18n("Forecast days:")
                        // the day pills grow to the left, on their own row under the
                        // source button (see HeaderRightBlock)
                        from: 3
                        to: 7
                    }
                    ConfigSpinBox {
                        id: graphScrollDetailSpin
                        Kirigami.FormData.label: i18n("Scroll step, 12-hour view (hours):")
                        from: 1
                        to: 12
                    }
                    ConfigSpinBox {
                        id: graphScrollDaySpin
                        Kirigami.FormData.label: i18n("Scroll step, 24-hour view (hours):")
                        from: 2
                        to: 24
                        stepSize: 2
                    }
                    ConfigSpinBox {
                        id: graphScrollWideSpin
                        Kirigami.FormData.label: i18n("Scroll step, 48-hour view (hours):")
                        from: 4
                        to: 48
                        stepSize: 4
                    }
                    // Kept as a block of their own below the steps rather than paired
                    // with each one: the three steps are read against each other, and so
                    // are the three durations.
                    ConfigSpinBox {
                        id: graphSlideDetailSpin
                        Kirigami.FormData.label: i18n("Scroll animation, 12-hour view:")
                        from: 0
                        to: 2000
                        stepSize: 50
                        // the unit lives on the value, which keeps the label column
                        // narrow enough for a small config window
                        textFromValue: (value, locale) => i18n("%1 ms", value)
                        valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                        ToolTip.visible: hovered
                        ToolTip.text: slideTip
                    }
                    ConfigSpinBox {
                        id: graphSlideDaySpin
                        Kirigami.FormData.label: i18n("Scroll animation, 24-hour view:")
                        from: 0
                        to: 2000
                        stepSize: 50
                        // the unit lives on the value, which keeps the label column
                        // narrow enough for a small config window
                        textFromValue: (value, locale) => i18n("%1 ms", value)
                        valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                        ToolTip.visible: hovered
                        ToolTip.text: slideTip
                    }
                    ConfigSpinBox {
                        id: graphSlideWideSpin
                        Kirigami.FormData.label: i18n("Scroll animation, 48-hour view:")
                        from: 0
                        to: 2000
                        stepSize: 50
                        // the unit lives on the value, which keeps the label column
                        // narrow enough for a small config window
                        textFromValue: (value, locale) => i18n("%1 ms", value)
                        valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                        ToolTip.visible: hovered
                        ToolTip.text: slideTip
                    }
                    ConfigSpinBox {
                        id: simpleIconSpin
                        Kirigami.FormData.label: i18n("Hourly icon size:")
                        from: 12
                        to: 64
                        stepSize: 2
                    }
                    ConfigSpinBox {
                        id: simpleHourSpin
                        Kirigami.FormData.label: i18n("Hour font:")
                        from: 7
                        to: 32
                        stepSize: 1
                    }
                    ConfigSpinBox {
                        id: simpleGraphTempSpin
                        Kirigami.FormData.label: i18n("Graph temperature font:")
                        from: 8
                        to: 40
                        stepSize: 1
                    }
                    ConfigSpinBox {
                        id: simpleDayMarkerSpin
                        Kirigami.FormData.label: i18n("Day label font:")
                        from: 8
                        to: 32
                        stepSize: 1
                    }
                    ConfigSpinBox {
                        id: dayPillSpin
                        Kirigami.FormData.label: i18n("Day buttons font:")
                        from: 8
                        to: 32
                        stepSize: 1
                    }
                    ConfigComboBox {
                        id: simpleAnimCombo
                        Kirigami.FormData.label: i18n("Animation:")
                        textRole: "text"
                        // each option adds to the one above it (main.qml graphAnimation)
                        model: [
                            { text: i18n("None"),        value: 0 },
                            { text: i18n("Header icon"), value: 1 },
                            { text: i18n("Full layout"), value: 2 }
                        ]
                        // never chosen: what main.qml derives from the older switches
                        Component.onCompleted: currentIndex = page.cfg_graphAnimation >= 0
                            ? Math.min(2, page.cfg_graphAnimation)
                            : (page.cfg_simpleAnimatedIcons ? 2 : page.cfg_simpleHeaderAnim ? 1 : 0)
                        onActivated: page.cfg_graphAnimation = model[currentIndex].value
                    }
                    ConfigComboBox {
                        id: graphColorCombo
                        Kirigami.FormData.label: i18n("Graph color:")
                        textRole: "text"
                        // the VALUE is graphColorMode, not the index, so the list can
                        // be reordered without renumbering anyone's saved setting
                        model: [
                            { text: i18n("Temperature curve & precipitation"), value: 4 },
                            { text: i18n("Temperature & precipitation"),       value: 0 },
                            { text: i18n("Temperature only"),                  value: 1 },
                            { text: i18n("Precipitation only"),                value: 2 },
                            { text: i18n("None"),                              value: 3 }
                        ]
                        Component.onCompleted: {
                            for (var i = 0; i < model.length; ++i)
                                if (model[i].value === page.cfg_graphColorMode) { currentIndex = i; break; }
                        }
                        onActivated: page.cfg_graphColorMode = model[currentIndex].value
                    }
                    ConfigSpinBox {
                        id: precipBandSpin
                        Kirigami.FormData.label: i18n("Precipitation gradient:")
                        from: 0
                        to: 90
                        stepSize: 5
                        // the unit lives on the value, as with the card entrance
                        textFromValue: (value, locale) => i18n("%1%", value)
                        valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                        ToolTip.visible: hovered
                        ToolTip.text: i18n("How dense the shaded band under the precipitation curve is. It fades toward the floor either way; 0 leaves the curve as a bare line.")
                    }
                    ConfigComboBox {
                        id: precipLabelCombo
                        Kirigami.FormData.label: i18n("Precipitation labels:")
                        textRole: "text"
                        // value is a bit pair, not the index: 1 = the chance, 2 = the amount
                        model: [
                            { text: i18n("Chance and amount"), value: 3 },
                            { text: i18n("Amount"),            value: 2 },
                            { text: i18n("Chance"),            value: 1 },
                            { text: i18n("Hide"),              value: 0 }
                        ]
                        Component.onCompleted: {
                            for (var i = 0; i < model.length; ++i)
                                if (model[i].value === page.cfg_precipLabelMode) { currentIndex = i; break; }
                        }
                        onActivated: page.cfg_precipLabelMode = model[currentIndex].value
                    }
                    CheckBox {
                        id: dayMarkerDateCheck
                        Kirigami.FormData.label: i18n("Day markers:")
                        text: i18n("Show the date next to each day")
                    }
                    CheckBox {
                        id: dayMarkerColorCheck
                        text: i18n("Use colored day markers")
                        ToolTip.visible: hovered
                        ToolTip.text: i18n("Colors the graph's day markers and its sunrise and sunset icons, times and glow.")
                    }

                    }
                    Kirigami.FormLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.leftMargin: Kirigami.Units.gridUnit * 1
                    // a section title as on the Location page
                    Kirigami.Separator {
                        Kirigami.FormData.label: i18n("Weather Elements")
                        Kirigami.FormData.isSection: true
                    }
                    ConfigComboBox {
                        id: simpMetric1
                        Kirigami.FormData.label: i18n("Element 1:")
                        textRole: "text"
                        model: page.detailMetricOptions
                        Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_simpleHeaderMetric1)
                        onActivated: page.cfg_simpleHeaderMetric1 = page.detailMetricOptions[currentIndex].id
                    }
                    ConfigComboBox {
                        id: simpMetric2
                        Kirigami.FormData.label: i18n("Element 2:")
                        textRole: "text"
                        model: page.detailMetricOptions
                        Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_simpleHeaderMetric2)
                        onActivated: page.cfg_simpleHeaderMetric2 = page.detailMetricOptions[currentIndex].id
                    }
                    ConfigComboBox {
                        id: simpMetric3
                        Kirigami.FormData.label: i18n("Element 3:")
                        textRole: "text"
                        model: page.detailMetricOptions
                        Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_simpleHeaderMetric3)
                        onActivated: page.cfg_simpleHeaderMetric3 = page.detailMetricOptions[currentIndex].id
                    }
                    ConfigComboBox {
                        id: simpMetric4
                        Kirigami.FormData.label: i18n("Element 4:")
                        textRole: "text"
                        model: page.detailMetricOptions
                        Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_simpleHeaderMetric4)
                        onActivated: page.cfg_simpleHeaderMetric4 = page.detailMetricOptions[currentIndex].id
                    }
                    }
                }
            }

            // ── Panel (compact view) ──
            // The sizes and fonts, beside them the elements to add, and under both the
            // Panel Elements: what the panel shows, in order.
            ScrollView {
                id: panelTab
                contentWidth: availableWidth
                ColumnLayout {
                    width: panelTab.availableWidth
                    spacing: Kirigami.Units.largeSpacing

                    // the form at the left, the list at the right, ending level with
                    // the rows under them
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.gridUnit * 2
                        Kirigami.FormLayout {
                            id: panelForm
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: false
                            CheckBox {
                                id: panelColorCheck
                                Kirigami.FormData.label: i18n("Icon color:")
                                text: i18n("Use colored icons")
                                enabled: page.panelShowsIcon || page.panelShowsReading
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("Colors the weather icon and the icons before the readings.")
                            }
                            ConfigSpinBox {
                                id: panelIconSpin
                                Kirigami.FormData.label: i18n("Weather icon size:")
                                enabled: page.panelShowsIcon
                                from: 50
                                to: 200
                                stepSize: 5
                                textFromValue: (value, locale) => i18n("%1%", value)
                                valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                                ToolTip.visible: hovered
                                ToolTip.text: page.panelSizeTip
                            }
                            ConfigSpinBox {
                                id: panelFontSpin
                                Kirigami.FormData.label: i18n("Temperature font:")
                                enabled: page.panelShowsTemp
                                from: 20
                                to: 90
                                stepSize: 2
                                textFromValue: (value, locale) => i18n("%1%", value)
                                valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                                ToolTip.visible: hovered
                                ToolTip.text: page.panelSizeTip
                            }
                            ConfigComboBox {
                                id: panelTempWeightCombo
                                Kirigami.FormData.label: i18n("Temperature font style:")
                                enabled: page.panelShowsTemp
                                textRole: "text"
                                // the value is the font weight itself
                                model: [
                                    { text: i18n("Regular"),  value: 400 },
                                    { text: i18n("SemiBold"), value: 600 },
                                    { text: i18n("Bold"),     value: 700 }
                                ]
                                Component.onCompleted: {
                                    for (var i = 0; i < model.length; ++i)
                                        if (model[i].value === page.cfg_panelTempFontWeight) { currentIndex = i; break; }
                                }
                                onActivated: page.cfg_panelTempFontWeight = model[currentIndex].value
                            }
                            ConfigSpinBox {
                                id: panelSecondarySpin
                                Kirigami.FormData.label: i18n("Secondary font:")
                                enabled: page.panelShowsSecondary
                                from: 15
                                to: 70
                                stepSize: 2
                                textFromValue: (value, locale) => i18n("%1%", value)
                                valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("Everything on the panel but the weather icon and the temperature: the location, the condition and the readings. A percentage of the panel's thickness.")
                            }
                            ConfigComboBox {
                                id: panelSecondLineWeightCombo
                                Kirigami.FormData.label: i18n("Secondary font style:")
                                enabled: page.panelShowsSecondary
                                textRole: "text"
                                // the value is the font weight itself
                                model: [
                                    { text: i18n("Regular"),  value: 400 },
                                    { text: i18n("SemiBold"), value: 600 },
                                    { text: i18n("Bold"),     value: 700 }
                                ]
                                Component.onCompleted: {
                                    for (var i = 0; i < model.length; ++i)
                                        if (model[i].value === page.cfg_panelSecondLineFontWeight) { currentIndex = i; break; }
                                }
                                onActivated: page.cfg_panelSecondLineFontWeight = model[currentIndex].value
                            }
                            ConfigSpinBox {
                                id: panelSpacingSpin
                                Kirigami.FormData.label: i18n("Element spacing:")
                                enabled: page.panelShowsSeveral
                                from: -10
                                to: 40
                                stepSize: 1
                                textFromValue: (value, locale) => i18n("%1 px", value)
                                valueFromText: (text, locale) => parseInt(text.replace(/[^0-9-]/g, "") || "0", 10)
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("Pixels added to the space between the elements, on both sides of a separator, and between a vertical panel's lines. 0 keeps the panel's own spacing, which grows with its thickness; below 0 brings the elements closer.")
                            }
                            // the kind of separator, and beside it the mark itself: the
                            // bullet's shown, a custom one typed in
                            RowLayout {
                                Kirigami.FormData.label: i18n("Element separator:")
                                enabled: page.panelShowsSeveral
                                ConfigComboBox {
                                    id: panelSeparatorCombo
                                    textRole: "text"
                                    // the value is what main.xml stores
                                    model: [
                                        { text: i18n("None"),   value: 0 },
                                        { text: i18n("Bullet"), value: 1 },
                                        { text: i18n("Custom"), value: 2 }
                                    ]
                                    Component.onCompleted: currentIndex = Math.max(0, Math.min(2, page.cfg_panelElementSeparator))
                                    onActivated: page.cfg_panelElementSeparator = model[currentIndex].value
                                }
                                TextField {
                                    id: panelSeparatorField
                                    readonly property bool custom: page.cfg_panelElementSeparator === 2
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                                    horizontalAlignment: TextInput.AlignHCenter
                                    enabled: custom
                                    text: custom ? page.cfg_panelElementSeparatorText
                                                 : page.cfg_panelElementSeparator === 1 ? "•" : ""
                                    // one character, an emoji too: a new one typed replaces the
                                    // one there
                                    onTextEdited: {
                                        page.cfg_panelElementSeparatorText = page.lastCharacter(text.trim());
                                        text = Qt.binding(function () {
                                            return custom ? page.cfg_panelElementSeparatorText
                                                          : page.cfg_panelElementSeparator === 1 ? "•" : "";
                                        });
                                    }
                                    ToolTip.visible: hovered && custom
                                    ToolTip.text: i18n("Your own separator: a single character.")
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                        // the elements not on the panel, to add from
                        ColumnLayout {
                            id: addColumn
                            Layout.alignment: Qt.AlignTop
                            spacing: Kirigami.Units.smallSpacing
                            ScrollView {
                                id: addScroll
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 13
                                // Seven entries tall, however many there are: measured on an
                                // entry that isn't in the list (addRowProbe), so neither the
                                // count nor the last entry changes it.
                                Layout.preferredHeight: addRowProbe.implicitHeight * 7 + topPadding + bottomPadding
                                Component.onCompleted: if (background) background.visible = true
                                ListView {
                                    id: addList
                                    clip: true
                                    currentIndex: -1
                                    model: page.panelAvailable
                                    delegate: ItemDelegate {
                                        id: addItem
                                        required property var modelData
                                        required property int index
                                        width: ListView.view.width
                                        // the style pads the last entry of a list more at the
                                        // bottom; here they are all alike, seven to the list
                                        bottomPadding: Kirigami.Units.smallSpacing
                                        highlighted: ListView.isCurrentItem
                                        onClicked: addList.currentIndex = index
                                        onDoubleClicked: page.addPanelElement(modelData.id)
                                        contentItem: RowLayout {
                                            spacing: Kirigami.Units.largeSpacing
                                            PanelElementIcon { elementId: addItem.modelData.id }
                                            Label {
                                                Layout.fillWidth: true
                                                text: addItem.modelData.text
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                    Label {
                                        anchors.centerIn: parent
                                        width: parent.width - Kirigami.Units.largeSpacing * 2
                                        visible: addList.count === 0
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        text: i18n("Every element is on the panel.")
                                        opacity: 0.6
                                    }
                                }
                            }
                            Button {
                                id: addButton
                                Layout.alignment: Qt.AlignRight
                                text: i18n("Add to panel")
                                icon.name: "list-add"
                                enabled: addList.currentIndex >= 0 && addList.currentIndex < page.panelAvailable.length
                                onClicked: page.addPanelElement(page.panelAvailable[addList.currentIndex].id)
                            }
                        }
                    }

                    // the section title as the Location page has it: the line under it
                    // about a form's width
                    Kirigami.FormLayout {
                        Layout.fillWidth: true
                        Kirigami.Separator {
                            Kirigami.FormData.label: i18n("Panel Elements")
                            Kirigami.FormData.isSection: true
                        }
                        Item {
                            implicitWidth: Kirigami.Units.gridUnit * 11
                            implicitHeight: 0
                        }
                    }

                    // The rows (a Repeater, not a ListView — the page already scrolls).
                    // A row drags up or down from anywhere on it; the rows it passes
                    // make room, and it lands where it is let go.
                    ColumnLayout {
                        id: elementRows
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: panelModel
                            delegate: Rectangle {
                                id: elementRow
                                required property int index
                                required property string elementId
                                required property bool shown
                                readonly property bool dragged: rowDrag.active
                                // making room for the dragged row: a row's height up or down
                                readonly property real shift: {
                                    var f = page.panelDragFrom, t = page.panelDragTo;
                                    if (f < 0 || index === f) return 0;
                                    if (f < t && index > f && index <= t) return -page.panelDragPitch;
                                    if (f > t && index < f && index >= t) return page.panelDragPitch;
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
                                        enabled: page.panelRowsAnimate && elementRow.index !== page.panelDragFrom
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
                                    PanelElementIcon {
                                        elementId: elementRow.elementId
                                        opacity: elementRow.shown ? 1 : 0.4
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: page.panelElementName(elementRow.elementId)
                                        elide: Text.ElideRight
                                        opacity: elementRow.shown ? 1 : 0.5
                                    }
                                    ToolButton {
                                        icon.name: elementRow.shown ? "view-visible-symbolic" : "view-hidden-symbolic"
                                        onClicked: page.togglePanelElement(elementRow.index)
                                        ToolTip.visible: hovered
                                        ToolTip.text: elementRow.shown ? i18n("Hide on the panel") : i18n("Show on the panel")
                                        HoverHandler { cursorShape: Qt.ArrowCursor }
                                    }
                                    ToolButton {
                                        icon.name: "edit-delete"
                                        onClicked: page.removePanelElement(elementRow.index)
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
                                        if (active) {
                                            page.panelRowsAnimate = true;
                                            page.panelDragPitch = elementRow.height + elementRows.spacing;
                                            page.panelDragFrom = elementRow.index;
                                            page.panelDragTo = elementRow.index;
                                            return;
                                        }
                                        // dropped: everything takes its new place at once
                                        var from = page.panelDragFrom, to = page.panelDragTo;
                                        page.panelRowsAnimate = false;
                                        page.panelDragFrom = -1;
                                        page.panelDragTo = -1;
                                        if (from >= 0 && to >= 0 && from !== to) page.movePanelElement(from, to);
                                    }
                                    onActiveTranslationChanged: {
                                        if (!active || page.panelDragPitch <= 0) return;
                                        page.panelDragTo = Math.max(0, Math.min(panelModel.count - 1,
                                            elementRow.index + Math.round(activeTranslation.y / page.panelDragPitch)));
                                    }
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: page.panelShownIds.length === 0
                            wrapMode: Text.WordWrap
                            text: i18n("With no element shown, the panel shows the weather icon.")
                            opacity: 0.6
                        }
                    }
                }
            }
        }
    }
}
