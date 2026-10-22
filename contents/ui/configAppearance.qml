/*
 * Appearance settings — a Common tab for what the layouts share (and beside it the
 * header's Weather Elements), then one tab each for the Daily forecast (the card
 * layout), the Weather graph, the Detailed view and the panel.
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import "panelelements.js" as PanelElements
import "detailedelements.js" as DetailedElements

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
    property string cfg_readingIconPack
    property string cfg_readingIconDir
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
    property int   cfg_locationFontWeight
    property alias cfg_providerFontSize:   providerFontSpin.value
    property alias cfg_toolbarIconSize:    toolbarIconSpin.value
    property alias cfg_layoutButtonFontSize: layoutButtonSpin.value
    property alias cfg_dayPillFontSize:      dayPillSpin.value
    // Detailed view
    property alias cfg_detailedViewDays:     detailedDaysSpin.value
    property alias cfg_detailedViewFontSize: detailedFontSpin.value
    property int   cfg_detailedViewFontWeight
    property alias cfg_detailedEntrancePercent: detailedEntranceSpin.value
    property string cfg_detailedViewElements
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
    property alias cfg_simpleDailyDays:         graphDaysSpin.value
    property alias cfg_graphScrollHoursDay:     graphScrollDaySpin.value
    property alias cfg_graphScrollHoursDetail:  graphScrollDetailSpin.value
    property alias cfg_graphScrollHoursWide:    graphScrollWideSpin.value
    property alias cfg_graphSlideMsDetail:      graphSlideDetailSpin.value
    property alias cfg_graphSlideMsDay:         graphSlideDaySpin.value
    property alias cfg_graphSlideMsWide:        graphSlideWideSpin.value
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
    property alias cfg_dailyHiLoColored:      dailyHiLoColorCheck.checked
    property alias cfg_hourlyIconsColored:    hourlyIconColorCheck.checked
    property alias cfg_hourlyValuesColored:   hourlyValueColorCheck.checked
    property alias cfg_hourlyPrecipGradient:  hourlyPrecipGradientCheck.checked
    property alias cfg_detailedIconsColored:  detailedIconColorCheck.checked
    property alias cfg_detailedValuesColored: detailedValueColorCheck.checked
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
        { text: i18n("Sunrise / sunset"),       id: "sun"        },
        { text: i18n("Date"),                   id: "date"       },
        { text: i18n("Moon phase"),             id: "moon"       }
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
        { text: i18n("Air pressure"),  id: "pressure"  },
        { text: i18n("Date"),          id: "date"      }
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
        case "date":       return i18n("Date");
        case "moon":       return i18n("Moon phase");
        }
        return id;
    }
    // the Panel Elements' editable list (Panel tab)
    ElementsModel {
        id: panelEdit
        allIds: PanelElements.all
        parse: function (json) {
            return PanelElements.parse(json, page.cfg_panelDisplay, page.cfg_panelDetailed, page.cfg_panelSecondLine);
        }
        stringify: PanelElements.stringify
        nameOf: page.panelElementName
        json: page.cfg_panelElements
        onEdited: (json) => page.cfg_panelElements = json
    }
    // the ids shown on the panel, for the settings that apply to them
    readonly property var panelShownIds: panelEdit.shownIds
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

    // ── Detailed view Elements (cfg_detailedViewElements) ──
    // Each element's name: the sun and the moon, and a reading's as in the Weather
    // Elements' list.
    function detailedElementName(id) {
        // the Detailed view's own, not a Weather Element of the other layouts
        if (id === "weather") return i18n("Weather and temperature");
        for (var i = 0; i < detailMetricOptions.length; ++i)
            if (detailMetricOptions[i].id === id) return detailMetricOptions[i].text;
        return id;
    }
    ElementsModel {
        id: detailedEdit
        allIds: DetailedElements.all
        parse: DetailedElements.parse
        stringify: DetailedElements.stringify
        nameOf: page.detailedElementName
        json: page.cfg_detailedViewElements
        onEdited: (json) => page.cfg_detailedViewElements = json
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

    FolderDialog {
        id: iconFolderDialog
        title: i18n("Choose icon folder")
        onAccepted: page.cfg_customIconDir = selectedFolder
    }
    FolderDialog {
        id: readingFolderDialog
        title: i18n("Choose icon folder")
        onAccepted: page.cfg_readingIconDir = selectedFolder
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton { text: i18n("Common") }
            TabButton { text: i18n("Daily forecast") }
            TabButton { text: i18n("Weather graph") }
            TabButton { text: i18n("Detailed view") }
            TabButton { text: i18n("Panel") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // ── Common to the layouts ──
            // The header is built the same way in every layout — same icon,
            // temperature, condition, location, source and buttons, in the same spots —
            // so these size them in all of them rather than three times over. Beside
            // them, the header's Weather Elements.
            ScrollView {
                contentWidth: availableWidth
                RowLayout {
                    spacing: Kirigami.Units.gridUnit * 2
                    Kirigami.FormLayout {
                        Layout.alignment: Qt.AlignTop
                        // The condition-icon pack applies to both layouts and the panel,
                        // which is what makes it a Common setting.
                        ConfigComboBox {
                            id: iconPackCombo
                            Kirigami.FormData.label: i18n("Weather icon pack:")
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
                        // The colour icons before the readings, in every view that shows them
                        // in colour; each view's "Use colored icons" still picks monochrome.
                        ConfigComboBox {
                            id: readingPackCombo
                            Kirigami.FormData.label: i18n("Element icon pack:")
                            textRole: "text"
                            // each option stores its pack id (main.qml readingIconPack)
                            model: [
                                { text: i18n("Meteocons (flat)"), id: "meteocons-flat" },
                                { text: i18n("Meteocons (line)"), id: "meteocons-line" },
                                { text: i18n("Custom folder…"),   id: "custom"         }
                            ]
                            Component.onCompleted: {
                                for (var i = 0; i < model.length; ++i)
                                    if (model[i].id === page.cfg_readingIconPack) { currentIndex = i; break; }
                            }
                            onActivated: page.cfg_readingIconPack = model[currentIndex].id
                            ToolTip.text: i18n("The icons of the Weather Elements wherever they are colored: in the header, on the hourly cards, in the Detailed view, on the panel and at the Weather graph's sunrise and sunset. Each of those has its own \"Use colored icons\"; without it, the icons are monochrome.")
                        }
                        RowLayout {
                            Kirigami.FormData.label: i18n("Custom folder:")
                            visible: page.cfg_readingIconPack === "custom"
                            Button {
                                text: i18n("Choose…")
                                icon.name: "folder-open"
                                onClicked: readingFolderDialog.open()
                            }
                            Label {
                                Layout.fillWidth: true
                                // as the icon pack's: a long path can't widen the form
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                                elide: Text.ElideMiddle
                                opacity: 0.7
                                text: page.cfg_readingIconDir
                                      ? page.cfg_readingIconDir.replace(/^file:\/\//, "")
                                      : i18n("(none selected)")
                            }
                        }
                        Label {
                            visible: page.cfg_readingIconPack === "custom"
                            Layout.fillWidth: true
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                            wrapMode: Text.WordWrap
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            text: i18n("Folder with SVGs named like the bundled set (thermometer.svg, humidity.svg, wind.svg, …); an icon missing from it shows Meteocons' flat one. Tip: copy contents/icons/meteocons/readings/flat/ as a starting point, then edit.")
                        }
                        ConfigComboBox {
                            id: animationCombo
                            Kirigami.FormData.label: i18n("Weather icon animation:")
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
                            ToolTip.text: i18n("Which icons move, in every layout: the header's, then the Daily forecast's daily tabs, then the hourly cards and the Weather graph's hour icons.")
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
                        ConfigComboBox {
                            id: locWeightCombo
                            Kirigami.FormData.label: i18n("Location font style:")
                            textRole: "text"
                            // the value is the font weight itself
                            model: [
                                { text: i18n("Regular"),  value: 400 },
                                { text: i18n("SemiBold"), value: 600 },
                                { text: i18n("Bold"),     value: 700 }
                            ]
                            Component.onCompleted: {
                                for (var i = 0; i < model.length; ++i)
                                    if (model[i].value === page.cfg_locationFontWeight) { currentIndex = i; break; }
                            }
                            onActivated: page.cfg_locationFontWeight = model[currentIndex].value
                            ToolTip.text: i18n("SemiBold needs a font that has it. Where yours doesn't, the nearest weight it has is used — normally Bold.")
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
                            ToolTip.text: i18n("Sizes the buttons in the popup's corners: keep open, zoom and refresh.")
                        }
                        ConfigSpinBox {
                            id: layoutButtonSpin
                            Kirigami.FormData.label: i18n("Layout buttons font:")
                            from: 8
                            to: 32
                            stepSize: 1
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Sizes the Forecast, Graph and Details buttons under the location.")
                        }
                        ConfigSpinBox {
                            id: dayPillSpin
                            Kirigami.FormData.label: i18n("Day buttons font:")
                            from: 8
                            to: 32
                            stepSize: 1
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Sizes the day buttons of the Detailed view and the Weather graph.")
                        }
                        ConfigSpinBox {
                            id: windArrowSpin
                            Kirigami.FormData.label: i18n("Wind direction arrow:")
                            from: 10
                            to: 48
                            stepSize: 1
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Size of the arrow that follows a wind reading: on the hourly cards, in the Weather Elements and in the Detailed view.")
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
                        ConfigSpinBox {
                            id: elementsFontSpin
                            Kirigami.FormData.label: i18n("Font:")
                            from: 7
                            to: 32
                            stepSize: 1
                        }
                        ConfigComboBox {
                            id: elementsWeightCombo
                            Kirigami.FormData.label: i18n("Font style:")
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
                            ToolTip.text: i18n("SemiBold needs a font that has it. Where yours doesn't, the nearest weight it has is used — normally Bold.")
                        }
                        ConfigComboBox {
                            id: elementsStyleCombo
                            Kirigami.FormData.label: i18n("Style:")
                            textRole: "text"
                            model: [
                                { text: i18n("Icons"), value: 1 },
                                { text: i18n("Text"),  value: 0 }
                            ]
                            Component.onCompleted: currentIndex = page.cfg_headerElementsStyle === 0 ? 1 : 0
                            onActivated: page.cfg_headerElementsStyle = model[currentIndex].value
                            ToolTip.text: i18n("Icons shows each element's icon — the one the hourly cards use — in place of its label.")
                        }
                        CheckBox {
                            id: readingColorCheck
                            Kirigami.FormData.label: i18n("Icon color:")
                            // the header's Weather Elements have icons only in the Icons style
                            enabled: page.cfg_headerElementsStyle !== 0
                            text: i18n("Use colored icons")
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Colors the icons of the Weather Elements in the header.")
                        }
                        CheckBox {
                            id: weatherColorsCheck
                            Kirigami.FormData.label: i18n("Font color:")
                            text: i18n("Use weather-specific color")
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Colors the values of the Weather Elements in the header — blue for precipitation, green to red for the UV index, and so on. Off, they follow your theme.")
                        }
                    }
                }
            }

            // ── Daily forecast (the card layout) ──
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
                            Kirigami.FormData.label: i18n("Daily tabs:")
                            text: i18n("Show the date under each day")
                        }
                        CheckBox {
                            id: dailyHiLoColorCheck
                            text: i18n("Use colored H/L")
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("The high temperature in orange and the low in blue. Off, they follow your theme.")
                        }
                        CheckBox {
                            id: hourlyFirstCheck
                            Kirigami.FormData.label: i18n("Hourly cards:")
                            text: i18n("Show above the daily tabs")
                        }
                        CheckBox {
                            id: hourlyIconColorCheck
                            text: i18n("Use colored icons")
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Colors the icons before the hourly cards' readings.")
                        }
                        CheckBox {
                            id: hourlyValueColorCheck
                            text: i18n("Use weather-specific color")
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Colors the hourly cards' readings — blue for precipitation, green to red for the UV index, and so on. Off, they follow your theme.")
                        }
                        CheckBox {
                            id: hourlyPrecipGradientCheck
                            text: i18n("Show precipitation gradient")
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Tints a card blue from its lower left corner where rain is likely, and white from its upper right where snow is: the likelier, the stronger.")
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
                            ToolTip.text: page.elementsHoverTip
                        }
                        ConfigComboBox {
                            id: detMetric2
                            Kirigami.FormData.label: i18n("Element 2:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric2)
                            onActivated: page.cfg_headerMetric2 = page.detailMetricOptions[currentIndex].id
                            ToolTip.text: page.elementsHoverTip
                        }
                        ConfigComboBox {
                            id: detMetric3
                            Kirigami.FormData.label: i18n("Element 3:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric3)
                            onActivated: page.cfg_headerMetric3 = page.detailMetricOptions[currentIndex].id
                            ToolTip.text: page.elementsHoverTip
                        }
                        ConfigComboBox {
                            id: detMetric4
                            Kirigami.FormData.label: i18n("Element 4:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric4)
                            onActivated: page.cfg_headerMetric4 = page.detailMetricOptions[currentIndex].id
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
                            ToolTip.text: i18n("Shows the main metric, or the fallback on hours the main one has nothing to show.")
                        }
                        ConfigComboBox {
                            id: hourMetric1Fallback2
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric1Fallback2)
                            onActivated: page.cfg_hourlyMetric1Fallback2 = page.hourlyMetricOptions[currentIndex].id
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
                            ToolTip.text: i18n("Shows the main metric, or the fallback on hours the main one has nothing to show.")
                        }
                        ConfigComboBox {
                            id: hourMetric2Fallback2
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric2Fallback2)
                            onActivated: page.cfg_hourlyMetric2Fallback2 = page.hourlyMetricOptions[currentIndex].id
                            ToolTip.text: i18n("Shows the main metric, or the fallback on hours the main one has nothing to show.")
                        }
                    }
                }
            }

            // ── Weather graph ──
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

            // ── Detailed view ──
            // Its forecast days and font, beside them the elements to add, and under
            // both the Detailed view Elements: what it shows, in order — two to the
            // first row, three to every row after it.
            ScrollView {
                id: detailedTab
                contentWidth: availableWidth
                ColumnLayout {
                    width: detailedTab.availableWidth
                    spacing: Kirigami.Units.largeSpacing

                    // the form at the left, the list at the right, ending level with
                    // the rows under them
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.gridUnit * 2
                        Kirigami.FormLayout {
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: false
                            ConfigSpinBox {
                                id: detailedDaysSpin
                                Kirigami.FormData.label: i18n("Forecast days:")
                                from: 1
                                to: 7
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("The day buttons, and how far the view scrolls.")
                            }
                            ConfigSpinBox {
                                id: detailedFontSpin
                                Kirigami.FormData.label: i18n("Element font:")
                                from: 8
                                to: 32
                                stepSize: 1
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("The elements' names and values; their icons grow with it.")
                            }
                            ConfigComboBox {
                                id: detailedWeightCombo
                                Kirigami.FormData.label: i18n("Element font style:")
                                textRole: "text"
                                // the values' weight; the value is the font weight itself
                                model: [
                                    { text: i18n("Regular"),  value: 400 },
                                    { text: i18n("SemiBold"), value: 600 },
                                    { text: i18n("Bold"),     value: 700 }
                                ]
                                Component.onCompleted: {
                                    for (var i = 0; i < model.length; ++i)
                                        if (model[i].value === page.cfg_detailedViewFontWeight) { currentIndex = i; break; }
                                }
                                onActivated: page.cfg_detailedViewFontWeight = model[currentIndex].value
                            }
                            CheckBox {
                                id: detailedIconColorCheck
                                Kirigami.FormData.label: i18n("Element icon color:")
                                text: i18n("Use colored icons")
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("Colors the elements' icons, and the sun on its arc.")
                            }
                            CheckBox {
                                id: detailedValueColorCheck
                                Kirigami.FormData.label: i18n("Element font color:")
                                text: i18n("Use weather-specific color")
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("Colors the elements' values — blue for precipitation, green to red for the UV index, and so on. Off, they follow your theme.")
                            }
                            ConfigSpinBox {
                                id: detailedEntranceSpin
                                Kirigami.FormData.label: i18n("Element entrance duration:")
                                // a percentage of the original pace, as the cards' entrance
                                // (see entrancePace in DetailedView.qml)
                                from: 0
                                to: 150
                                stepSize: 10
                                textFromValue: (value, locale) => i18n("%1%", value)
                                valueFromText: (text, locale) => parseInt(text.replace(/[^0-9]/g, "") || "0", 10)
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("How long the elements take to come in when the view opens, as a percentage of the original pace: lower is faster, 0 turns the animation off.")
                            }
                        }
                        Item { Layout.fillWidth: true }
                        // the elements not in the view, to add from
                        ElementAddList {
                            Layout.alignment: Qt.AlignTop
                            elements: detailedEdit
                            buttonText: i18n("Add to view")
                            emptyText: i18n("Every element is in the view.")
                        }
                    }

                    // the section title as the Location page has it
                    Kirigami.FormLayout {
                        Layout.fillWidth: true
                        Kirigami.Separator {
                            Kirigami.FormData.label: i18n("Detailed view Elements")
                            Kirigami.FormData.isSection: true
                        }
                        Item {
                            implicitWidth: Kirigami.Units.gridUnit * 11
                            implicitHeight: 0
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        wrapMode: Text.WordWrap
                        text: i18n("The view shows its elements in this order, three to a row.")
                        opacity: 0.7
                    }
                    ElementRows {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        elements: detailedEdit
                        nameOf: page.detailedElementName
                        hideText: i18n("Hide in the view")
                        showText: i18n("Show in the view")
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
                        ElementAddList {
                            Layout.alignment: Qt.AlignTop
                            elements: panelEdit
                            buttonText: i18n("Add to panel")
                            emptyText: i18n("Every element is on the panel.")
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

                    ElementRows {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        elements: panelEdit
                        nameOf: page.panelElementName
                        hideText: i18n("Hide on the panel")
                        showText: i18n("Show on the panel")
                        emptyText: i18n("With no element shown, the panel shows the weather icon.")
                    }
                }
            }
        }
    }
}
