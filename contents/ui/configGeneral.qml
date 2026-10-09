/*
 * General settings — units and refresh.
 * (Location → configLocation.qml; forecast days, graph detail and the per-layout
 *  header-info pickers → configAppearance.qml, inside the layout tabs.)
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Kirigami.FormLayout {
    id: page

    // cfg_* properties are auto-bound to the config keys by Plasma.
    property string cfg_temperatureUnit
    property bool   cfg_unitConfigured        // set once the unit is chosen (here or auto-picked)
    property alias  cfg_refreshInterval: refreshSpin.value
    property alias  cfg_showAlerts: alertsCheck.checked
    property int    cfg_minAlertSeverity
    property string cfg_windUnit
    property string cfg_pressureUnit
    property string cfg_precipUnit
    property int    cfg_clockFormat
    property bool   cfg_use24Hour             // the older checkbox, read only while clockFormat was never chosen

    // What "Follow system" resolves to, shown in its brackets. The same rules as
    // main.qml's units, windUnitApi, pressureUnitApi, precipImperial and use24Hour —
    // keep them in step.
    readonly property int  localeMeasurement: Qt.locale().measurementSystem
    readonly property bool localeUses12Hour:
        /[aA]/.test(Qt.locale().timeFormat(Locale.ShortFormat).replace(/'[^']*'/g, ""))
    // "Follow system (°C)": the short form is taken from the brackets of the option
    // the system resolves to, so it reads the same as that option in any language.
    function followSystem(options, value) {
        for (var i = 0; i < options.length; ++i) {
            if (options[i].value !== value) continue;
            var m = /\(([^()]*)\)\s*$/.exec(options[i].text);
            return i18n("Follow system (%1)", m ? m[1] : options[i].text);
        }
        return i18n("Follow system (%1)", value);
    }

    // ── Reset all settings ──
    // Every setting goes back to its default from main.xml (the configuration holds
    // each one's default as "<key>Default"), except what isn't a preference: where
    // the widget is — its location and the saved ones — and one-time markers whose
    // reset would run an old migration again.
    readonly property var keptOnReset: ["latitude", "longitude", "locationName", "locationTimezone",
                                        "locationConfigured", "savedLocations",
                                        "locationFontsSplit", "simpleHourly", "unitConfigured"]
    function resetAllSettings() {
        var c = Plasmoid.configuration, keys = c.keys(), has = {}, i, k;
        for (i = 0; i < keys.length; ++i) has[keys[i]] = true;
        for (i = 0; i < keys.length; ++i) {
            k = keys[i];
            // (the "…Default" entries have no default of their own, so they skip too)
            if (!has[k + "Default"] || keptOnReset.indexOf(k) >= 0) continue;
            c[k] = c[k + "Default"];
        }
        c.writeConfig();
        // Plasma saves only the open page, from its cfg_ values: take the new values
        // here too, or OK / Apply would write this page's old ones back.
        for (i = 0; i < keys.length; ++i)
            if (("cfg_" + keys[i]) in page) page["cfg_" + keys[i]] = c[keys[i]];
        syncControls();
    }
    // the lists pick their entry from cfg_ values only when asked
    function syncControls() {
        alertLevelCombo.sync();
        unitCombo.sync();
        windUnitCombo.sync();
        pressureUnitCombo.sync();
        precipUnitCombo.sync();
        clockFormatCombo.sync();
    }

    // breathing room so the settings don't sit flush against the top
    Item { implicitHeight: Kirigami.Units.gridUnit }

    ConfigSpinBox {
        id: refreshSpin
        Kirigami.FormData.label: i18n("Refresh interval (minutes):")
        from: 1
        to: 180
        stepSize: 5
    }
    RowLayout {
        Kirigami.FormData.label: i18n("Weather alerts:")
        CheckBox {
            id: alertsCheck
            text: i18n("Show weather alerts")
        }
        Kirigami.Icon {
            source: "dialog-information"
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            opacity: alertInfoHov.hovered ? 1.0 : 0.7
            HoverHandler { id: alertInfoHov }
            ToolTip.visible: alertInfoHov.hovered
            ToolTip.text: i18n("Weather alerts come from KDE Public Alert Server. It collects official weather warnings from agencies around the world so you get worldwide alerts without contacting, or exposing yourself to each individual agency.")
        }
    }
    ConfigComboBox {
        id: alertLevelCombo
        Kirigami.FormData.label: i18n("Show alerts at or above:")
        enabled: alertsCheck.checked   // only meaningful when alerts are on
        textRole: "text"
        // CAP severity ranks (see alertRank in main.qml): the floor for display
        model: [
            { text: i18n("Minor"),    value: 1 },
            { text: i18n("Moderate"), value: 2 },
            { text: i18n("Severe"),   value: 3 },
            { text: i18n("Extreme"),  value: 4 }
        ]
        function sync() {
            for (var i = 0; i < model.length; ++i)
                if (model[i].value === page.cfg_minAlertSeverity) { currentIndex = i; break; }
        }
        Component.onCompleted: sync()
        onActivated: page.cfg_minAlertSeverity = model[currentIndex].value
    }
    ConfigComboBox {
        id: unitCombo
        Kirigami.FormData.label: i18n("Temperature unit:")
        textRole: "text"
        model: {
            var opts = [
                { text: i18n("Celsius (°C)"),    value: "celsius"    },
                { text: i18n("Fahrenheit (°F)"), value: "fahrenheit" }
            ];
            // °F only where the locale is US imperial
            var sys = page.localeMeasurement === Locale.ImperialUSSystem ? "fahrenheit" : "celsius";
            return [{ text: page.followSystem(opts, sys), value: "system" }].concat(opts);
        }
        function sync() {
            for (var i = 0; i < model.length; ++i)
                if (model[i].value === page.cfg_temperatureUnit) { currentIndex = i; break; }
        }
        Component.onCompleted: sync()
        onActivated: { page.cfg_temperatureUnit = model[currentIndex].value; page.cfg_unitConfigured = true; }
    }
    ConfigComboBox {
        id: windUnitCombo
        Kirigami.FormData.label: i18n("Wind speed unit:")
        textRole: "text"
        model: {
            var opts = [
                { text: i18n("Kilometers per hour (km/h)"), value: "kmh" },
                { text: i18n("Miles per hour (mph)"),       value: "mph" },
                { text: i18n("Meters per second (m/s)"),    value: "ms"  },
                { text: i18n("Knots (kn)"),                 value: "kn"  },
                { text: i18n("Beaufort scale (bft)"),       value: "bft" }
            ];
            // mph wherever the locale is imperial (the UK's too)
            var sys = page.localeMeasurement === Locale.MetricSystem ? "kmh" : "mph";
            return [{ text: page.followSystem(opts, sys), value: "auto" }].concat(opts);
        }
        function sync() {
            for (var i = 0; i < model.length; ++i)
                if (model[i].value === page.cfg_windUnit) { currentIndex = i; break; }
        }
        Component.onCompleted: sync()
        onActivated: page.cfg_windUnit = model[currentIndex].value
    }
    ConfigComboBox {
        id: pressureUnitCombo
        Kirigami.FormData.label: i18n("Air pressure unit:")
        textRole: "text"
        model: {
            var opts = [
                { text: i18n("Hectopascals (hPa)"),            value: "hPa"  },
                { text: i18n("Inches of mercury (inHg)"),      value: "inHg" },
                { text: i18n("Millimeters of mercury (mmHg)"), value: "mmHg" }
            ];
            // inHg where the locale is US imperial
            var sys = page.localeMeasurement === Locale.ImperialUSSystem ? "inHg" : "hPa";
            return [{ text: page.followSystem(opts, sys), value: "auto" }].concat(opts);
        }
        function sync() {
            for (var i = 0; i < model.length; ++i)
                if (model[i].value === page.cfg_pressureUnit) { currentIndex = i; break; }
        }
        Component.onCompleted: sync()
        onActivated: page.cfg_pressureUnit = model[currentIndex].value
    }
    ConfigComboBox {
        id: precipUnitCombo
        Kirigami.FormData.label: i18n("Precipitation unit:")
        textRole: "text"
        model: {
            var opts = [
                { text: i18n("Millimeters (mm)"), value: "mm" },
                { text: i18n("Inches (in)"),      value: "in" }
            ];
            // inches where the locale is US imperial (the UK measures rain in mm)
            var sys = page.localeMeasurement === Locale.ImperialUSSystem ? "in" : "mm";
            return [{ text: page.followSystem(opts, sys), value: "auto" }].concat(opts);
        }
        function sync() {
            for (var i = 0; i < model.length; ++i)
                if (model[i].value === page.cfg_precipUnit) { currentIndex = i; break; }
        }
        Component.onCompleted: sync()
        onActivated: page.cfg_precipUnit = model[currentIndex].value
        ToolTip.visible: hovered
        ToolTip.text: i18n("Snowfall follows it: centimeters with millimeters, inches with inches.")
    }
    ConfigComboBox {
        id: clockFormatCombo
        Kirigami.FormData.label: i18n("Clock format:")
        textRole: "text"
        // value is the stored mode (main.qml clockFormat), not the index
        model: [
            { text: i18n("Follow system (%1)", page.localeUses12Hour ? i18nc("short for 12-hour time", "12h")
                                                                     : i18nc("short for 24-hour time", "24h")),
              value: 0 },
            { text: i18n("12-hour time"),          value: 1 },
            { text: i18n("24-hour time"),          value: 2 }
        ]
        // never chosen: what main.qml derives from the older checkbox
        function sync() {
            var m = page.cfg_clockFormat >= 0 ? page.cfg_clockFormat : (page.cfg_use24Hour ? 0 : 1);
            for (var i = 0; i < model.length; ++i)
                if (model[i].value === m) { currentIndex = i; break; }
        }
        Component.onCompleted: sync()
        onActivated: page.cfg_clockFormat = model[currentIndex].value
    }

    Item { Kirigami.FormData.isSection: true }
    Button {
        text: i18n("Reset All Settings…")
        icon.name: "edit-reset"
        onClicked: resetPrompt.open()
    }
    Kirigami.PromptDialog {
        id: resetPrompt
        title: i18n("Reset all settings?")
        subtitle: i18n("Every setting of this widget goes back to its default. Your location and saved locations are kept.")
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action {
                text: i18n("Reset")
                icon.name: "edit-reset"
                onTriggered: { page.resetAllSettings(); resetPrompt.close(); }
            },
            Kirigami.Action {
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                onTriggered: resetPrompt.close()
            }
        ]
    }
}
