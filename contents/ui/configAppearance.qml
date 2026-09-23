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

Item {
    id: page
    // shared by the three scroll-animation spins below
    readonly property string slideTip: i18n("How long the graph takes to glide to its new position after one scroll notch. A bigger scroll step covers more ground, so it wants a longer glide to feel the same. 0 jumps straight there.")

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
    property alias cfg_dailyIconSize:      dailySpin.value
    property alias cfg_dailyTempFontSize:  dailyTempSpin.value
    property alias cfg_windArrowSize:      windArrowSpin.value
    property alias cfg_showDayDate:        dayDateCheck.checked
    property alias cfg_hourlyIconSize:     hourlySpin.value
    property alias cfg_hourlyTempFontSize: hourlyTempSpin.value
    property alias cfg_hourlyCardFontSize: hourlyCardSpin.value
    property alias cfg_conditionFontSize:  condFontSpin.value
    property alias cfg_locationFontSize:   locFontSpin.value
    property alias cfg_providerFontSize:   providerFontSpin.value
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
    property alias cfg_panelDetailed:      panelDetailedCheck.checked
    property alias cfg_panelSecondLine:    panelSecondLineCombo.currentIndex
    property alias cfg_panelConditionPercent:  panelConditionSpin.value
    property alias cfg_panelSecondLinePercent: panelSecondLineSpin.value

    // shared options for the header-metric dropdowns (id ↔ label)
    readonly property var metricOptions: [
        { text: i18n("None"),                    id: "none"       },
        { text: i18n("Feels like"),              id: "feelsLike"  },
        { text: i18n("Humidity"),                id: "humidity"   },
        { text: i18n("UV Index"),                id: "uv"         },
        { text: i18n("Precipitation rate"),      id: "precipRate" },
        { text: i18n("Precipitation sum"),       id: "precipSum"  },
        { text: i18n("Wind"),                    id: "wind"       },
        { text: i18n("Snowfall today"),          id: "snowSum"    },
        { text: i18n("Cloud cover"),             id: "cloud"      },
        { text: i18n("Air pressure"),            id: "pressure"   }
    ]
    function findMetricIndex(arr, id) {
        for (var i = 0; i < arr.length; ++i)
            if (arr[i].id === id) return i;
        return 0;
    }
    function detailMetricIndexOf(id)  { return findMetricIndex(detailMetricOptions,  id) }
    function hourlyMetricIndexOf(id)  { return findMetricIndex(hourlyMetricOptions,  id) }
    // Weather Elements options, shared by the card and graph headers: the base set
    // plus sunrise/sunset.
    readonly property var detailMetricOptions: metricOptions.concat([
        { text: i18n("Sunrise / sunset"), id: "sun" }
    ])
    // Per-hour options for the Detailed hourly-card readouts (chance/amount are
    // per-hour, unlike the header's daily-total precip/snow sums).
    readonly property var hourlyMetricOptions: [
        { text: i18n("None"),          id: "none"      },
        { text: i18n("Wind"),          id: "wind"      },
        { text: i18n("Wind + gust"),   id: "windGust"  },
        { text: i18n("Precip chance"), id: "precip"    },
        { text: i18n("Precip amount"), id: "precipAmt" },
        { text: i18n("Snowfall"),      id: "snow"      },
        { text: i18n("Feels like"),    id: "feelsLike" },
        { text: i18n("Humidity"),      id: "humidity"  },
        { text: i18n("UV Index"),      id: "uv"        },
        { text: i18n("Cloud cover"),   id: "cloud"     },
        { text: i18n("Air pressure"),  id: "pressure"  }
    ]

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

                    }
                    Kirigami.FormLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.leftMargin: Kirigami.Units.gridUnit * 4
                        Layout.topMargin: 0   // header has no intrinsic top padding now, so no negative pull needed (was clipping the title)
                        RowLayout {
                            // inline section header (see the matching note in the Hourly cards section)
                            Kirigami.FormData.isSection: true
                            Layout.fillWidth: true
                            Kirigami.Heading {
                                level: 5
                                text: i18n("Weather Elements (up to 4)")
                            }
                            Kirigami.Icon {
                                source: "documentinfo"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                                opacity: headerInfoHover.hovered ? 1.0 : 0.65
                                HoverHandler { id: headerInfoHover; cursorShape: Qt.PointingHandCursor }
                                ToolTip.visible: headerInfoHover.hovered
                                ToolTip.text: i18n("The element header readouts follow whichever hour you hover.")
                            }
                            Item { Layout.fillWidth: true }
                        }
                        ConfigComboBox {
                            id: detMetric1
                            Kirigami.FormData.label: i18n("Element 1:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric1)
                            onActivated: page.cfg_headerMetric1 = page.detailMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: detMetric2
                            Kirigami.FormData.label: i18n("Element 2:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric2)
                            onActivated: page.cfg_headerMetric2 = page.detailMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: detMetric3
                            Kirigami.FormData.label: i18n("Element 3:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric3)
                            onActivated: page.cfg_headerMetric3 = page.detailMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: detMetric4
                            Kirigami.FormData.label: i18n("Element 4:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric4)
                            onActivated: page.cfg_headerMetric4 = page.detailMetricOptions[currentIndex].id
                        }
                        Button {
                            text: i18n("Reset to none")
                            icon.name: "edit-clear-all"
                            onClicked: {
                                page.cfg_headerMetric1 = "none"; detMetric1.currentIndex = 0;
                                page.cfg_headerMetric2 = "none"; detMetric2.currentIndex = 0;
                                page.cfg_headerMetric3 = "none"; detMetric3.currentIndex = 0;
                                page.cfg_headerMetric4 = "none"; detMetric4.currentIndex = 0;
                            }
                        }

                        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing * 2 }
                        RowLayout {
                            Kirigami.FormData.isSection: true
                            Layout.fillWidth: true
                            Kirigami.Heading {
                                level: 5
                                text: i18n("Hourly cards (2 elements)")
                            }
                            Kirigami.Icon {
                                source: "documentinfo"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                                opacity: hourlyInfoHover.hovered ? 1.0 : 0.65
                                HoverHandler { id: hourlyInfoHover; cursorShape: Qt.PointingHandCursor }
                                ToolTip.visible: hourlyInfoHover.hovered
                                ToolTip.text: i18n("Shows the main metric, or the fallback on hours the main one has nothing to show.")
                            }
                            Item { Layout.fillWidth: true }
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
                        }
                        ConfigComboBox {
                            id: hourMetric1Fallback2
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric1Fallback2)
                            onActivated: page.cfg_hourlyMetric1Fallback2 = page.hourlyMetricOptions[currentIndex].id
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
                        }
                        ConfigComboBox {
                            id: hourMetric2Fallback2
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric2Fallback2)
                            onActivated: page.cfg_hourlyMetric2Fallback2 = page.hourlyMetricOptions[currentIndex].id
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
                        // the day pills and the graph grow to the left; the location
                        // above them follows the first pill (see HeaderRightBlock)
                        from: 3
                        to: 5
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

                    }
                    Kirigami.FormLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.leftMargin: Kirigami.Units.gridUnit * 1
                    RowLayout {
                        // inline section header (mirrors the Cards tab)
                        Kirigami.FormData.isSection: true
                        Layout.fillWidth: true
                        Kirigami.Heading {
                            level: 5
                            text: i18n("Weather Elements (up to 4)")
                        }
                        Item { Layout.fillWidth: true }
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
                    Button {
                        text: i18n("Reset to none")
                        icon.name: "edit-clear-all"
                        onClicked: {
                            page.cfg_simpleHeaderMetric1 = "none"; simpMetric1.currentIndex = 0;
                            page.cfg_simpleHeaderMetric2 = "none"; simpMetric2.currentIndex = 0;
                            page.cfg_simpleHeaderMetric3 = "none"; simpMetric3.currentIndex = 0;
                            page.cfg_simpleHeaderMetric4 = "none"; simpMetric4.currentIndex = 0;
                        }
                    }
                    }
                }
            }

            // ── Panel (compact view) ──
            ScrollView {
                contentWidth: availableWidth
                Kirigami.FormLayout {
                    ConfigSpinBox {
                        id: panelIconSpin
                        Kirigami.FormData.label: i18n("Panel icon size:")
                        from: 50
                        to: 200
                        stepSize: 5
                    }
                    ConfigSpinBox {
                        id: panelFontSpin
                        Kirigami.FormData.label: i18n("Panel temperature font:")
                        from: 20
                        to: 90
                        stepSize: 2
                    }
                    CheckBox {
                        id: panelColorCheck
                        Kirigami.FormData.label: i18n("Icon color:")
                        text: i18n("Use colored icon")
                    }
                    CheckBox {
                        id: panelDetailedCheck
                        Kirigami.FormData.label: i18n("Panel:")
                        text: i18n("Detailed View")
                    }
                    ConfigComboBox {
                        id: panelSecondLineCombo
                        enabled: panelDetailedCheck.checked
                        // index maps directly to panelSecondLine (0 = H/L, 1 = precip, 2 = wind)
                        model: [
                            i18n("High / low temperature"),
                            i18n("Precipitation (chance / amount)"),
                            i18n("Wind (speed / gust)")
                        ]
                    }
                    ConfigSpinBox {
                        id: panelConditionSpin
                        enabled: panelDetailedCheck.checked
                        Kirigami.FormData.label: i18n("Condition font:")
                        from: 15
                        to: 70
                        stepSize: 2
                    }
                    ConfigSpinBox {
                        id: panelSecondLineSpin
                        enabled: panelDetailedCheck.checked
                        Kirigami.FormData.label: i18n("Second metric font:")
                        from: 15
                        to: 70
                        stepSize: 2
                    }
                }
            }
        }
    }
}
