/*
 * One element of the Detailed view (see DetailedView), for the hour the view shows:
 *  - a reading: its icon, and beside it its name over its value — the name level
 *    with the icon's top, the value with its bottom;
 *  - the sun: the day's length over sunrise and sunset, an arc between them with
 *    the sun where it is at that hour, and how long until it next rises or sets;
 *  - the moon: its phase's name over an arc like the sun's, between the rise and the
 *    set of the pass across the sky the hour falls in, with the moon on it drawn in its
 *    phase, and how long until it next sets or rises;
 *  - the hour's weather: its condition icon (the icon pack's, as the header's), and
 *    beside it the condition over the temperature, as a reading's name and value.
 * The date is a reading too: the hour's time of day, the hour and its date.
 * Names and values read as the Weather Elements' text style prints them; the icons and
 * values have colour settings of their own (Appearance → Detailed view).
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "moon.js" as Moon
import "providers/solar.js" as Solar

Item {
    id: el
    property var weatherRoot: null
    property string elementId: ""
    property var sample: null        // the hour the view shows
    property bool isNow: false       // the current one, which the Date reads to the minute
    property int dayIdx: 0           // its day
    // That hour — now, for the first one — as new Date() reads the forecast's own times
    // (the location's clock), and as a true instant.
    property var refDate: new Date()
    property real refUtcMs: Date.now()
    property int fontPx: 15
    property int fontWeight: Font.DemiBold
    // the width a reading's text is laid out in, which holds while the hour changes
    property real textWidth: 0
    // between a reading's icon and its text
    property int iconGap: Kirigami.Units.largeSpacing
    // the view's go-ahead to build the weather's animated icon, and to let it move
    // (see ConditionIcon)
    property bool iconCanBuild: true
    property bool iconPlaying: true

    // An icon a little taller than the name and value on top of each other.
    readonly property int iconSize: Math.round(fontPx * 2.6)
    // Appearance → Detailed view → Element icon color and Element font color
    readonly property bool coloredIcons: !!weatherRoot && weatherRoot.detailedIconsColored
    readonly property bool coloredValues: !weatherRoot || weatherRoot.detailedValuesColored
    readonly property var day: weatherRoot && dayIdx >= 0 && dayIdx < weatherRoot.dailyData.length
                               ? weatherRoot.dailyData[dayIdx] : null

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    Loader {
        id: loader
        sourceComponent: el.elementId === "sun" ? sunComponent
                       : el.elementId === "moon" ? moonComponent
                       : el.elementId === "weather" ? weatherComponent : readingComponent
    }

    // ── Coming in (DetailedView's entrance) ──
    // After `delay` ms the element rises into place, grows to its size and fades in, as
    // the Daily forecast deals its cards; the sun and the moon cross their arcs to where
    // they are.
    property real arcSweep: 1   // how far along their way to where they are they show
    readonly property var _enterEasing: [0.2, 0.7, 0.25, 1, 1, 1]
    transform: [
        Translate { id: enterShift },
        Scale {
            id: enterScale
            origin.x: el.width / 2
            origin.y: el.height / 2
            yScale: xScale
        }
    ]
    SequentialAnimation {
        id: enterAnim
        property int duration: 0
        PauseAnimation { id: enterPause }
        ParallelAnimation {
            NumberAnimation {
                target: el; property: "opacity"; from: 0; to: 1; duration: enterAnim.duration
                easing.type: Easing.BezierSpline; easing.bezierCurve: el._enterEasing
            }
            NumberAnimation {
                target: enterShift; property: "y"; from: Math.round(el.fontPx * 1.2); to: 0
                duration: enterAnim.duration
                easing.type: Easing.BezierSpline; easing.bezierCurve: el._enterEasing
            }
            NumberAnimation {
                target: enterScale; property: "xScale"; from: 0.85; to: 1; duration: enterAnim.duration
                easing.type: Easing.BezierSpline; easing.bezierCurve: el._enterEasing
            }
            NumberAnimation {
                target: el; property: "arcSweep"; from: 0; to: 1
                duration: Math.round(enterAnim.duration * 2.4); easing.type: Easing.InOutCubic
            }
        }
    }
    function enter(delay, duration) {
        enterAnim.stop();
        if (duration <= 0) {
            opacity = 1;
            enterShift.y = 0;
            enterScale.xScale = 1;
            arcSweep = 1;
            return;
        }
        // hidden from the first frame on, not only once its turn comes
        opacity = 0;
        arcSweep = 0;
        enterPause.duration = Math.max(0, delay);
        enterAnim.duration = duration;
        enterAnim.start();
    }

    // A Meteocons reading icon `size` tall: the box is larger, its artwork's empty
    // edges spilling past the slot. Monochrome, its lines are drawn less bold than the
    // smaller icons elsewhere (readingIcon's `lighter`).
    component ElementIcon: Item {
        id: icon
        property string name: ""
        property int size: el.iconSize
        implicitWidth: size
        implicitHeight: size
        ReadingImage {
            anchors.centerIn: parent
            width: Math.round(icon.size * 1.9 * (el.weatherRoot ? el.weatherRoot.readingIconScale(icon.name) : 1))
            height: width
            weatherRoot: el.weatherRoot
            name: icon.name
            colored: el.coloredIcons
            lighter: true
        }
    }

    // "5h 12m", or "12m" under an hour
    function duration(ms) {
        var mins = Math.max(0, Math.round(ms / 60000)), h = Math.floor(mins / 60), m = mins % 60;
        return h > 0 ? i18nc("a duration: hours and minutes", "%1h %2m", h, m)
                     : i18nc("a duration: minutes", "%1m", m);
    }
    // The location's offset from UTC, in seconds; the viewer's own while it isn't known.
    readonly property real utcOffset: weatherRoot && !isNaN(weatherRoot.utcOffsetSeconds)
                                      ? weatherRoot.utcOffsetSeconds : -new Date().getTimezoneOffset() * 60

    // ── a reading ──
    Component {
        id: readingComponent
        RowLayout {
            id: reading
            spacing: el.iconGap
            // the hour itself, or now (no hour) for the Date of the current one
            readonly property var hour: el.isNow && el.elementId === "date" ? null : el.sample
            readonly property string value: el.weatherRoot
                ? el.weatherRoot.metricValue(el.elementId, el.dayIdx, hour, el.coloredValues) : ""
            ElementIcon {
                name: el.weatherRoot ? el.weatherRoot.metricIconAt(el.elementId, reading.hour) : ""
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: el.textWidth > 0 ? el.textWidth : -1
                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: el.weatherRoot ? el.weatherRoot.metricLabel(el.elementId, el.dayIdx) : ""
                    font.pixelSize: el.fontPx
                    opacity: 0.7
                }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        Layout.maximumWidth: el.textWidth > 0 ? el.textWidth - (arrow.visible ? arrow.width + parent.spacing : 0) : -1
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        text: reading.value.length ? reading.value : "—"
                        font.pixelSize: el.fontPx
                        font.weight: el.fontWeight
                    }
                    // the wind's direction, as after the Weather Elements' wind
                    Kirigami.Icon {
                        id: arrow
                        visible: el.elementId === "wind" && !!el.sample && !isNaN(el.sample.windDir)
                        source: Qt.resolvedUrl("../icons/wind-direction.svg")
                        isMask: true
                        color: Kirigami.Theme.textColor
                        roundToIconSize: false
                        rotation: el.weatherRoot && el.sample ? el.weatherRoot.windArrowRotation(el.sample.windDir) : 0
                        Layout.preferredWidth: el.weatherRoot ? el.weatherRoot.windArrowSize : 21
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }

    // ── the hour's weather and temperature ──
    Component {
        id: weatherComponent
        RowLayout {
            id: weatherBlock
            spacing: el.iconGap
            readonly property var hour: el.sample
            // The current hour shows what the header does — the current temperature
            // rather than the hour's forecast, which can round a degree apart. Another
            // hour, as the hourly cards: one likely to rain shows rain, whatever its code.
            readonly property bool now: el.isNow && !!el.weatherRoot
            readonly property int code: now ? el.weatherRoot.heroCode
                : hour && el.weatherRoot
                ? el.weatherRoot.precipAwareCode(hour.code, hour.precip, hour.precipAmt, hour.snow, hour.temp) : -1
            readonly property int dayFlag: now ? el.weatherRoot.heroDay : hour ? hour.day : 1
            readonly property string tempText: now ? el.weatherRoot.temperatureText
                : hour && el.weatherRoot ? el.weatherRoot.tempStr(hour.temp) : "—"
            // a reading icon's slot, the condition icon a little larger in it: it shows
            // the weather of the whole element
            Item {
                Layout.preferredWidth: el.iconSize
                Layout.preferredHeight: el.iconSize
                Layout.alignment: Qt.AlignVCenter
                ConditionIcon {
                    anchors.centerIn: parent
                    width: Math.round(el.iconSize * 1.25)
                    height: width
                    weatherRoot: el.weatherRoot
                    code: weatherBlock.code
                    day: weatherBlock.dayFlag
                    cloud: weatherBlock.now ? el.weatherRoot.heroCloud : weatherBlock.hour ? weatherBlock.hour.cloud : NaN
                    // it moves with the hourly cards (Appearance → Common → Weather icon animation)
                    animate: el.weatherRoot ? el.weatherRoot.animatedHourlyIcons : false
                    canBuild: el.iconCanBuild
                    playing: el.iconPlaying
                }
            }
            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: el.textWidth > 0 ? el.textWidth : -1
                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: el.weatherRoot && weatherBlock.code >= 0
                          ? el.weatherRoot.conditionText(weatherBlock.code, weatherBlock.dayFlag) : "—"
                    font.pixelSize: el.fontPx
                    opacity: 0.7
                }
                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: weatherBlock.tempText
                    font.pixelSize: el.fontPx
                    font.weight: el.fontWeight
                }
            }
        }
    }

    // ── the sun ──
    Component {
        id: sunComponent
        ColumnLayout {
            id: sunBlock
            spacing: Kirigami.Units.smallSpacing
            readonly property var rise: el.day && el.day.sunrise ? new Date(el.day.sunrise) : null
            readonly property var set: el.day && el.day.sunset ? new Date(el.day.sunset) : null
            readonly property bool known: !!rise && !!set && !isNaN(rise.getTime()) && !isNaN(set.getTime())
            readonly property real t: el.refDate ? el.refDate.getTime() : 0
            // the next sunrise after the sun has set: the next day's, else a day on
            readonly property real nextRise: {
                if (!known) return NaN;
                var next = el.weatherRoot && el.dayIdx + 1 < el.weatherRoot.dailyData.length
                           ? el.weatherRoot.dailyData[el.dayIdx + 1].sunrise : "";
                var d = next ? new Date(next) : null;
                return d && !isNaN(d.getTime()) ? d.getTime() : rise.getTime() + 86400000;
            }
            readonly property bool up: known && t >= rise.getTime() && t < set.getTime()
            // how far along its arc the sun is: 0 at sunrise, 1 at sunset
            readonly property real along: !known ? 0 : up ? (t - rise.getTime()) / (set.getTime() - rise.getTime())
                                        : (t < rise.getTime() ? 0 : 1)

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: sunBlock.known ? el.duration(sunBlock.set.getTime() - sunBlock.rise.getTime()) : "—"
                font.pixelSize: el.fontPx
                font.weight: el.fontWeight
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing
                ColumnLayout {
                    spacing: 0
                    ElementIcon { name: "sunrise"; Layout.alignment: Qt.AlignHCenter }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: el.day && el.weatherRoot ? el.weatherRoot._sunClock(el.day.sunrise) || "—" : "—"
                        font.pixelSize: el.fontPx
                        font.weight: el.fontWeight
                    }
                }
                SkyArc {
                    along: sunBlock.along * el.arcSweep
                    up: sunBlock.up
                    bodyColor: el.coloredIcons ? (el.weatherRoot ? el.weatherRoot.sunColor : "#ffb74d")
                                               : Kirigami.Theme.textColor
                }
                ColumnLayout {
                    spacing: 0
                    ElementIcon { name: "sunset"; Layout.alignment: Qt.AlignHCenter }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: el.day && el.weatherRoot ? el.weatherRoot._sunClock(el.day.sunset) || "—" : "—"
                        font.pixelSize: el.fontPx
                        font.weight: el.fontWeight
                    }
                }
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: sunBlock.known
                text: !sunBlock.known ? ""
                    : sunBlock.up ? i18n("To sunset: %1", el.duration(sunBlock.set.getTime() - sunBlock.t))
                    : i18n("To sunrise: %1", el.duration((sunBlock.t < sunBlock.rise.getTime()
                                                          ? sunBlock.rise.getTime() : sunBlock.nextRise) - sunBlock.t))
                font.pixelSize: el.fontPx
                opacity: 0.7
            }
        }
    }

    // ── the sky's arc, for the sun and the moon ──
    // A faint half circle from rising (left) to setting (right), the part already
    // crossed in the body's colour, and the body where it is (`along`: 0 just risen, 1
    // set), fainter while it is down. The moon is a disc in its phase (`phase` and `lit`
    // as moon.js gives them), larger than the sun's dot: the arc keeps the sun's size,
    // and the moon reaches up into the room above the canvas.
    component SkyArc: Canvas {
        id: arc
        property real along: 0
        property bool up: false
        property color bodyColor: Kirigami.Theme.textColor
        property bool moon: false
        property real phase: 0
        property real lit: 0
        readonly property color lineColor: Kirigami.Theme.textColor
        readonly property color backColor: Kirigami.Theme.backgroundColor
        // the sun's dot, which sets the arc's size, and the body drawn
        readonly property int sunDot: Math.max(3, Math.round(el.fontPx * 0.35))
        readonly property int bodyR: moon ? Math.max(5, Math.round(el.fontPx * 0.55)) : sunDot
        readonly property int headroom: Math.max(0, bodyR - sunDot)
        // south of the equator the moon is lit from the other side
        readonly property bool mirrored: Plasmoid.configuration.latitude < 0
        Layout.preferredWidth: Math.round(el.iconSize * 2.3)
        Layout.preferredHeight: el.iconSize + headroom
        Layout.topMargin: -headroom
        Layout.alignment: Qt.AlignTop
        onAlongChanged: requestPaint()
        onUpChanged: requestPaint()
        onBodyColorChanged: requestPaint()
        onPhaseChanged: requestPaint()
        onLitChanged: requestPaint()
        onLineColorChanged: requestPaint()
        onBackColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var r = Math.min(width / 2, el.iconSize) - sunDot - 1, cx = width / 2, cy = height - 1;
            if (r <= 0) return;
            var b = bodyColor;
            ctx.lineWidth = 1.5;
            ctx.lineCap = "round";
            // the whole way faintly, the part crossed fully
            ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.3);
            ctx.beginPath();
            ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI, false);
            ctx.stroke();
            if (along > 0) {
                ctx.strokeStyle = Qt.rgba(b.r, b.g, b.b, 0.85);
                ctx.beginPath();
                ctx.arc(cx, cy, r, Math.PI, Math.PI + Math.PI * along, false);
                ctx.stroke();
            }
            var a = Math.PI + Math.PI * along, x = cx + r * Math.cos(a), y = cy + r * Math.sin(a);
            if (!moon) {
                ctx.fillStyle = Qt.rgba(b.r, b.g, b.b, up ? 1 : 0.45);
                ctx.beginPath();
                ctx.arc(x, y, sunDot, 0, 2 * Math.PI, false);
                ctx.fill();
                return;
            }
            var R = bodyR, k = up ? 1 : 0.45;
            // the disc covers the arc behind it; its dark side faint, its rim a little
            // clearer, so a new moon still shows
            ctx.beginPath();
            ctx.arc(x, y, R, 0, 2 * Math.PI, false);
            ctx.fillStyle = backColor;
            ctx.fill();
            ctx.fillStyle = Qt.rgba(b.r, b.g, b.b, 0.16 * k);
            ctx.fill();
            ctx.lineWidth = 1;
            ctx.strokeStyle = Qt.rgba(b.r, b.g, b.b, 0.5 * k);
            ctx.stroke();
            // The lit part: down the lit limb from top to bottom, and back up along the
            // terminator, half an ellipse R·c wide (c = 1 − 2·lit: 1 new, 0 at the
            // quarters, −1 full) — on the limb's side while a crescent, past the middle
            // once gibbous. Waxing, the right limb is lit (seen from the north).
            var side = (phase < 0.5 ? 1 : -1) * (mirrored ? -1 : 1), c = 1 - 2 * lit, n = 24, i, t;
            ctx.beginPath();
            for (i = 0; i <= n; ++i) {
                t = -Math.PI / 2 + Math.PI * i / n;
                if (i === 0) ctx.moveTo(x + side * R * Math.cos(t), y + R * Math.sin(t));
                else ctx.lineTo(x + side * R * Math.cos(t), y + R * Math.sin(t));
            }
            for (i = n; i >= 0; --i) {
                t = -Math.PI / 2 + Math.PI * i / n;
                ctx.lineTo(x + side * R * c * Math.cos(t), y + R * Math.sin(t));
            }
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(b.r, b.g, b.b, k);
            ctx.fill();
        }
    }

    // ── the moon ──
    // As the sun: the phase's name above, the moon's pass across the sky — the one the
    // hour falls in, or the next while it is down — and how long until it sets or rises.
    Component {
        id: moonComponent
        ColumnLayout {
            id: moonBlock
            spacing: Kirigami.Units.smallSpacing
            readonly property var phase: Moon.phase(el.refUtcMs)
            readonly property var pass: Moon.pass(el.refUtcMs, Plasmoid.configuration.latitude,
                                                  Plasmoid.configuration.longitude)
            readonly property bool rises: !isNaN(pass.riseMs)
            readonly property bool sets: !isNaN(pass.setMs)
            // how far along its pass the moon is: 0 just risen, 1 set (and still to rise
            // while it is down); halfway while up all the time it is reckoned over
            readonly property real along: !pass.up ? 0
                : rises && sets ? Math.max(0, Math.min(1, (el.refUtcMs - pass.riseMs) / (pass.setMs - pass.riseMs)))
                : 0.5
            function clock(ms) {
                return isNaN(ms) || !el.weatherRoot ? "—" : el.weatherRoot._sunClock(Solar.toLocalIso(ms, el.utcOffset)) || "—";
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: el.weatherRoot ? el.weatherRoot.moonPhaseNames[moonBlock.phase.index] : ""
                font.pixelSize: el.fontPx
                font.weight: el.fontWeight
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing
                ColumnLayout {
                    spacing: 0
                    ElementIcon { name: "moonrise"; Layout.alignment: Qt.AlignHCenter }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: moonBlock.clock(moonBlock.pass.riseMs)
                        font.pixelSize: el.fontPx
                        font.weight: el.fontWeight
                    }
                }
                SkyArc {
                    moon: true
                    along: moonBlock.along * el.arcSweep
                    up: moonBlock.pass.up
                    phase: moonBlock.phase.phase
                    lit: moonBlock.phase.lit
                    // the colour of Meteocons' flat moon
                    bodyColor: el.coloredIcons ? "#72b9d5" : Kirigami.Theme.textColor
                }
                ColumnLayout {
                    spacing: 0
                    ElementIcon { name: "moonset"; Layout.alignment: Qt.AlignHCenter }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: moonBlock.clock(moonBlock.pass.setMs)
                        font.pixelSize: el.fontPx
                        font.weight: el.fontWeight
                    }
                }
            }
            // always there, so the last lines of the sun and the moon stay level
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: moonBlock.pass.up
                    ? (moonBlock.sets ? i18n("To moonset: %1", el.duration(moonBlock.pass.setMs - el.refUtcMs)) : "—")
                    : (moonBlock.rises ? i18n("To moonrise: %1", el.duration(moonBlock.pass.riseMs - el.refUtcMs)) : "—")
                font.pixelSize: el.fontPx
                opacity: 0.7
            }
        }
    }
}
