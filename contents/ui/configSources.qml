/*
 * Sources — where the data comes from, and who to credit for it.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Attribution is not decoration here: MET Norway's terms REQUIRE their data be
 * credited wherever it is shown, so the met.no line has to exist somewhere the
 * user can reach. The provider objects carry their own `attribution` and
 * `attributionUrl` strings, and this page renders whatever is registered rather
 * than hard-coding a list — add a provider and its credit appears here.
 *
 * Deliberately NOT called "About": the Plasma shell appends its own About page to
 * every applet's config dialog (hard-coded in the shell's AppletConfiguration.qml,
 * with no opt-out), which already covers the name, version, author and licence.
 * Two tabs called "About" would be worse than one with an accurate name, so this
 * one carries only what the shell's does not — the data-source credits.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "providers"

ColumnLayout {
    id: page
    spacing: Kirigami.Units.largeSpacing

    // The config pages run in their own QML context — no weatherRoot to borrow —
    // so instantiate the providers here just to read their credit strings. They
    // are inert QtObjects until something calls buildUrl/parse.
    OpenMeteo { id: openMeteoProvider }
    MetNo     { id: metNoProvider }
    readonly property var creditProviders: [openMeteoProvider, metNoProvider]

    Item { implicitHeight: Kirigami.Units.smallSpacing }

    Kirigami.Heading {
        level: 2
        text: i18n("Weather data")
    }
    Label {
        text: i18n("The active source is chosen with the toolbar button in the widget, and applies to every saved location.")
        opacity: 0.8
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Repeater {
        model: page.creditProviders
        delegate: RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Label {
                text: "•"
                opacity: 0.6
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                text: "<a href=\"" + modelData.attributionUrl + "\">"
                      + modelData.attribution + "</a>"
                onLinkActivated: function (link) { Qt.openUrlExternally(link); }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }

    Kirigami.Separator { Layout.fillWidth: true }

    Kirigami.Heading {
        level: 2
        text: i18n("Other sources")
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.RichText
        opacity: 0.9
        text: "• " + i18n("Severe-weather alerts via the <a href=\"https://invent.kde.org/webapps/foss-public-alert-server\">KDE FOSS Public Alert Server</a>.")
              + "<br>• " + i18n("Place search via <a href=\"https://open-meteo.com\">Open-Meteo geocoding</a>; location auto-detect via <a href=\"https://mullvad.net\">Mullvad</a>.")
              + "<br>• " + i18n("Icons derived from <a href=\"https://github.com/basmilius/weather-icons\">Meteocons</a> by Bas Milius (MIT).")
        onLinkActivated: function (link) { Qt.openUrlExternally(link); }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Kirigami.Separator { Layout.fillWidth: true }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: i18n("Each data source keeps its own licence — see the links above.")
    }

    Item { Layout.fillHeight: true }
}
