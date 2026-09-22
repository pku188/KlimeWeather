/*
 * Config categories.
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Location")
        icon: "mark-location"
        source: "configLocation.qml"
    }
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
    // Not optional garnish: MET Norway's terms require their data be credited
    // where it's shown, so the attribution needs a home in the UI. Named "Sources"
    // rather than "About" because the Plasma shell always appends an About page of
    // its own — see configSources.qml.
    ConfigCategory {
        name: i18n("Sources")
        icon: "documentinfo"
        source: "configSources.qml"
    }
}
