/*
 * An element's icon in the settings' lists of elements, in the text colour: the
 * Meteocons reading icon the element shows (main.qml readingIcon) — a reading's own, a
 * cloud with the sun for the weather icon, a thermometer for the temperature, a
 * crescent for the moon, the sun of an afternoon for the date, a cloud with the sun for
 * the Detailed view's weather and temperature — and the icon theme's
 * for the location and the condition.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami
import "../icons/meteocons/readings/monochrome.js" as MonoReadings

Item {
    id: elementIcon
    property string elementId: ""

    readonly property var readings: ({
        icon: "partly-cloudy-day", temp: "thermometer", hiLo: "thermometer", precipRate: "umbrella", wind: "wind",
        feelsLike: "thermometer", humidity: "humidity", precipSum: "raindrops",
        uv: "uv-index", pressure: "barometer", sun: "sunrise", dewPoint: "thermometer-raindrop",
        snowSum: "snowflake", cloud: "cloudy", moon: "moon-waxing-crescent", date: "time-afternoon",
        weather: "partly-cloudy-day"
    })
    readonly property string reading: readings[elementId] || ""
    // the monochrome icon in the text colour, as a data URL (as main.qml readingIcon)
    readonly property string readingUrl: {
        var svg = reading ? MonoReadings.svg[reading] : "";
        return svg ? "data:image/svg+xml;utf8,"
                     + encodeURIComponent(svg.replace(/currentColor/g, "" + Kirigami.Theme.textColor)) : "";
    }

    implicitWidth: Kirigami.Units.iconSizes.smallMedium
    implicitHeight: implicitWidth
    // the reading icons' artwork leaves the edges of their box empty
    Image {
        visible: elementIcon.reading.length > 0
        anchors.centerIn: parent
        width: Math.round(parent.width * 1.6)
        height: width
        sourceSize: Qt.size(width, height)
        source: visible ? elementIcon.readingUrl : ""
    }
    Kirigami.Icon {
        visible: elementIcon.reading.length === 0
        anchors.fill: parent
        source: elementIcon.elementId === "location" ? "mark-location-symbolic" : "draw-text-symbolic"
    }
}
