/*
 * Full (popup) representation — header, daily tabs, and a continuous
 * scrollable/draggable hourly timeline with day-break dividers. Scrolling the
 * timeline highlights the matching day tab; clicking a tab scrolls to that day.
 * Copyright 2026  pku188, bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "wheel.js" as Wheel

Item {
    id: full

    property var weatherRoot
    // The highlighted day. Normally the day whose card sits at the strip's left edge
    // (leadDay), but a day picked from the tabs wins (chosenDay): the strip cannot
    // scroll far enough to bring the LAST days to the left edge — met.no's sparse
    // 6-hour days are only a few cards wide — so tracking the edge alone would leave
    // an earlier day highlighted, with its sun times and totals in the header.
    // Any scroll of the strip itself hands the selection back to the edge.
    property int leadDay: 0
    property int chosenDay: -1
    readonly property int selectedDay: (chosenDay >= 0 && chosenDay < dayTabsRep.count) ? chosenDay : leadDay
    // hour whose card the pointer is over, so the header's instantaneous metrics
    // (cloud, humidity, UV, feels, wind) track it like the graph scrubs — null when
    // not hovering, so they fall back to the current reading. Day-based metrics
    // (precip/snow totals, sun) keep following selectedDay regardless.
    property var hoveredHourSample: null

    // Uniform padding around the whole popup
    readonly property int pad: Math.round(Kirigami.Units.gridUnit * 0.85)

    // Top of the header row, in view coordinates (the content's top margin plus the
    // header's own lift). The header content is positioned from the shared geometry in
    // WeatherToolbar, which is in view coordinates too; this converts between the two.
    readonly property int headerY: Math.round(pad * 0.4) - Math.round(Kirigami.Units.gridUnit * 0.35)

    // Hourly timeline geometry (used for both layout and scroll math)
    // Card width FLEXES to the visible strip: a whole number of cards fills the
    // width exactly, so the last card is never chopped off — whatever width the box
    // ends up (on the desktop it's dictated by the graph layout's size). Falls back
    // to the base width before the strip has a width. ponytail: targets hour cards;
    // a day-break divider in view leaves a small remainder, but the common
    // resting view (today, no midnight in frame) fills cleanly.
    readonly property int hourCardBaseW: Math.round(Kirigami.Units.gridUnit * 5.9)
    readonly property int hourCardCount: {
        var avail = hourlyFlick.width;
        if (avail <= 0) return 1;
        return Math.max(1, Math.round(avail / (hourCardBaseW + hourGapBase)));
    }
    readonly property int hourCardW: {
        var avail = hourlyFlick.width;
        if (avail <= 0) return hourCardBaseW;
        return Math.max(Math.round(hourCardBaseW * 0.8),
                        Math.floor((avail - (hourCardCount - 1) * hourGapBase) / hourCardCount));
    }
    // Entrance "deal" timing. cardDealDurationPercent scales the per-card animation
    // AND the stagger between cards together, so the whole sequence keeps its shape
    // at any speed: 100 = the original pace, 60 = the default, 50 = twice as fast,
    // 0 = instant. Set from the Cards tab ("Card entrance duration").
    readonly property int  dealDurationBase: 550   // per-card slide/fade/scale, ms
    readonly property int  dealStaggerBase:  75    // delay added per card, ms
    readonly property real dealPercent: (weatherRoot ? weatherRoot.cardDealDurationPercent : 60) / 100
    readonly property int  dealDuration: Math.max(0, Math.round(dealDurationBase * dealPercent))
    readonly property int  dealStagger:  Math.max(0, Math.round(dealStaggerBase  * dealPercent))

    readonly property int hourCardH: (weatherRoot ? weatherRoot.hourlyIconSize : 32)
                                     + Math.round(Kirigami.Units.gridUnit * 8)
    // A day-break marker takes a WHOLE card slot, not a narrow one. hourCardW is
    // sized so a whole number of cards exactly fills the strip, which keeps the
    // right edge flush — but only while every element in the row is one card wide.
    // A narrow divider broke that grid: any scroll position with a divider on
    // screen shifted everything by (hourCardW - dayBreakW), so the last card came
    // out sliced. Giving the divider a full slot makes the row a uniform grid
    // again, so every snap position is flush by construction. The label itself is
    // unchanged — it just centres in a wider box, which is where the extra width
    // goes (the "responsive margins" around it).
    readonly property int dayBreakW: hourCardW
    readonly property int hourGapBase: Kirigami.Units.smallSpacing * 2
    // The gap absorbs the leftover, so the grid fills the viewport EXACTLY.
    // hourCardW has to be a whole number of pixels, and flooring it leaves a few px
    // of slack — enough for a sliver of the NEXT card to show past the right edge
    // (a 4 px stripe at 1460 px wide, on every scroll position). Widening the gaps
    // by a fraction of a pixel each instead consumes that slack, which also makes
    // the scrollable range an exact multiple of the card pitch — that is what lets
    // the final card come to rest flush rather than half cut off.
    // Spread over the gaps rather than taken out of the strip's width because the
    // width is what the layout gives us: deriving the Flickable's width from the
    // card grid would feed back into the view's implicitWidth on the desktop.
    readonly property real hourGap: {
        var avail = hourlyFlick.width;
        if (avail <= 0 || hourCardCount <= 1) return hourGapBase;
        return Math.max(2, (avail - hourCardCount * hourCardW) / (hourCardCount - 1));
    }
    // Fixed height for a per-hour readout row. Each card always reserves this
    // height per configured metric (even when a given hour has no value, e.g.
    // snow on a dry hour), so the centered time/icon/temp cluster sits at the
    // same Y on every card instead of drifting between 1- and 2-readout hours.
    // Must clear the TALLEST content — the wind glyph at 1.6× the readout font.
    // Its line box runs taller than its em, so + smallSpacing of headroom keeps
    // it fully inside the row (else it overflows downward and crowds line 2).
    readonly property int hourMetricRowH: Math.max(
        Kirigami.Units.iconSizes.small,
        Math.round((weatherRoot ? weatherRoot.hourlyCardFontSize : 11) * 1.6)
            + Kirigami.Units.smallSpacing)

    // ── "Corner split" precip gradient for hourly cards (precip-corner-split.js) ──
    // Rain blooms from the BOTTOM-LEFT corner in blue; snow blooms from the
    // TOP-RIGHT corner in white. Each corner grows + brightens with its share of
    // the precip chance, so a wintry-mix hour shows a diagonal of both, an all-rain
    // hour is just blue, an all-snow hour just white. Dry/low hours stay clean.
    readonly property var  rainBlue:      [66, 165, 245]    // #42a5f5 rain hue
    readonly property var  snowWhite:     [234, 242, 255]   // snow
    readonly property real rainTideFloor: weatherRoot ? weatherRoot.precipDisplayFloor : 15   // shared floor: % at/under which a card stays clean (no wash, no readout)
    function rainTideT(pct) {                // overall intensity 0..1 (0 at floor, 1 at 100%)
        if (isNaN(pct)) return 0;
        var t = (pct - rainTideFloor) / (100 - rainTideFloor);
        return t < 0 ? 0 : (t > 1 ? 1 : t);
    }
    // The faintest background a card can show from a real chance: whole-percent chances
    // start washing at floor + 1 (21%), i.e. one step of the floor..100 range. An hour
    // with measurable precipitation but no chance published (met.no outside the Nordics)
    // gets at least this, so 0.1-0.5 mm — which maps under the floor — isn't left blank
    // while its card plainly reads as rain.
    readonly property real rainTideMinT: 1 / (100 - rainTideFloor)
    // Fraction of the precip falling as snow (0 = all rain → blue corner, 1 = all
    // snow → white corner). Gate on the SAME icon the card shows (precipAwareCode)
    // so a snow glyph ALWAYS gets a white corner — even a flurry that accumulates to
    // ~0. Then grade the split by air temp: a clearly-cold hour reads pure white,
    // while a near-freezing snow hour keeps a blue corner too (the wintry-mix
    // diagonal). Rain-coded hours stay all blue.
    function snowFraction(code, precip, precipAmt, snowCm, temp) {
        var ic = weatherRoot ? weatherRoot.precipAwareCode(code, precip, precipAmt, snowCm, temp) : code;
        // Sleet (56/57/66/67) is a rain/snow MIX — give it a half-and-half wash so
        // the corner shows both colours, matching the sleet glyph (the marginal-band
        // hours land here; pure blue read as plain rain under a "light snow" label).
        if (ic === 56 || ic === 57 || ic === 66 || ic === 67) return 0.5;
        if (!((ic >= 71 && ic <= 77) || ic === 85 || ic === 86)) return 0;   // icon says rain → all blue
        if (isNaN(temp)) return 1;
        var f = weatherRoot && weatherRoot.units === "fahrenheit";
        var tAllSnow = f ? 31 : -0.5, tAllRain = f ? 37 : 3;
        var frac = (tAllRain - temp) / (tAllRain - tAllSnow);
        frac = frac < 0 ? 0 : (frac > 1 ? 1 : frac);
        return Math.max(0.45, frac);         // snow per icon → keep a visible blue hint when marginal
    }
    function tideRgbaStr(c, a) { return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + a.toFixed(3) + ")"; }

    // true while the hourly strip is in motion (drag/flick or wheel/tab animation);
    // hourly card animations pause during this for smooth scrolling
    readonly property bool scrolling: hourlyFlick.moving || scrollAnim.running

    // Animated icons are built only once the popup has been opened and the cards
    // have been dealt: until then the static icons show, which look the same at
    // rest, so neither the first frame nor the deal waits on building them. Stays
    // true — built icons are kept and just hold still while the popup is closed.
    property bool iconsLive: false
    Timer {
        id: iconsLiveTimer
        // the deal's length: its per-card stagger (capped at ten cards) plus one card's own
        interval: 10 * full.dealStagger + full.dealDuration + 50
        onTriggered: if (full.onScreen && full.visible) full.iconsLive = true
    }

    // bumping this re-deals the hourly cards (entrance animation). Fires on
    // creation, on every popup open, and on becoming visible again — the view is
    // now kept warm across layout switches (main.qml), so a switch reveals it
    // rather than rebuilding it; onVisibleChanged replays the intro on that switch.
    property int dealRun: 0
    // Timeline index of the first entry on screen when a deal starts. The stagger counts
    // from it, so a deal replayed on a strip that is scrolled away from the start (the
    // layout switch keeps the scroll position) still cascades from the left edge instead
    // of every card waiting out the maximum delay and landing at once.
    property int dealBase: 0
    function redeal() {
        dealBase = leadingEntry(hourlyFlick.contentX);
        dealRun++;
        if (!iconsLive) iconsLiveTimer.restart();
    }
    Component.onCompleted: { syncTimelineModel(); redeal(); }
    onVisibleChanged: if (visible) redeal()
    Connections {
        target: full.weatherRoot
        function onExpandedChanged() {
            if (full.weatherRoot.expanded) {
                scrollAnim.stop();
                hourlyFlick.contentX = 0;   // always reopen on today's tab
                full.chosenDay = -1;
                full.redeal();
            }
        }
    }

    // False while the popup is closed. Plasma keeps the view alive (and `visible`)
    // behind a hidden popup, so an animated icon gated on `visible` alone keeps
    // decoding frames for a window nobody can see.
    readonly property bool onScreen: Window.visibility !== Window.Hidden

    // toolbar buttons floated at the very top-right corner (out of the header
    // flow, so they don't push the condition/location down)
    WeatherToolbar {
        id: toolbar
        pad: full.pad
        switchTooltip: i18n("Switch to graph layout")
        switchIcon: "view-graph"
        root: weatherRoot
    }

    implicitWidth:  content.implicitWidth  + pad * 2
    implicitHeight: content.implicitHeight + pad + Math.round(pad * 0.4)
    Layout.minimumWidth: Kirigami.Units.gridUnit * 32 + pad * 2

    // Continuous hourly model — rebuilds after each fetch and when the day count
    // changes (those properties are read here to register the dependency).
    readonly property var timeline: {
        if (!weatherRoot) return [];
        var _dep1 = weatherRoot.allHourly;
        var _dep2 = weatherRoot.dailyDays;
        return weatherRoot.timeline();
    }

    // ── The card strip's model, kept in step with `timeline` ─────────────
    // The strip used to take `timeline` (a plain JS array) as its model directly.
    // Qt reuses the cards when a new array has the same LENGTH, but rebuilds every
    // one of them when the length changes — and the length changes on the first
    // refresh after each hour turns, when the hour that just passed drops off the
    // front. That rebuilt all ~160 cards in the background every hour, and the next
    // popup open paid to render them from scratch: the "slow again after a while".
    //
    // This ListModel is updated IN PLACE instead: hours that have passed are removed
    // from the front, rows whose content changed are overwritten, new ones appended.
    // A typical hourly refresh now destroys one card and creates none.
    //
    // Each row holds the whole entry in ONE role. One role per field would be
    // unsafe: ListModel fills a field a row doesn't have with a type default, so a
    // day divider would read `temp` as 0 and an hour `dayBreak` as false. A single
    // role keeps undefined as undefined and NaN as NaN, exactly as `timeline` has it.
    ListModel { id: timelineModel }
    property var _syncedTimeline: []   // what timelineModel currently holds, in order
    function _entryKey(e) { return e.dayBreak ? "break|" + e.date : e.time; }
    function _sameEntry(a, b) {
        var ka = Object.keys(a), kb = Object.keys(b);
        if (ka.length !== kb.length) return false;
        for (var i = 0; i < ka.length; ++i) {
            var x = a[ka[i]], y = b[ka[i]];
            if (x !== y && !(x !== x && y !== y)) return false;   // NaN equals NaN here
        }
        return true;
    }
    function syncTimelineModel() {
        var next = timeline || [], cur = _syncedTimeline, i;
        // 1. drop what has scrolled into the past: find the new first entry among the
        //    current rows and remove everything before it. No match (a new location,
        //    provider or day count) → nothing to drop; rows are overwritten below.
        if (next.length && cur.length) {
            var firstKey = _entryKey(next[0]);
            for (i = 0; i < cur.length; ++i) {
                if (_entryKey(cur[i]) !== firstKey) continue;
                if (i > 0) { timelineModel.remove(0, i); cur = cur.slice(i); }
                break;
            }
        }
        // 2. overwrite rows in place — only the ones whose content actually changed
        var common = Math.min(cur.length, next.length);
        for (i = 0; i < common; ++i)
            if (!_sameEntry(cur[i], next[i])) timelineModel.set(i, { entry: next[i] });
        // 3. append anything new at the end, in one insert; or trim what's left over
        if (next.length > common) {
            var add = [];
            for (i = common; i < next.length; ++i) add.push({ entry: next[i] });
            timelineModel.append(add);
        } else if (cur.length > common) {
            timelineModel.remove(common, cur.length - common);
        }
        _syncedTimeline = next.slice();
    }
    onTimelineChanged: syncTimelineModel()

    // x offset to open a day at its configured start hour (detailDayStartHour:
    // 6 = 6AM, skipping the overnight cards; 0 = midnight) — except "today"
    // (index 0), which opens at its first available card, i.e. the current hour.
    //
    // A 6-hour BLOCK is never skipped. The start-hour rule exists to skip a long
    // overnight run of hourly cards; a day of blocks has only about four cards, so
    // applying it there throws away a quarter of the day — with met.no's
    // 02/08/14/20 blocks a 6AM start would open on 08–14 and hide 02–08 entirely.
    // So the day opens at the first card that is EITHER a block or at/after the
    // start hour, whichever comes first. That also handles the mixed day where
    // met.no's hourly data runs out partway: its couple of overnight hourly cards
    // are still skipped, but the 02–08 block that follows them is not.
    function dayCardX(dayIdx) {
        if (!weatherRoot || dayIdx < 0 || dayIdx >= weatherRoot.dailyData.length) return 0;
        var date = weatherRoot.dailyData[dayIdx].date;
        var pos = 0, firstPos = -1;
        for (var i = 0; i < timeline.length; ++i) {
            var e = timeline[i];
            if (!e.dayBreak && e.date === date) {
                if (firstPos < 0) firstPos = pos;
                if (dayIdx !== 0 && (e.spanHours > 1
                        || new Date(e.time).getHours() >= weatherRoot.detailDayStartHour)) return pos;
            }
            pos += (e.dayBreak ? dayBreakW : hourCardW) + hourGap;
        }
        return firstPos < 0 ? 0 : firstPos;
    }

    // timeline index of the entry at the left edge for a given scroll offset
    function leadingEntry(contentX) {
        var pos = 0;
        for (var i = 0; i < timeline.length; ++i) {
            var w = timeline[i].dayBreak ? dayBreakW : hourCardW;
            if (contentX < pos + w) return i;
            pos += w + hourGap;
        }
        return 0;
    }

    // which day index sits at the left edge for a given scroll offset
    function leadingDay(contentX) {
        if (!weatherRoot) return 0;
        var pos = 0;
        for (var i = 0; i < timeline.length; ++i) {
            var e = timeline[i];
            var w = e.dayBreak ? dayBreakW : hourCardW;
            if (contentX < pos + w)
                return weatherRoot.dayIndexForDate(e.date);
            pos += w + hourGap;
        }
        return 0;
    }

    // clicking a day tab animates the timeline to that day's first card
    // Left edges of the CARD entries only, in strip order. Wheel stepping works on
    // this list rather than on pixel distances, so "2 cards" always advances by two
    // hours of forecast: a day divider between them is passed over without
    // consuming a step, and no snap-to-nearest can round the move up or down.
    readonly property var cardXs: {
        var out = [], pos = 0;
        for (var i = 0; i < timeline.length; ++i) {
            var e = timeline[i];
            if (!e.dayBreak) out.push(pos);
            pos += (e.dayBreak ? dayBreakW : hourCardW) + hourGap;
        }
        return out;
    }
    function cardIndexAt(x) {
        var best = 0, bd = Infinity;
        for (var i = 0; i < cardXs.length; ++i) {
            var d = Math.abs(cardXs[i] - x);
            if (d < bd) { bd = d; best = i; }
        }
        return best;
    }
    // x offset `n` cards along from whatever card `fromX` is resting on.
    function stepCardsX(fromX, n) {
        if (!cardXs.length) return fromX;
        var i = Math.max(0, Math.min(cardXs.length - 1, cardIndexAt(fromX) + n));
        var maxX = Math.max(0, hourlyFlick.contentWidth - hourlyFlick.width);
        return Math.max(0, Math.min(maxX, cardXs[i]));
    }

    // Day stepping for the tab wheel. selectedDay only catches up once the scroll
    // animation has moved contentX, so a fast second notch would otherwise step
    // from the day we are still leaving. pendingDay remembers the destination.
    property int pendingDay: -1
    function stepDay(delta) {
        var maxDay = (weatherRoot ? Math.min(weatherRoot.dailyDays, weatherRoot.dailyData.length) : 1) - 1;
        var from = (pendingDay >= 0) ? pendingDay : selectedDay;
        var to = Math.max(0, Math.min(maxDay, from + delta));
        if (to === from) return;
        pendingDay = to;
        chosenDay = to;
        scrollToDay(to);
    }

    function scrollToDay(dayIdx) {
        var target = Math.min(dayCardX(dayIdx),
                              Math.max(0, hourlyFlick.contentWidth - hourlyFlick.width));
        scrollAnim.stop();
        scrollAnim.from = hourlyFlick.contentX;
        scrollAnim.to = target;
        scrollAnim.start();
    }

    // snap a raw scroll offset to the nearest hour-card left edge, so a drag/
    // flick/wheel never rests mid-card (which crops the edge cards). Walks the
    // same running `pos` as dayCardX/leadingDay; day-break dividers aren't snap
    // targets (you rest on a card, not on a divider). Clamped to the scrollable
    // range, so the far end stays flush-right.
    function nearestCardX(x) {
        var maxX = Math.max(0, hourlyFlick.contentWidth - hourlyFlick.width);
        x = Math.max(0, Math.min(maxX, x));
        // maxX is a candidate in its own right. The card grid and the scrollable
        // range don't quite share a boundary (hourCardW is floored, leaving a few
        // px of slack), so without this the nearest card edge to the end can sit a
        // whole slot short — leaving the final card half off-screen with no way to
        // reach it by scrolling. It was most obvious under met.no, where a day is
        // four wide blocks rather than 24 cards.
        var pos = 0, best = maxX, bestDist = Math.abs(maxX - x);
        for (var i = 0; i < timeline.length; ++i) {
            var e = timeline[i];
            if (!e.dayBreak) {
                var d = Math.abs(pos - x);
                if (d < bestDist) { bestDist = d; best = pos; }
            }
            pos += (e.dayBreak ? dayBreakW : hourCardW) + hourGap;
        }
        return Math.max(0, Math.min(maxX, best));
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: full.pad
        anchors.rightMargin: full.pad
        anchors.bottomMargin: full.pad
        anchors.topMargin: Math.round(full.pad * 0.4)
        spacing: Kirigami.Units.smallSpacing

        // ── Header ────────────────────────────────────────────────────────
        // Placed from the shared header geometry in WeatherToolbar (view coordinates,
        // converted here via headerY), so everything lands in the same spots as in the
        // graph layout.
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            // Pinned to the top of its cell. A popup taller than the content gets the
            // spare height spread between the rows (which gives the rows below their
            // breathing room), and a centred header would drift down with it, away
            // from where the other layout shows the same icon and location.
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: full.headerY - content.anchors.topMargin
            spacing: Kirigami.Units.largeSpacing

            // Icon, temperature, condition and Weather Elements — the same block as the
            // graph layout's (see HeaderHero); only what differs is handed in here.
            HeaderHero {
                id: heroRow
                Layout.alignment: Qt.AlignTop
                Layout.leftMargin: toolbar.heroRowX - full.pad
                Layout.topMargin: toolbar.heroRowY - full.headerY
                weatherRoot: full.weatherRoot
                toolbar: toolbar
                metrics: full.weatherRoot ? full.weatherRoot.headerMetrics : []
                selectedDay: full.selectedDay
                // the hovered card while the pointer is over the strip, else the CURRENT
                // hour's sample — so with nothing hovered the elements read "now" the way
                // the cards do (the current-hour forecast), not the slightly different
                // live block
                sample: full.hoveredHourSample
                        || (full.weatherRoot ? full.weatherRoot.currentHourSample : null)
                // what the header can be handed: any hourly card, any day tab
                readingHours: full.timeline
                readingDays: dayTabsRep.count
                animate: full.weatherRoot ? full.weatherRoot.fullHeaderAnim : false
                animCanBuild: full.iconsLive
                animPlaying: full.onScreen
            }

            Item { Layout.fillWidth: true }

            // Location, day pills and weather source — shared with the graph layout, so
            // they hold the same spots in both (see HeaderRightBlock).
            HeaderRightBlock {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
                Layout.topMargin: toolbar.buttonCenterY - full.headerY - capCenter
                Layout.rightMargin: toolbar.rightInset - full.pad
                weatherRoot: full.weatherRoot
                toolbar: toolbar
                originX: content.x + headerRow.x
                // The location line is above the Weather Elements, so it may run over
                // them; it only has to stay clear of the temperature.
                leftBound: content.x + headerRow.x + heroRow.x + heroRow.heroTempWidth + Kirigami.Units.largeSpacing * 2
                locationFontSize: weatherRoot ? weatherRoot.locationFontSize : 26
                providerFontSize: weatherRoot ? weatherRoot.providerFontSize : 16
                pillCount: weatherRoot ? weatherRoot.graphDays : 0
                // the card layout has no day pills: an invisible placeholder keeps their room
                pillsShown: false
            }
        }

        // ── Daily tabs (count limited by the dailyDays setting) ───────────
        // wrapped in a plain Item so the sliding highlight can live OUTSIDE the
        // RowLayout — a RowLayout manages every child item, so a highlight
        // inside it would be grabbed as a layout cell and lose its x/width
        Item {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            implicitHeight: dayTabsRow.implicitHeight

            // single selection highlight that SLIDES between tabs (drawn under
            // the RowLayout; same coordinate space since the row fills this Item)
            Rectangle {
                readonly property Item sel: dayTabsRep.count > full.selectedDay
                                            ? dayTabsRep.itemAt(full.selectedDay) : null
                visible: sel !== null
                x: sel ? sel.x : 0
                y: sel ? sel.y : 0
                width: sel ? sel.width : 0
                height: sel ? sel.height : 0
                radius: 8
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.10)
                Behavior on x     { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
            }

            // Wheel over the day tabs steps whole days: down = later, up = earlier,
            // matching the card strip's own scroll direction. scrollToDay honours the
            // "Day starts at" setting (and its 6-hour-block exemption) because it goes
            // through dayCardX, exactly like a tab click.
            WheelHandler {
                id: dayTabsWheel
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real acc: 0
                onWheel: (wheel) => {
                    wheel.accepted = true;
                    var ad = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                    var dir = Wheel.step(dayTabsWheel, ad);
                    if (dir !== 0) full.stepDay(dir);
                }
            }

            RowLayout {
            id: dayTabsRow
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                id: dayTabsRep
                model: weatherRoot ? weatherRoot.dailyData.slice(0, weatherRoot.dailyDays) : []
                delegate: Rectangle {
                    id: dayTab
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: dayCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                    radius: 8
                    readonly property bool selected: index === full.selectedDay
                    // selection is drawn by the sliding highlight; tabs only
                    // paint their hover state
                    color: tabHover.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 200 } }

                    HoverHandler { id: tabHover }
                    TapHandler {
                        onTapped: {
                            full.chosenDay = dayTab.index;
                            full.scrollToDay(dayTab.index);
                        }
                    }

                    ColumnLayout {
                        id: dayCol
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: weatherRoot ? weatherRoot.dayName(dayTab.index, true) : ""
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                            font.bold: dayTab.selected
                        }
                        // the date under the name, in the system's date format (no year)
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: -Math.round(Kirigami.Units.smallSpacing / 2)
                            visible: weatherRoot ? weatherRoot.showDayDate : true
                            text: weatherRoot ? weatherRoot.dailyDate(dayTab.index) : ""
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                            font.bold: dayTab.index === 0   // today's date stands out; stays dimmed
                            opacity: 0.55
                        }
                        ConditionIcon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth:  weatherRoot ? weatherRoot.dailyIconSize : 24
                            Layout.preferredHeight: weatherRoot ? weatherRoot.dailyIconSize : 24
                            weatherRoot: full.weatherRoot
                            // daily tabs always show the day variant
                            code: dayTab.modelData ? dayTab.modelData.code : -1
                            day: 1
                            animate: weatherRoot ? weatherRoot.animatedDailyIcons : false
                            canBuild: full.iconsLive
                            playing: full.onScreen
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            textFormat: Text.StyledText
                            font.pixelSize: weatherRoot ? weatherRoot.dailyTempFontSize : 15
                            text: weatherRoot
                                ? "<b><font color=\"#42a5f5\">" + weatherRoot.tempStr(dayTab.modelData.lo) + "</font> | "
                                  + "<font color=\"#ff6e40\">" + weatherRoot.tempStr(dayTab.modelData.hi) + "</font></b>" : ""
                        }
                    }
                }
            }
            }
        }

        // ── Continuous hourly timeline (scroll + drag) ────────────────────
        Flickable {
            id: hourlyFlick
            Layout.fillWidth: true
            Layout.preferredHeight: full.hourCardH + Kirigami.Units.smallSpacing * 2
            Layout.topMargin: Math.round(Kirigami.Units.largeSpacing * 1.6)   // gap between tabs and hourly
            Layout.leftMargin: Kirigami.Units.largeSpacing                     // inset from the day tabs
            Layout.rightMargin: Kirigami.Units.largeSpacing
            contentWidth: hourlyRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // Whenever the pointer isn't over the hourly strip at all, drop the hovered
            // hour so the header readouts fall back to the current ("now") reading. The
            // per-card HoverHandlers pick the hour while inside; this is the robust catch-all
            // for leaving the section (a fast exit can skip a card's own hovered=false, and
            // a stale identity-guard miss would otherwise leave the header stuck on an hour).
            HoverHandler { onHoveredChanged: if (!hovered) full.hoveredHourSample = null }

            // track scroll direction so cards deal in from the side they enter
            property real _prevContentX: 0
            property int scrollDir: 1   // 1 = entering from right, -1 = from left
            onContentXChanged: {
                scrollDir = contentX >= _prevContentX ? 1 : -1;
                _prevContentX = contentX;
                full.leadDay = full.leadingDay(contentX);
            }
            // the user took the strip itself: the edge day is the selection again
            onMovementStarted: full.chosenDay = -1

            // A free drag/flick settles at an arbitrary offset, cropping the cards
            // at both edges. Snap the resting offset to the nearest card boundary.
            onMovementEnded: {
                var t = full.nearestCardX(contentX);
                if (Math.abs(t - contentX) > 1) {
                    scrollAnim.stop();
                    scrollAnim.from = contentX;
                    scrollAnim.to = t;
                    scrollAnim.start();
                }
            }

            // vertical mouse wheel (or touchpad) scrolls the strip horizontally,
            // animated through the same scrollAnim used by tab clicks. One notch
            // (120) moves cardsPerScroll cards; touchpad pixel deltas move 1:1.
            WheelHandler {
                id: stripWheel
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                // Whole notches only. A touchpad reports many small angle deltas, and
                // dividing each one by 120 gave fractional steps that then rounded
                // differently depending on where the strip happened to be resting —
                // which is why "1 card per scroll" sometimes moved two.
                property real acc: 0
                onWheel: (wheel) => {
                    // Consume the event. This handler sits ON a Flickable, which does
                    // its own wheel scrolling — leaving the event unaccepted lets both
                    // act on the same notch, and the strip travels further than a step.
                    wheel.accepted = true;
                    var maxX = Math.max(0, hourlyFlick.contentWidth - hourlyFlick.width);
                    var ad = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                    var pd = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.pixelDelta.x;
                    // touchpad pixel deltas stay continuous (clamped) to keep scroll smooth
                    if (pd !== 0) {
                        full.chosenDay = -1;
                        scrollAnim.stop();
                        scrollAnim.from = hourlyFlick.contentX;
                        scrollAnim.to = Math.max(0, Math.min(maxX, hourlyFlick.contentX - pd));
                        scrollAnim.start();
                        return;
                    }
                    var dir = Wheel.step(stripWheel, ad);
                    if (dir === 0) return;
                    // chain off the in-flight target so rapid notches stack
                    var base = scrollAnim.running ? scrollAnim.to : hourlyFlick.contentX;
                    var targetX = full.stepCardsX(base, dir * (weatherRoot ? weatherRoot.cardsPerScroll : 1));
                    // a notch against the end stop moves nothing, so it leaves a
                    // picked day selected rather than flipping the highlight back
                    if (Math.abs(targetX - base) < 0.5) return;
                    full.chosenDay = -1;
                    scrollAnim.stop();
                    scrollAnim.from = hourlyFlick.contentX;
                    scrollAnim.to = targetX;
                    scrollAnim.start();
                }
            }

            NumberAnimation {
                id: scrollAnim
                target: hourlyFlick
                property: "contentX"
                duration: 140
                easing.type: Easing.OutCubic
                onFinished: full.pendingDay = -1   // chain closed; resume from selectedDay
            }

            Row {
                id: hourlyRow
                spacing: full.hourGap

                Repeater {
                    model: timelineModel
                    delegate: Loader {
                        id: cardLoader
                        required property int index
                        required property var entry        // the timeline element (see timelineModel)
                        // everything inside the card reads `modelData`, as it did when the
                        // Repeater was fed the array directly
                        readonly property var modelData: entry
                        sourceComponent: modelData.dayBreak ? dayBreakCard : hourCard

                        // "Deal The Cards" entrance: slide in from the right + fade,
                        // 75 ms stagger per card. Resting state is visible — the
                        // card is only hidden when a deal is triggered, so cards
                        // created later (data refresh) just show normally.
                        transform: [
                            Translate { id: dealTr },
                            Scale {
                                id: dealScale
                                origin.x: cardLoader.width / 2
                                origin.y: cardLoader.height / 2
                                yScale: xScale
                            }
                        ]
                        SequentialAnimation {
                            id: dealAnim
                            // cap the stagger at ~the visible strip so offscreen
                            // cards don't lag seconds behind. Clamped at 0 too: a
                            // delegate being removed reports index -1, and a negative
                            // duration is rejected with a warning per card.
                            PauseAnimation { duration: Math.max(0, Math.min(cardLoader.index - full.dealBase, 10)) * full.dealStagger }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: cardLoader; property: "opacity"
                                    from: 0; to: 1; duration: full.dealDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                                }
                                NumberAnimation {
                                    target: dealTr; property: "x"
                                    from: 60; to: 0; duration: full.dealDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                                }
                                NumberAnimation {
                                    target: dealScale; property: "xScale"
                                    from: 0.75; to: 1; duration: full.dealDuration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                                }
                            }
                        }
                        function deal() {
                            // Only cards on screen take part. The strip holds a week of
                            // cards and animating all of them on every open is wasted
                            // work; the rest come to rest immediately and still slide in
                            // as they are scrolled into view (slideIn below).
                            // (A strip not laid out yet has no view to test against, so
                            // everything deals, as it always did.)
                            if (hourlyFlick.width > 0 && !inView) {
                                dealAnim.stop();
                                slideInAnim.stop();
                                opacity = 1;
                                dealTr.x = 0;
                                dealScale.xScale = 1;
                                return;
                            }
                            opacity = 0;
                            dealTr.x = 60;
                            dealScale.xScale = 0.75;
                            dealAnim.restart();
                        }
                        Connections {
                            target: full
                            function onDealRunChanged() { cardLoader.deal(); }
                        }

                        // Re-deal each card as it scrolls/drags into view — same
                        // slide+fade as the entrance, dealt from the side it enters.
                        // Gated on full.scrolling so it never fights the entrance
                        // (which runs with no scroll in progress).
                        readonly property bool inView:
                            (x + width) > hourlyFlick.contentX
                            && x < (hourlyFlick.contentX + hourlyFlick.width)
                        onInViewChanged: if (inView && full.scrolling)
                                             slideIn(hourlyFlick.scrollDir < 0 ? -130 : 130)
                        // Qt Quick draws every card in the strip on every frame, not only the
                        // ones its clip lets through, and each card carries its own Canvas
                        // texture that nothing can batch: a week of cards cost the popup a
                        // few milliseconds of every frame whenever anything on it moved. So
                        // cards off the strip are hidden from the renderer, with a card's
                        // margin either side so none pops in at an edge. The card is hidden,
                        // not this Loader, so the Row keeps every card's place.
                        readonly property bool onStrip:
                            (x + width) > hourlyFlick.contentX - width
                            && x < (hourlyFlick.contentX + hourlyFlick.width + width)
                        Binding {
                            target: cardLoader.item; property: "visible"; value: cardLoader.onStrip
                            when: cardLoader.item !== null
                        }
                        ParallelAnimation {
                            id: slideInAnim
                            NumberAnimation {
                                target: cardLoader; property: "opacity"; to: 1; duration: 650
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                            }
                            NumberAnimation {
                                target: dealTr; property: "x"; to: 0; duration: 650
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                            }
                            NumberAnimation {
                                target: dealScale; property: "xScale"; to: 1; duration: 650
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                            }
                        }
                        function slideIn(fromX) {
                            opacity = 0;
                            dealTr.x = fromX;
                            dealScale.xScale = 0.75;
                            slideInAnim.restart();
                        }

                        Component {
                            id: dayBreakCard
                            Item {
                                width: full.dayBreakW
                                height: full.hourCardH
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.bold: true
                                    opacity: 0.8
                                }
                            }
                        }

                        Component {
                            id: hourCard
                            Rectangle {
                                id: card
                                width: full.hourCardW
                                height: full.hourCardH
                                radius: 8
                                // the hour this card shows, aliased so the inner metric
                                // Repeater (whose own modelData is a metric id) can reach it
                                readonly property var hourData: modelData

                                // hovering a card feeds its hour to the header metrics; the
                                // identity guard means sliding A→B doesn't let A's exit wipe
                                // B's freshly-set value (whichever order the events fire).
                                HoverHandler {
                                    onHoveredChanged: {
                                        if (hovered) full.hoveredHourSample = card.hourData;
                                        else if (full.hoveredHourSample === card.hourData) full.hoveredHourSample = null;
                                    }
                                }

                                // is this card within the visible strip? (parent is the
                                // Loader, whose x is its position in the flickable content)
                                readonly property bool inView:
                                    (parent.x + width) > hourlyFlick.contentX
                                    && parent.x < (hourlyFlick.contentX + hourlyFlick.width)
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                                      Kirigami.Theme.textColor.b, 0.11)

                                // "Corner split" precip wash: rain blooms blue from the
                                // bottom-left, snow white from the top-right, each sized
                                // and brightened by its share of the chance (so a wintry
                                // mix shows both). Behind the content, clipped to the
                                // rounded card; blank for dry hours. See precip-corner-split.js.
                                Canvas {
                                    id: tide
                                    anchors.fill: parent
                                    // wash intensity, not the raw chance: a sample with no chance
                                    // (met.no outside the Nordics) falls back to its amount, so
                                    // its rain still shows (see precipWashPct)
                                    readonly property real precip:  weatherRoot ? weatherRoot.precipWashPct(modelData) : 0
                                    // raining, but no chance to scale by → never less than the minimum
                                    readonly property bool minWash: weatherRoot ? weatherRoot.precipWithoutChance(modelData) : false
                                    readonly property real snowFrac: full.snowFraction(modelData.code, modelData.precip, modelData.precipAmt, modelData.snow, modelData.temp)
                                    onPrecipChanged:   requestPaint()
                                    onMinWashChanged:  requestPaint()
                                    onSnowFracChanged: requestPaint()
                                    onWidthChanged:    requestPaint()
                                    onHeightChanged:   requestPaint()
                                    Component.onCompleted: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d"); ctx.reset();
                                        var w = width, h = height;
                                        var t = full.rainTideT(precip);
                                        if (tide.minWash && t < full.rainTideMinT) t = full.rainTideMinT;
                                        if (t <= 0 || w <= 0 || h <= 0) return;
                                        // clip to the card's rounded rect so the blooms
                                        // don't square off the corners
                                        var r = card.radius;
                                        ctx.beginPath();
                                        ctx.moveTo(r, 0);
                                        ctx.arcTo(w, 0, w, h, r);
                                        ctx.arcTo(w, h, 0, h, r);
                                        ctx.arcTo(0, h, 0, 0, r);
                                        ctx.arcTo(0, 0, w, 0, r);
                                        ctx.closePath();
                                        ctx.clip();
                                        var diag = Math.max(w, h);
                                        var snowT = t * tide.snowFrac;          // top-right, white
                                        var rainT = t * (1 - tide.snowFrac);    // bottom-left, blue
                                        if (snowT > 0) {
                                            var sR = (0.5 + snowT * 0.6) * diag;
                                            var g = ctx.createRadialGradient(w, 0, 0, w, 0, sR);
                                            g.addColorStop(0,   full.tideRgbaStr(full.snowWhite, 0.20 + 0.40 * snowT));
                                            g.addColorStop(0.7, full.tideRgbaStr(full.snowWhite, 0));
                                            g.addColorStop(1,   full.tideRgbaStr(full.snowWhite, 0));
                                            ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
                                        }
                                        if (rainT > 0) {
                                            var rR = (0.5 + rainT * 0.6) * diag;
                                            var g2 = ctx.createRadialGradient(0, h, 0, 0, h, rR);
                                            g2.addColorStop(0,   full.tideRgbaStr(full.rainBlue, 0.18 + 0.40 * rainT));
                                            g2.addColorStop(0.7, full.tideRgbaStr(full.rainBlue, 0));
                                            g2.addColorStop(1,   full.tideRgbaStr(full.rainBlue, 0));
                                            ctx.fillStyle = g2; ctx.fillRect(0, 0, w, h);
                                        }
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Kirigami.Units.smallSpacing * 2
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.pixelSize: Math.round((weatherRoot ? weatherRoot.hourlyCardFontSize : 11) * 1.1)
                                        font.bold: true
                                        text: weatherRoot ? weatherRoot.formatSlot(modelData) : ""
                                    }
                                    ConditionIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth:  weatherRoot ? weatherRoot.hourlyIconSize : 32
                                        Layout.preferredHeight: weatherRoot ? weatherRoot.hourlyIconSize : 32
                                        weatherRoot: full.weatherRoot
                                        // probability-aware code: a likely-rain hour shows rain even if the code reads cloudy
                                        code: weatherRoot ? weatherRoot.precipAwareCode(modelData.code, modelData.precip, modelData.precipAmt, modelData.snow, modelData.temp) : modelData.code
                                        day: modelData.day
                                        cloud: modelData.cloud
                                        animate: weatherRoot ? weatherRoot.animatedHourlyIcons : false
                                        // cards share one animation per condition, so a card scrolled
                                        // in shows a condition already on screen at once; one not yet
                                        // built waits for the strip to rest
                                        canBuild: full.iconsLive && !full.scrolling
                                        // moves only while on screen, and holds still while scrolling
                                        playing: full.onScreen && card.inView && !full.scrolling
                                    }
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.bold: true
                                        font.pixelSize: weatherRoot ? weatherRoot.hourlyTempFontSize : 13
                                        text: weatherRoot ? weatherRoot.tempStr(modelData.temp) : ""
                                    }
                                    // two configurable readouts (Appearance → Detailed →
                                    // Hourly cards). Each slot resolves its primary metric
                                    // against this card's hour (card.hourData), falling back
                                    // to the slot's fallback metric when the primary is empty
                                    // (e.g. dry hour for snow → precip chance). `effId` is the
                                    // metric that actually produced the value, so the icon and
                                    // wind glyph follow the fallback when it kicks in.
                                    Repeater {
                                        model: weatherRoot ? weatherRoot.hourlyMetrics : []
                                        delegate: RowLayout {
                                            id: hMetricRow
                                            required property int index
                                            required property var modelData   // a readout slot { id, fallback }
                                            readonly property var m: card.hourData
                                            readonly property var ro: weatherRoot ? weatherRoot.hourlyReadout(modelData, m) : ({ id: "", val: "" })
                                            readonly property string effId: ro.id
                                            readonly property string val: ro.val
                                            Layout.alignment: Qt.AlignHCenter
                                            // Put the extra gap BELOW line 1 (above line 2) rather
                                            // than above line 1: nudges the first readout up toward
                                            // the temp and widens the gap to the second readout. Total
                                            // column height is unchanged, so the centered cluster holds.
                                            Layout.topMargin: index === 0 ? 0 : Kirigami.Units.smallSpacing
                                            // Always reserve the row's height (even when this hour has
                                            // no value for the metric) so the centered cluster above
                                            // doesn't shift; the contents simply hide when val is empty.
                                            Layout.preferredHeight: full.hourMetricRowH
                                            spacing: 2
                                            Text {   // leading metric glyph from the BUNDLED weather-
                                                     // icons font (wiFont) — identical for every user,
                                                     // unlike a system-theme icon. Wind has none here
                                                     // (its direction arrow trails the label instead).
                                                readonly property string glyph: weatherRoot ? weatherRoot.hourlyMetricGlyph(hMetricRow.effId) : ""
                                                visible: hMetricRow.val.length > 0 && glyph.length > 0
                                                text: glyph
                                                color: Kirigami.Theme.textColor
                                                opacity: 0.75
                                                font.family: weatherRoot ? weatherRoot.wiFontFamily : ""
                                                font.pixelSize: Math.round((weatherRoot ? weatherRoot.hourlyCardFontSize : 11)
                                                    * (weatherRoot ? weatherRoot.hourlyMetricGlyphScale(hMetricRow.effId) : 1.5))
                                            }
                                            Label {
                                                font.pixelSize: weatherRoot ? weatherRoot.hourlyCardFontSize : 11
                                                opacity: 0.9
                                                text: hMetricRow.val
                                                // default theme text (white) — card readouts aren't colour-coded
                                            }
                                            Kirigami.Icon {   // wind direction (wind / wind+gust metrics)
                                                visible: hMetricRow.val.length > 0 && (hMetricRow.effId === "wind" || hMetricRow.effId === "windGust") && hMetricRow.m && !isNaN(hMetricRow.m.windDir)
                                                source: Qt.resolvedUrl("../icons/wind-direction.svg")
                                                isMask: true
                                                color: Kirigami.Theme.textColor
                                                roundToIconSize: false
                                                rotation: (weatherRoot && hMetricRow.m) ? weatherRoot.windArrowRotation(hMetricRow.m.windDir) : 0
                                                // a little air after the reading it belongs to
                                                Layout.leftMargin: Kirigami.Units.smallSpacing
                                                Layout.preferredWidth: weatherRoot ? weatherRoot.windArrowSize : 21
                                                Layout.preferredHeight: Layout.preferredWidth
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
