import QtQuick
import QtQuick.Window
import EarthSky.Globe 1.0

Window {
    id: window
    width: 1280
    height: 752
    minimumWidth: 720
    minimumHeight: 472
    visible: true
    title: "Earth & Sky"
    color: "#080f18"
    property bool globeMode: false
    readonly property var skyModel: sky
    onClosing: sky.stopAnimation()
    onVisibleChanged: { if (!visible) sky.stopAnimation() }
    Shortcut { sequence: "Escape"; enabled: !intervalMenu.visible; onActivated: sky.stopAnimation() }

    Connections {
        target: sky
        function onFrameRebased(turns) {
            mapViewport.resettingFollow = true
            mapViewport.centerX -= turns
            mapViewport.resettingFollow = false
            globe.yaw -= turns * 360
        }
    }
    // Camera coordinates are normalized and longitude wraps rather than clamping.
    Item {
        id: mapViewport
        visible: !window.globeMode
        objectName: "mapViewport"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        clip: true
        property bool horizonActive: false
        property real observerLongitude: 0.5
        property real observerLatitude: 0
        function setHorizonAt(px, py) {
            const longitude = wrapUnit(cameraX - sky.earthOffset + (px - width / 2) / map.width)
            const latitude = Math.max(-90, Math.min(90, 90 - 180 * (boundedCenterY + (py - height / 2) / map.height)))
            setObserver(longitude * 360 - 180, latitude)
        }
        function setObserver(longitude, latitude) {
            observerLongitude = wrapUnit((longitude + 180) / 360); observerLatitude = latitude
            horizonActive = true
            beginFollow("place", observerLongitude, (90 - latitude) / 180, "", zoom)
        }
        property real zoom: 1
        property real centerX: 0.5
        property real centerY: 0.5
        property bool dragging: false
        property bool resettingFollow: false
        property string followKind: "none"
        property string followBody: ""
        property real followLongitude: 0.5
        property real followLatitude: 0.5
        property real followBlend: 0
        readonly property var trackedMarker: {
            const markers = sky.markers
            for (let i = 0; i < markers.length; ++i)
                if (markers[i].name === followBody) return markers[i]
            return null
        }
        readonly property real targetX: followKind === "body" && trackedMarker ? trackedMarker.x + sky.skyOffset
                                      : followKind === "place" ? followLongitude + sky.earthOffset : centerX
        readonly property real targetY: followKind === "body" && trackedMarker ? trackedMarker.y
                                      : followKind === "place" ? followLatitude : centerY
        readonly property real cameraX: centerX + wrapDelta(targetX - centerX) * followBlend
        readonly property real cameraY: centerY + (targetY - centerY) * followBlend
        readonly property real boundedCenterY: Math.max(0.5 / zoom, Math.min(1 - 0.5 / zoom, cameraY))
        readonly property bool fitted: !horizonActive && followKind === "none" && Math.abs(zoom - 1) < 0.001 && Math.abs(centerX - 0.5) < 0.001 && Math.abs(centerY - 0.5) < 0.001
        function wrapUnit(value) { return ((value % 1) + 1) % 1 }
        function wrapDelta(value) { return wrapUnit(value + 0.5) - 0.5 }
        function releaseFollow() {
            const heldX = cameraX, heldY = boundedCenterY
            resettingFollow = true
            followKind = "none"; followBody = ""; followBlend = 0
            centerX = heldX; centerY = heldY
            resettingFollow = false
        }
        function beginFollow(kind, longitude, latitude, body, nextZoom) {
            releaseFollow()
            followLongitude = wrapUnit(longitude)
            followLatitude = latitude
            followBody = body
            followKind = kind
            zoom = nextZoom
            followBlend = 1
        }
        function fitMap() { horizonActive = false; releaseFollow(); zoom = 1; centerX = 0.5; centerY = 0.5 }
        function zoomAt(px, py, requested, recenter) {
            const next = Math.max(1, Math.min(8, requested))
            if (next === 1 && !horizonActive) { fitMap(); return }
            if (followKind === "body" && !recenter) { zoom = next; return }
            const pointX = cameraX + (px - width / 2) / (width * zoom)
            const pointY = boundedCenterY + (py - height / 2) / (height * zoom)
            const nextX = recenter ? pointX : pointX - (px - width / 2) / (width * next)
            const nextY = Math.max(0.5 / next, Math.min(1 - 0.5 / next,
                         recenter ? pointY : pointY - (py - height / 2) / (height * next)))
            beginFollow("place", nextX - sky.earthOffset, nextY, "", next)
        }
        function bodyAt(px, py) {
            const markers = sky.markers
            // Hit-test the nearer, visually topmost bodies first.
            for (let i = markers.length - 1; i >= 0; --i) {
                const marker = markers[i]
                const shown = marker.name === "Sun" ? sunToggle.checked : marker.name === "Moon" ? moonToggle.checked : planetsToggle.checked
                if (!shown) continue
                const x = width / 2 + wrapDelta(marker.x + sky.skyOffset - cameraX) * map.width
                const y = height / 2 + (marker.y - boundedCenterY) * map.height
                for (let copy = -1; copy <= 1; ++copy)
                    if (Math.hypot(px - x - copy * map.width, py - y) <= Math.max(marker.size / 2 + 4, 10)) return marker
            }
            return null
        }
        function selectAt(px, py) { setHorizonAt(px, py) }
        function lockPlaceAtCenter() {
            beginFollow("place", cameraX - sky.earthOffset, boundedCenterY, "", zoom)
        }
        Behavior on zoom { enabled: !mapViewport.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on centerX { enabled: !mapViewport.dragging && !mapViewport.resettingFollow; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on centerY { enabled: !mapViewport.dragging && !mapViewport.resettingFollow; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on followBlend { enabled: !mapViewport.dragging && !mapViewport.resettingFollow; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Item {
            id: map
            width: mapViewport.width * mapViewport.zoom
            height: mapViewport.height * mapViewport.zoom
            readonly property int skyRasterWidth: Math.min(2560, Math.max(1, Math.round(width)))
            readonly property int skyRasterHeight: Math.max(1, Math.round(skyRasterWidth * height / Math.max(1, width)))
            y: mapViewport.height / 2 - mapViewport.boundedCenterY * height
            // Adjacent tiles share cached textures and hide the longitude seam.
            Repeater {
                model: [-1, 0, 1]
                delegate: Image {
                    required property int modelData
                    x: mapViewport.width / 2 - mapViewport.wrapUnit(mapViewport.cameraX - sky.earthOffset) * map.width + modelData * map.width
                    width: map.width; height: map.height
                    source: "image://earth/day"
                    sourceSize.width: 5400
                    smooth: true
                }
            }
            Repeater {
                model: [-1, 0, 1]
                delegate: Item {
                    required property int modelData
                    x: mapViewport.width / 2 - mapViewport.wrapUnit(mapViewport.cameraX - sky.skyOffset) * map.width + modelData * map.width
                    width: map.width; height: map.height
                    Image {
                        anchors.fill: parent
                        source: "image://earth/night/" + sky.revision
                        cache: true
                        smooth: true
                    }
                    Image {
                        anchors.fill: parent
                        visible: constellationsToggle.checked || allConstellationsToggle.checked
                        source: visible ? "image://earth/zodiac/" + (allConstellationsToggle.checked ? "all/" : "") + (labelsToggle.checked ? "labels/" : "no-labels/") + sky.revision : ""
                        sourceSize: Qt.size(map.skyRasterWidth, map.skyRasterHeight)
                        cache: true
                        smooth: true
                    }
                    // Keep marker sizes readable while zooming the geographic area.
                    Repeater {
                        model: 7
                        delegate: Item {
                            required property int index
                            readonly property var marker: sky.markers[index]
                            visible: marker.name === "Sun" ? sunToggle.checked
                                     : marker.name === "Moon" ? moonToggle.checked : planetsToggle.checked
                            x: marker.x * map.width
                            y: marker.y * map.height
                            Image {
                                anchors.centerIn: parent
                                width: marker.size; height: marker.size
                                source: "image://earth/" + marker.image
                                cache: true
                                smooth: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: marker.size * (marker.name === "Sun" ? 0.42 : marker.name === "Moon" ? 0.48 : 0.31)
                                visible: labelsToggle.checked
                                text: marker.name
                                font.family: "Segoe UI"
                                font.pixelSize: 9
                                color: "#a5a9ad"
                                style: Text.Outline
                                styleColor: "#182330"
                            }
                        }
                    }
                }
            }
            // Parallels are longitude-independent; keep their labels at the viewport edges.
            Item {
                id: latitudeLinesOverlay
                objectName: "latitudeLinesOverlay"
                width: mapViewport.width
                height: map.height
                visible: latitudeLinesToggle.checked
                Repeater {
                    model: [0, 23.44, -23.44, 66.56, -66.56]
                    delegate: Item {
                        id: parallel
                        required property real modelData
                        readonly property real latitude: modelData
                        readonly property bool equator: latitude === 0
                        readonly property string degreeLabel: equator ? "0\u00b0" : (latitude > 0 ? "+" : "") + latitude.toFixed(2) + "\u00b0"
                        width: latitudeLinesOverlay.width
                        height: equator ? 1.2 : 0.7
                        y: (90 - latitude) / 180 * latitudeLinesOverlay.height - height / 2
                        Rectangle {
                            anchors.fill: parent
                            color: parallel.equator ? "#647bbd70" : "#4a6caa66"
                            antialiasing: true
                        }
                        Repeater {
                            model: 3
                            delegate: Text {
                                required property int index
                                objectName: "latitudeLabel"
                                visible: labelsToggle.checked
                                text: parallel.degreeLabel
                                x: index === 0 ? 6 : index === 1 ? (parallel.width - implicitWidth) / 2 : parallel.width - implicitWidth - 6
                                y: -implicitHeight - 3
                                font.family: "Segoe UI"
                                font.pixelSize: 9
                                color: parallel.equator ? "#c39ac68b" : "#b38bb77f"
                                style: Text.Outline
                                styleColor: "#99101c17"
                            }
                        }
                    }
                }
            }
        }
        Canvas {
            id: horizonOverlay
            objectName: "horizonOverlay"
            anchors.fill: parent
            visible: mapViewport.horizonActive
            z: 2
            onVisibleChanged: if (visible) requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: mapViewport
                function onObserverLatitudeChanged() { horizonOverlay.requestPaint() }
                function onObserverLongitudeChanged() { horizonOverlay.requestPaint() }
                function onBoundedCenterYChanged() { horizonOverlay.requestPaint() }
                function onZoomChanged() { horizonOverlay.requestPaint() }
                function onCameraXChanged() { horizonOverlay.requestPaint() }
            }
            onPaint: {
                const c = getContext("2d")
                c.clearRect(0, 0, width, height)
                if (!visible) return
                const r = Math.PI / 180, phi = mapViewport.observerLatitude * r
                const equator = Math.abs(phi) < 1e-8, north = phi > 0
                const mapWidth = map.width, mapHeight = map.height
                function deltaAt(x) {
                    const lon = mapViewport.cameraX - sky.earthOffset + (x - width / 2) / mapWidth
                    return mapViewport.wrapDelta(lon - mapViewport.observerLongitude) * 2 * Math.PI
                }
                function edgeY(x) {
                    const lat = north ? Math.atan2(-Math.cos(phi) * Math.cos(deltaAt(x)), Math.sin(phi))
                                      : Math.atan2(Math.cos(phi) * Math.cos(deltaAt(x)), -Math.sin(phi))
                    return height / 2 + ((90 - lat / r) / 180 - mapViewport.boundedCenterY) * mapHeight
                }
                c.fillStyle = "rgba(8,15,24,0.84)"
                if (equator) {
                    for (let x = 0; x < width; ++x)
                        if (Math.cos(deltaAt(x + 0.5)) < 0) c.fillRect(x, 0, 1, height)
                } else {
                    c.beginPath(); c.moveTo(0, north ? height : 0)
                    for (let x = 0; x <= width; ++x) c.lineTo(x, edgeY(x))
                    c.lineTo(width, north ? height : 0); c.closePath(); c.fill()
                }
                c.strokeStyle = "rgba(146,191,204,0.65)"; c.lineWidth = 1
                c.beginPath()
                if (equator) {
                    for (let side of [-1, 1]) {
                        const x = width / 2 + mapViewport.wrapDelta(mapViewport.observerLongitude + sky.earthOffset + side / 4 - mapViewport.cameraX) * mapWidth
                        c.moveTo(x, 0); c.lineTo(x, height)
                    }
                } else {
                    for (let x = 0; x <= width; ++x) {
                        const y = edgeY(x)
                        if (x === 0) c.moveTo(x, y); else c.lineTo(x, y)
                    }
                }
                c.stroke()
                const x = width / 2 + mapViewport.wrapDelta(mapViewport.observerLongitude + sky.earthOffset - mapViewport.cameraX) * mapWidth
                const y = height / 2 + ((90 - mapViewport.observerLatitude) / 180 - mapViewport.boundedCenterY) * mapHeight
                c.strokeStyle = "#d2e5ec"; c.lineWidth = 1.3
                c.beginPath(); c.arc(x, y, 4, 0, 2 * Math.PI); c.stroke()
                c.beginPath(); c.moveTo(x - 9, y); c.lineTo(x - 5, y); c.moveTo(x + 5, y); c.lineTo(x + 9, y)
                c.moveTo(x, y - 9); c.lineTo(x, y - 5); c.moveTo(x, y + 5); c.lineTo(x, y + 9); c.stroke()
            }
        }
        MouseArea {
            id: mapInput
            objectName: "mapInput"
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: pressed && moved ? Qt.ClosedHandCursor : mapViewport.zoom > 1.001 ? Qt.OpenHandCursor : Qt.PointingHandCursor
            property real pressX
            property real pressY
            property real pressCenterX
            property real pressCenterY
            property bool moved: false
            onPressed: mouse => {
                pressX = mouse.x; pressY = mouse.y
                pressCenterX = mapViewport.cameraX; pressCenterY = mapViewport.boundedCenterY
                moved = false; mapViewport.dragging = true
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                if (!moved && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 4) {
                    moved = true; mapViewport.releaseFollow()
                }
                if (moved) {
                    mapViewport.centerX = pressCenterX - (mouse.x - pressX) / map.width
                    mapViewport.centerY = Math.max(0.5 / mapViewport.zoom, Math.min(1 - 0.5 / mapViewport.zoom,
                                                   pressCenterY - (mouse.y - pressY) / map.height))
                }
            }
            onReleased: {
                if (moved) mapViewport.lockPlaceAtCenter()
                mapViewport.dragging = false
            }
            onCanceled: mapViewport.dragging = false
            onClicked: mouse => { if (!moved) mapViewport.selectAt(mouse.x, mouse.y) }
            onDoubleClicked: mouse => { mouse.accepted = true; mapViewport.selectAt(mouse.x, mouse.y) }
            onWheel: wheel => {
                const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y / 120 : wheel.pixelDelta.y / 40
                if (delta !== 0) mapViewport.zoomAt(wheel.x, wheel.y, mapViewport.zoom * Math.pow(1.25, delta), false)
                wheel.accepted = true
            }
        }
    }

    GlobeView {
        id: globe
        objectName: "globeView"
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: footer.top
        visible: window.globeMode
        sky: window.skyModel
        layers: ({sun: sunToggle.checked, moon: moonToggle.checked, planets: planetsToggle.checked,
                  zodiac: constellationsToggle.checked, allConstellations: allConstellationsToggle.checked,
                  latitudeLines: latitudeLinesToggle.checked, labels: labelsToggle.checked})
        horizonActive: mapViewport.horizonActive
        observer: Qt.point(mapViewport.observerLongitude * 360 - 180, mapViewport.observerLatitude)
        onLocationSelected: (longitude, latitude) => { mapViewport.setObserver(longitude, latitude); globe.centerOn(longitude, latitude) }
    }
    Rectangle {
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10
        width: 112; height: 28; radius: 6; z: 20
        color: "#dd101d29"; border.color: "#344754"
        TimeAction {
            objectName: "flatMapViewButton"
            x: 0; width: 56; height: 28
            label: "Flat map"; highlighted: !window.globeMode
            description: "View the sky above a flat world map"
            onTriggered: window.globeMode = false
        }
        Rectangle { x: 56; y: 7; width: 1; height: 14; color: "#344754" }
        TimeAction {
            objectName: "globeViewButton"
            x: 56; width: 56; height: 28
            label: "Globe"; highlighted: window.globeMode
            description: "View Earth inside a celestial sphere; drag to turn and scroll to zoom"
            onTriggered: {
                window.globeMode = true
                if (mapViewport.horizonActive) globe.centerOn(mapViewport.observerLongitude * 360 - 180, mapViewport.observerLatitude)
            }
        }
    }
    Text {
        visible: window.globeMode
        anchors.horizontalCenter: parent.horizontalCenter
        y: 15
        text: "Drag to turn · Scroll to zoom"
        font.family: "Segoe UI"; font.pixelSize: 11; color: "#8197aa"
    }
    component VisibilityToggle: Item {
        id: control
        property string label
        property string settingsKey
        property bool initialized: false
        property bool checked: true
        Component.onCompleted: {
            checked = sky.layerVisible(settingsKey)
            initialized = true
        }
        onCheckedChanged: {
            if (initialized) sky.setLayerVisible(settingsKey, checked)
        }
        implicitWidth: track.width + 7 + caption.implicitWidth
        implicitHeight: 32
        width: implicitWidth
        height: implicitHeight
        activeFocusOnTab: true
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        Accessible.description: "Show or hide " + label.toLowerCase()
        Accessible.checkable: true
        Accessible.checked: checked
        Accessible.onToggleAction: checked = !checked
        Keys.onSpacePressed: event => { checked = !checked; event.accepted = true }
        Keys.onReturnPressed: event => { checked = !checked; event.accepted = true }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 5
            color: "transparent"
            border.width: control.activeFocus ? 1 : 0
            border.color: "#71899b"
        }
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 14
            radius: 7
            color: control.checked ? "#3b596a" : "#23303b"
            border.width: 1
            border.color: control.checked ? "#547485" : "#394651"
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                width: 8; height: 8
                radius: 4
                y: 3
                x: control.checked ? 15 : 3
                color: control.checked ? "#c1d1da" : "#74818b"
                Behavior on x { NumberAnimation { duration: 120 } }
            }
        }
        Text {
            id: caption
            anchors.left: track.right
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: control.label
            font.family: "Segoe UI"
            font.pixelSize: 11
            color: control.checked ? "#aab9c4" : "#728390"
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { control.forceActiveFocus(Qt.MouseFocusReason); control.checked = !control.checked }
        }
    }

    // Each half is keyboard-focusable and has its own accessible name.
    component TimeAction: Item {
        id: action
        property int direction: 0
        property bool animate: false
        property bool playing: false
        property bool highlighted: false
        property string label: ""
        property string description
        property bool hintReady: false
        property point hintOrigin: Qt.point(0, 0)
        signal triggered()
        signal held()
        property bool holdEnabled: false
        width: animate ? 21 : direction === 0 ? 48 : 33
        height: 32
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: description
        Accessible.description: description + ". Escape stops animation."
        Accessible.onPressAction: triggered()
        Keys.onSpacePressed: event => { triggered(); event.accepted = true }
        Keys.onReturnPressed: event => { triggered(); event.accepted = true }
        Keys.onEscapePressed: event => { if (intervalMenu.visible) intervalMenu.visible = false; else sky.stopAnimation(); event.accepted = true }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 5
            color: hit.pressed ? "#2b4051" : action.playing ? "#294454" : hit.containsMouse ? "#20303f" : "transparent"
            border.width: action.activeFocus ? 1 : 0
            border.color: "#829bad"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            anchors.centerIn: parent
            visible: action.direction === 0
            text: action.label
            font.family: "Segoe UI"
            font.pixelSize: 11
            color: action.highlighted ? "#d1e0e9" : "#99adbc"
        }
        Canvas {
            id: glyph
            anchors.centerIn: parent
            width: 12; height: 12
            visible: action.direction !== 0
            Connections { target: action; function onPlayingChanged() { glyph.requestPaint() } }
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = action.animate ? "#8196a6" : "#b1c4d2"
                ctx.fillStyle = action.playing ? "#c1d8e5" : "#8196a6"
                if (action.animate) {
                    if (action.playing) {
                        ctx.fillRect(3, 3, 2, 6)
                        ctx.fillRect(7, 3, 2, 6)
                    } else {
                        ctx.beginPath()
                        ctx.moveTo(action.direction < 0 ? 8 : 4, 3)
                        ctx.lineTo(action.direction < 0 ? 3 : 9, 6)
                        ctx.lineTo(action.direction < 0 ? 8 : 4, 9)
                        ctx.closePath()
                        ctx.fill()
                    }
                } else {
                    ctx.lineWidth = 1.5
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(action.direction < 0 ? 8 : 4, 2)
                    ctx.lineTo(action.direction < 0 ? 4 : 8, 6)
                    ctx.lineTo(action.direction < 0 ? 8 : 4, 10)
                    ctx.stroke()
                }
            }
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property bool didHold: false
            onPressed: didHold = false
            onPressAndHold: { if (action.holdEnabled) { didHold = true; action.forceActiveFocus(Qt.MouseFocusReason); action.held() } }
            onClicked: { if (!didHold) { action.forceActiveFocus(Qt.MouseFocusReason); action.triggered() } }
            onDoubleClicked: event => { event.accepted = true; action.triggered() }
            onContainsMouseChanged: { if (!containsMouse) action.hintReady = false }
        }
        Timer {
            interval: 650
            running: hit.containsMouse
            onTriggered: { action.hintOrigin = action.mapToItem(window.contentItem, 0, 0); action.hintReady = true }
        }
        Connections {
            target: window
            function onWidthChanged() { action.hintReady = false }
            function onHeightChanged() { action.hintReady = false }
        }
        Rectangle {
            id: hintBubble
            parent: window.contentItem
            visible: action.hintReady && hit.containsMouse
            z: 100
            width: Math.min(hint.implicitWidth + 18, window.width - 16)
            height: hint.implicitHeight + 12
            x: Math.max(8, Math.min(action.hintOrigin.x + (action.width - hintBubble.width) / 2, window.width - hintBubble.width - 8))
            y: action.hintOrigin.y < height + 12 ? action.hintOrigin.y + action.height + 7 : action.hintOrigin.y - height - 7
            radius: 5
            color: "#1a2a37"
            border.color: "#354c5e"
            Text {
                id: hint
                anchors.centerIn: parent
                width: hintBubble.width - 18
                wrapMode: Text.WordWrap
                text: action.description
                font.family: "Segoe UI"
                font.pixelSize: 10
                color: "#c5d2dc"
            }
        }
    }
    component DirectionGlobeButton: Rectangle {
        id: control
        property int direction: 1
        readonly property bool playing: sky.animationDirection === direction
        width: 62; height: 34; radius: 6
        color: "#121f2b"; border.color: playing ? "#59788d" : "#2a3d4c"
        TimeAction {
            id: stepAction
            x: control.direction < 0 ? 21 : 0
            width: 41; height: parent.height
            objectName: control.direction < 0 ? "stepBackwardButton" : "stepForwardButton"
            highlighted: control.playing
            holdEnabled: true
            description: (control.direction < 0 ? "Step backward " : "Step forward ") + sky.combinedLabel + (sky.earthMode ? "; rotate Earth" : "; rotate sky") + ". Hold or use the outer play section to animate."
            onTriggered: sky.navigate(control.direction, false)
            onHeld: sky.navigate(control.direction, true)
        }
        Canvas {
            z: 1
            x: stepAction.x + (stepAction.width - width) / 2
            y: 3; width: 32; height: 28
            onPaint: {
                const c = getContext("2d");c.clearRect(0,0,width,height);c.save()
                if (control.direction < 0) { c.translate(width,0);c.scale(-1,1) }
                c.lineWidth=1;c.lineCap="round";c.strokeStyle="#a4bfcd"
                c.beginPath();c.ellipse(7,4,18,20);c.stroke();c.beginPath();c.ellipse(12,4,8,20);c.stroke()
                c.strokeStyle="#698b9e";c.beginPath();c.moveTo(8,10);c.lineTo(24,10);c.moveTo(8,18);c.lineTo(24,18);c.stroke()
                c.strokeStyle="#c0d7e1";c.lineWidth=1.4;c.beginPath();c.moveTo(6,11);c.bezierCurveTo(-3,21,34,22,27,12);c.stroke()
                c.beginPath();c.moveTo(24,14);c.lineTo(27,11);c.lineTo(30,15);c.stroke();c.restore()
            }
        }
        TimeAction {
            x: control.direction < 0 ? 0 : 41
            width: 21; height: parent.height
            direction: control.direction; animate: true; playing: control.playing
            objectName: control.direction < 0 ? "playBackwardButton" : "playForwardButton"
            description: (playing ? "Pause" : control.direction < 0 ? "Animate backward" : "Animate forward") + " · " + sky.combinedLabel + (sky.combinedIndex >= 9 ? " twice per second" : " per second")
            onTriggered: sky.navigate(control.direction, true)
        }
        Rectangle { x: control.direction < 0 ? 21 : 41; y: 7; width: 1; height: parent.height - 14; color: "#2a3d4c" }
    }

    Item {
        id: intervalMenu
        property real popupX: 0
        onVisibleChanged: { if (visible) popupX = Math.max(8, Math.min(window.width - 168, intervalSelectorRect.mapToItem(window.contentItem, 0, 0).x)) }
        objectName: "intervalMenu"
        anchors.fill: parent
        z: 80
        visible: false
        MouseArea { anchors.fill: parent; onClicked: intervalMenu.visible = false; onWheel: wheel => { wheel.accepted = true } }
        Rectangle {
            x: intervalMenu.popupX
            y: Math.max(8, footer.y - height - 6)
            width: 160; height: intervalChoices.height + 8
            radius: 6; color: "#12212d"; border.color: "#3c5364"
            Column {
                id: intervalChoices
                x: 4; y: 4
                Repeater {
                    model: sky.combinedOptions
                    Rectangle {
                        required property int index
                        required property string modelData
                        objectName: "intervalChoice" + index
                        width: 152; height: 27; radius: 4
                        color: choiceHit.containsMouse ? "#2a4152" : sky.combinedIndex === index ? "#203747" : "transparent"
                        Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: (sky.combinedIndex === index ? "\u2713  " : "     ") + modelData; font.family: "Segoe UI"; font.pixelSize: 11; color: "#c1d2df" }
                        MouseArea { id: choiceHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { sky.selectCombinedInterval(index); intervalMenu.visible = false } }
                    }
                }
            }
        }
        Shortcut { sequence: "Escape"; enabled: intervalMenu.visible; onActivated: intervalMenu.visible = false }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        readonly property int sideMargin: 16
        readonly property int verticalPadding: 5
        readonly property bool singleRow: width >= timeControls.width + togglesRow.width + sideMargin * 2 + 24
        readonly property real controlsBottom: Math.max(timeControls.y + timeControls.height, togglesRow.y + togglesRow.height)
        readonly property real infoBottom: coordinatesLabel.visible ? coordinatesLabel.y + coordinatesLabel.implicitHeight : displayedTimeLabel.y + displayedTimeLabel.implicitHeight
        height: Math.ceil(attribution.y + attribution.implicitHeight + 7)
        color: "#0b131d"
        Rectangle { width: parent.width; height: 1; color: "#1b2936" }
        Text {
            id: titleText
            anchors.left: parent.left
            anchors.leftMargin: footer.sideMargin
            y: attribution.y
            text: "EARTH & SKY"
            font.family: "Segoe UI"
            font.pixelSize: 10
            font.letterSpacing: 2
            color: "#8197aa"
        }
        Text {
            x: togglesRow.x; y: togglesRow.y - 16
            text: "LAYERS"; font.family: "Segoe UI"; font.pixelSize: 9; font.letterSpacing: 1.2; color: "#758e9f"
        }
        Row {
            id: togglesRow
            anchors.right: parent.right
            anchors.rightMargin: footer.sideMargin
            y: footer.singleRow ? footer.verticalPadding + 32 : timeControls.y + timeControls.height + 20
            spacing: window.width < 850 ? 12 : 20
            VisibilityToggle { id: sunToggle; label: "Sun"; settingsKey: "sun" }
            VisibilityToggle { id: moonToggle; label: "Moon"; settingsKey: "moon" }
            VisibilityToggle { id: planetsToggle; label: "Planets"; settingsKey: "planets" }
            VisibilityToggle { id: constellationsToggle; objectName: "zodiacToggle"; label: "Zodiac"; settingsKey: "constellations" }
            VisibilityToggle { id: allConstellationsToggle; objectName: "allConstellationsToggle"; label: "All constellations"; settingsKey: "allConstellations" }
            VisibilityToggle { id: latitudeLinesToggle; objectName: "latitudeLinesToggle"; label: "Latitude lines"; settingsKey: "latitudeLines" }
            VisibilityToggle { id: labelsToggle; label: "Labels"; settingsKey: "labels" }
        }
        Row {
            id: timeControls
            anchors.left: parent.left
            anchors.leftMargin: footer.sideMargin
            y: footer.verticalPadding
            height: 65
            spacing: 18
            Item {
                width: 272; height: 65
                Row {
                    x: (parent.width - width) / 2; spacing: 4
                    Repeater {
                        model: ["Rotate Sky", "Rotate Earth"]
                        Rectangle {
                            required property int index
                            required property string modelData
                            width: 112; height: 24; radius: 5
                            color: sky.earthMode === (index === 1) ? "#203747" : "transparent"
                            border.color: sky.earthMode === (index === 1) ? "#496779" : "#263846"
                            TimeAction {
                                anchors.fill: parent
                                objectName: index === 0 ? "rotateSkyModeButton" : "rotateEarthModeButton"
                                label: modelData
                                Accessible.role: Accessible.RadioButton
                                Accessible.checkable: true
                                Accessible.checked: sky.earthMode === (index === 1)
                                highlighted: sky.earthMode === (index === 1)
                                description: index === 0 ? "Rotate the sky over a fixed Earth. Changing modes pauses playback." : "Rotate Earth beneath the sky. Changing modes pauses playback."
                                onTriggered: sky.setEarthMode(index === 1)
                            }
                        }
                    }
                }
                Row {
                    y: 31; spacing: 8
                    DirectionGlobeButton { direction: -1 }
                    Rectangle {
                        id: intervalSelectorRect
                        width: 132; height: 34; radius: 5
                        color: intervalHit.containsMouse ? "#20303f" : "#101c27"
                        Text { anchors.centerIn: parent; text: sky.combinedLabel + "  \u2304"; font.family: "Segoe UI"; font.pixelSize: 11; color: "#b4c8d5" }
                        MouseArea { id: intervalHit; objectName: "intervalSelector"; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: intervalMenu.visible = !intervalMenu.visible }
                        activeFocusOnTab: true
                        Accessible.role: Accessible.ComboBox
                        Accessible.name: "Rotation interval: " + sky.combinedLabel
                        Keys.onEscapePressed: event => { intervalMenu.visible = false; event.accepted = true }
                        Keys.onSpacePressed: intervalMenu.visible = !intervalMenu.visible
                        Keys.onReturnPressed: intervalMenu.visible = !intervalMenu.visible
                    }
                    DirectionGlobeButton { direction: 1 }
                }
            }
            Rectangle {
                y: 32; width: 66; height: 32; radius: 6
                color: "#121f2b"; border.color: "#2a3d4c"
                TimeAction {
                    objectName: "fullMapButton"
                    anchors.fill: parent
                    label: window.globeMode ? "Full globe" : "Full map"
                    description: "Fit the whole view and exit My Horizon; keep the displayed time"
                    enabled: window.globeMode || !mapViewport.fitted
                    opacity: enabled ? 1 : 0.45
                    onTriggered: { mapViewport.fitMap(); globe.fitView() }
                }
            }
            Rectangle {
                y: 32; width: 74; height: 32; radius: 6
                color: "#121f2b"; border.color: sky.live ? "#506d80" : "#2a3d4c"
                TimeAction {
                    objectName: "resetButton"
                    anchors.fill: parent
                    label: "\u21bb  Reset"
                    description: "Reset to the current time and full map, and stop playback"
                    highlighted: sky.live
                    onTriggered: { sky.goToNow(); mapViewport.fitMap(); globe.fitView(); intervalMenu.visible = false }
                }
            }
        }
        Text {
            id: displayedTimeLabel
            objectName: "displayedTimeLabel"
            anchors.horizontalCenter: parent.horizontalCenter
            y: footer.controlsBottom + 8
            text: sky.displayedTime
            font.family: "Segoe UI"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: "#d5e3ee"
        }
        Text {
            id: coordinatesLabel
            objectName: "coordinatesLabel"
            visible: mapViewport.horizonActive
            anchors.horizontalCenter: parent.horizontalCenter
            y: displayedTimeLabel.y + displayedTimeLabel.implicitHeight + 3
            text: "My Horizon  ·  Latitude " + Math.abs(mapViewport.observerLatitude).toFixed(2) + "° " + (mapViewport.observerLatitude >= 0 ? "N" : "S") + "  ·  Longitude " + Math.abs(mapViewport.observerLongitude * 360 - 180).toFixed(2) + "° " + (mapViewport.observerLongitude >= 0.5 ? "E" : "W")
            font.family: "Segoe UI"; font.pixelSize: 11; color: "#99bdce"
        }
        Text {
            id: attribution
            anchors.right: parent.right
            anchors.rightMargin: footer.sideMargin
            y: footer.infoBottom + 6
            text: "Map: NASA Blue Marble  ·  Moon: Gregory H. Revera"
            font.family: "Segoe UI"
            font.pixelSize: 10
            color: "#657e92"
        }
    }
}
