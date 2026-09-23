/*
 * A weather-condition icon for the popup. It draws the active pack's static SVG,
 * and where the view animates icons at this spot it shows the pack's animated SVG
 * instead. The icon fills this item, scaled by the pack's per-condition zoom
 * (main.qml iconZoom), in both forms alike.
 *
 * Animated icons are shared: every ConditionIcon showing the same picture at the
 * same size draws one ConditionIconShared, handed out by AnimatedIconCache. Only
 * what is asked for is loaded: a static-only spot never touches the animated files,
 * nor the VectorImage module, and only the monochrome pack loads the effects
 * module that tints it.
 *
 * Static icons are drawn by an Image, not Kirigami.Icon. Image shares one raster
 * per icon and size between every copy (Qt's pixmap cache); in Plasma,
 * Kirigami.Icon re-reads and re-renders the SVG for each of the hundred or so
 * icons the two layouts hold, which measured ~200 ms of every popup open.
 *
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: icon
    property var weatherRoot: null
    property int code: -1
    property int day: 1
    property real cloud: NaN
    // The view's animation option for this spot.
    property bool animate: false
    // The view's go-ahead to build an animated icon nobody has built yet. It takes
    // a few milliseconds, so views hold this back until the popup is open and its
    // entrance has played (the static icon looks the same at rest), and the graph
    // also while it scrolls. An icon someone already built is used at once.
    property bool canBuild: true
    // Let the animation move; false holds it on its current frame.
    property bool playing: false

    readonly property real zoom: weatherRoot ? weatherRoot.iconZoom(code, day) : 1
    readonly property string animSource: (animate && weatherRoot)
        ? weatherRoot.conditionIconAnimated(code, day, cloud) : ""

    // ── the static icon ──
    readonly property string stillSource: weatherRoot ? weatherRoot.conditionIcon(code, day, cloud)
                                                      : "weather-none-available"
    // a file (bundled or custom pack) rather than an icon-theme name
    readonly property bool _stillIsFile: stillSource.indexOf("file:") === 0
    // The software renderer can't run shaders: no tint effect, and VectorImage's
    // masks come out missing (an icon's sun or moon would vanish).
    readonly property bool _softwareRendered: icon.GraphicsInfo.api === GraphicsInfo.Software
    readonly property bool _tinted: weatherRoot ? weatherRoot.iconPackIsMask : false
    readonly property int _px: Math.round(width * zoom)

    Image {
        anchors.centerIn: parent
        width: icon._px
        height: width
        sourceSize: Qt.size(width, height)
        visible: !icon._vectorShown
        source: (icon._stillIsFile && !icon._tinted) ? icon.stillSource : ""
    }
    Loader {
        id: tintedStill
        anchors.centerIn: parent
        width: icon._px
        height: width
        active: icon._stillIsFile && icon._tinted && !icon._softwareRendered
        visible: !icon._vectorShown
        source: active ? "ConditionIconStillTinted.qml" : ""
    }
    Binding { target: tintedStill.item; property: "source"; value: icon.stillSource; when: tintedStill.item !== null }
    Binding { target: tintedStill.item; property: "tint"; value: Kirigami.Theme.textColor; when: tintedStill.item !== null }
    // Icon-theme names (the System pack, and "no data yet"), plus the monochrome
    // pack where the tint effect can't run: Kirigami.Icon tints it by itself.
    Kirigami.Icon {
        anchors.centerIn: parent
        width: icon._px
        height: width
        roundToIconSize: false   // honour the exact zoom; don't snap to 32/48
        visible: !icon._vectorShown
        readonly property bool wanted: !icon._stillIsFile || (icon._tinted && icon._softwareRendered)
        isMask: icon._tinted
        color: Kirigami.Theme.textColor
        source: wanted ? icon.stillSource : ""
    }

    // ── the animated icon ──
    readonly property var _cache: weatherRoot ? weatherRoot.iconCache : null
    // which shared icon this one wants ("" = none; software-rendered sessions stay static)
    readonly property string _wantKey: (animSource !== "" && _cache && !_softwareRendered)
        ? _cache.key(animSource, _px, _tinted) : ""
    property Item _shared: null
    readonly property bool _vectorShown: _shared !== null && _shared.ok
    // read by AnimatedIconCache: a shared icon moves while any of its users would
    readonly property bool wantsToPlay: playing && visible && _vectorShown

    function _release() {
        if (!_shared) return;
        var h = _shared;
        _shared = null;
        if (_cache) _cache.detach(h, icon);
    }
    function _sync() {
        var k = _wantKey;
        if (k === "" || !visible) { _release(); return; }
        if (_shared && _shared.key === k) return;
        var h = _cache.find(k);
        if (!h && !canBuild) { _release(); return; }   // static until building is allowed
        _release();
        _shared = h || _cache.create(k, animSource, _px, _tinted);
        _cache.attach(_shared, icon);
    }
    on_WantKeyChanged: _sync()
    onCanBuildChanged: _sync()
    onVisibleChanged: _sync()
    onWantsToPlayChanged: if (_shared && _cache) _cache.refresh(_shared)
    Component.onCompleted: _sync()
    Component.onDestruction: _release()

    ShaderEffect {
        anchors.centerIn: parent
        width: icon._px
        height: width
        visible: icon._vectorShown
        // no shaders given: the default ones draw `source`
        property var source: icon._shared ? icon._shared.texture : null
    }
}
