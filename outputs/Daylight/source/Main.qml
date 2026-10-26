import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 1280
    height: 752
    minimumWidth: 720
    minimumHeight: 472
    visible: true
    title: "Daylight"
    color: "#080f18"
    onClosing: sky.stopAnimation()
    onVisibleChanged: { if (!visible) sky.stopAnimation() }
    Shortcut { sequence: "Escape"; onActivated: sky.stopAnimation() }

    // Camera coordinates are normalized and longitude wraps rather than clamping.
    Item {
        id: mapViewport
        objectName: "mapViewport"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        clip: true
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
        readonly property bool fitted: followKind === "none" && Math.abs(zoom - 1) < 0.001 && Math.abs(centerX - 0.5) < 0.001 && Math.abs(centerY - 0.5) < 0.001
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
        function fitMap() { releaseFollow(); zoom = 1; centerX = 0.5; centerY = 0.5 }
        function zoomAt(px, py, requested, recenter) {
            const next = Math.max(1, Math.min(8, requested))
            if (next === 1) { fitMap(); return }
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
        function selectAt(px, py) {
            const marker = bodyAt(px, py)
            if (marker) beginFollow("body", 0, 0, marker.name, Math.min(8, Math.max(2, zoom * 2)))
            else zoomAt(px, py, zoom * 2, true)
        }
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
                        visible: constellationsToggle.checked
                        source: visible ? "image://earth/zodiac/" + (labelsToggle.checked ? "labels/" : "no-labels/") + sky.revision : ""
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
            onDoubleClicked: mouse => { mouse.accepted = true; mapViewport.fitMap() }
            onWheel: wheel => {
                const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y / 120 : wheel.pixelDelta.y / 40
                if (delta !== 0) mapViewport.zoomAt(wheel.x, wheel.y, mapViewport.zoom * Math.pow(1.25, delta), false)
                wheel.accepted = true
            }
        }
        Rectangle {
            visible: mapViewport.followKind !== "none" && mapViewport.zoom > 1.001
            z: 10
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 10
            width: trackingCaption.implicitWidth + 18
            height: 26
            radius: 5
            color: "#dd101d29"
            border.color: "#344754"
            Text {
                id: trackingCaption
                anchors.centerIn: parent
                text: mapViewport.followKind === "body" ? "Following " + mapViewport.followBody : "Location locked"
                font.family: "Segoe UI"
                font.pixelSize: 10
                color: "#9bb5c4"
            }
        }
        Row {
            id: mapControls
            z: 10
            MouseArea { parent: mapControls.parent; x: mapControls.x; y: mapControls.y; width: mapControls.width; height: mapControls.height; z: 9; onWheel: wheel => { wheel.accepted = true } }
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 6
            Rectangle {
                visible: !mapViewport.fitted
                width: 62; height: 28; radius: 6
                color: "#dd101d29"
                border.color: "#344754"
                TimeAction {
                    objectName: "fitMapButton"
                    anchors.fill: parent
                    label: "Fit map"
                    description: "Fit the whole map (or double-click)"
                    onTriggered: mapViewport.fitMap()
                }
            }
        }
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
        width: animate ? 21 : direction === 0 ? 48 : 33
        height: 32
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: description
        Accessible.description: description + ". Escape stops animation."
        Accessible.onPressAction: triggered()
        Keys.onSpacePressed: event => { triggered(); event.accepted = true }
        Keys.onReturnPressed: event => { triggered(); event.accepted = true }
        Keys.onEscapePressed: event => { sky.stopAnimation(); event.accepted = true }
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
            onClicked: { action.forceActiveFocus(Qt.MouseFocusReason); action.triggered() }
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
    component SplitTimeButton: Rectangle {
        id: split
        property int direction
        property string unit
        property string stepDescription
        readonly property bool playing: sky.animationUnit === unit && sky.animationDirection === direction
        width: 54; height: 32
        radius: 6
        color: "#121f2b"
        border.color: playing ? "#59788d" : "#2a3d4c"
        Behavior on border.color { ColorAnimation { duration: 120 } }
        TimeAction {
            id: stepPart
            x: split.direction < 0 ? 21 : 0
            direction: split.direction
            objectName: (direction < 0 ? "previous" : "next") + (split.unit === "day" ? "Day" : (split.unit === "hour" || split.unit === "navigation") ? "Hour" : "Sidereal") + "Button"
            description: (direction < 0 ? "Back " : "Forward ") + split.stepDescription
            onTriggered: sky.stepTime(split.direction, split.unit)
        }
        TimeAction {
            x: split.direction < 0 ? 0 : 33
            direction: split.direction
            animate: true
            playing: split.playing
            objectName: "animate" + (direction < 0 ? "Backward" : "Forward") + (split.unit === "day" ? "Day" : (split.unit === "hour" || split.unit === "navigation") ? "Hour" : "Sidereal") + "Button"
            description: (playing ? "Pause" : direction < 0 ? "Animate backward" : "Animate forward") + " by " + split.stepDescription + " per second"
            onTriggered: sky.toggleAnimation(split.direction, split.unit)
        }
        Rectangle {
            x: split.direction < 0 ? 21 : 33
            y: 7; width: 1; height: parent.height - 14
            color: "#2a3d4c"
        }
    }
    component TimeStepGroup: Row {
        property string unit
        property string label
        property string stepDescription
        spacing: 6
        SplitTimeButton { direction: -1; unit: parent.unit; stepDescription: parent.stepDescription }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 114; height: 32; radius: 5
            color: intervalHit.containsMouse ? "#20303f" : "transparent"
            Text {
                anchors.centerIn: parent
                text: sky.navigationLabel + "  \u2304"
                font.family: "Segoe UI"; font.pixelSize: 11; color: "#a5b9c8"
            }
            MouseArea {
                id: intervalHit
                objectName: "intervalSelector"
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: intervalMenu.visible = !intervalMenu.visible
            }
            activeFocusOnTab: true
            Accessible.role: Accessible.ComboBox
            Accessible.name: "Time interval: " + sky.navigationLabel
            Keys.onSpacePressed: intervalMenu.visible = !intervalMenu.visible
            Keys.onReturnPressed: intervalMenu.visible = !intervalMenu.visible
        }
        SplitTimeButton { direction: 1; unit: parent.unit; stepDescription: parent.stepDescription }
    }

    Item {
        id: intervalMenu
        objectName: "intervalMenu"
        anchors.fill: parent
        z: 80
        visible: false
        MouseArea { anchors.fill: parent; onClicked: intervalMenu.visible = false; onWheel: wheel => { wheel.accepted = true } }
        Rectangle {
            x: footer.sideMargin + 60
            y: footer.y - height - 6
            width: 160; height: intervalChoices.height + 8
            radius: 6; color: "#12212d"; border.color: "#3c5364"
            Column {
                id: intervalChoices
                x: 4; y: 4
                Repeater {
                    model: ["5 Minutes", "15 Minutes", "30 Minutes", "1 Hour", "2 Hours", "6 Hours", "1 Sidereal Day", "24 Hours"]
                    Rectangle {
                        required property int index
                        required property string modelData
                        objectName: "intervalChoice" + index
                        width: 152; height: 30; radius: 4
                        color: choiceHit.containsMouse ? "#2a4152" : sky.navigationIndex === index ? "#203747" : "transparent"
                        Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: (sky.navigationIndex === index ? "\u2713  " : "     ") + modelData; font.family: "Segoe UI"; font.pixelSize: 11; color: "#c1d2df" }
                        MouseArea { id: choiceHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { sky.selectInterval(index); intervalMenu.visible = false } }
                    }
                }
            }
        }
        Shortcut { sequence: "Escape"; enabled: intervalMenu.visible; onActivated: intervalMenu.visible = false }
    }

    Item {
        id: rotationMenu
        property real popupX: 0
        onVisibleChanged: { if (visible) popupX = Math.max(8, Math.min(window.width - 168, rotationSelector.mapToItem(window.contentItem, 0, 0).x)) }
        objectName: "rotationMenu"
        anchors.fill: parent
        z: 80
        visible: false
        MouseArea { anchors.fill: parent; onClicked: rotationMenu.visible = false; onWheel: wheel => { wheel.accepted = true } }
        Rectangle {
            x: rotationMenu.popupX
            y: footer.y - height - 6
            width: 160; height: rotationChoices.height + 8
            radius: 6; color: "#12212d"; border.color: "#3c5364"
            Column {
                id: rotationChoices
                x: 4; y: 4
                Repeater {
                    model: ["1 min/s", "5 min/s", "15 min/s", "30 min/s", "1 h/s", "2 h/s", "4 h/s", "8 h/s"]
                    Rectangle {
                        required property int index
                        required property string modelData
                        objectName: "rotationChoice" + index
                        width: 152; height: 30; radius: 4
                        color: choiceHit.containsMouse ? "#2a4152" : sky.rotationIndex === index ? "#203747" : "transparent"
                        Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: (sky.rotationIndex === index ? "\u2713  " : "     ") + modelData; font.family: "Segoe UI"; font.pixelSize: 11; color: "#c1d2df" }
                        MouseArea { id: choiceHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { sky.selectRotationSpeed(index); rotationMenu.visible = false } }
                    }
                }
            }
        }
        Shortcut { sequence: "Escape"; enabled: rotationMenu.visible; onActivated: rotationMenu.visible = false }
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
        readonly property bool separateAttributionRow: attribution.x < displayedTimeLabel.x + displayedTimeLabel.implicitWidth + 16
        height: Math.ceil(Math.max(displayedTimeLabel.y + displayedTimeLabel.implicitHeight,
                                   attribution.y + attribution.implicitHeight) + verticalPadding)
        color: "#0b131d"
        Rectangle { width: parent.width; height: 1; color: "#1b2936" }
        Text {
            id: titleText
            anchors.left: parent.left
            anchors.leftMargin: footer.sideMargin
            y: displayedTimeLabel.y + 1
            text: "DAYLIGHT"
            font.family: "Segoe UI"
            font.pixelSize: 10
            font.letterSpacing: 2
            color: "#8197aa"
        }
        Row {
            id: togglesRow
            anchors.right: parent.right
            anchors.rightMargin: footer.sideMargin
            y: footer.singleRow ? footer.verticalPadding : timeControls.y + timeControls.height + 6
            spacing: window.width < 850 ? 12 : 20
            VisibilityToggle { id: sunToggle; label: "Sun"; settingsKey: "sun" }
            VisibilityToggle { id: moonToggle; label: "Moon"; settingsKey: "moon" }
            VisibilityToggle { id: planetsToggle; label: "Planets"; settingsKey: "planets" }
            VisibilityToggle { id: constellationsToggle; label: "Constellations"; settingsKey: "constellations" }
            VisibilityToggle { id: latitudeLinesToggle; objectName: "latitudeLinesToggle"; label: "Latitude lines"; settingsKey: "latitudeLines" }
            VisibilityToggle { id: labelsToggle; label: "Labels"; settingsKey: "labels" }
        }
        Row {
            id: timeControls
            anchors.left: parent.left
            anchors.leftMargin: footer.sideMargin
            y: footer.verticalPadding
            spacing: 30
            TimeStepGroup { unit: "navigation"; label: sky.navigationLabel; stepDescription: sky.navigationLabel }
            Row {
                spacing: 4
                Rectangle {
                    width: 36; height: 32; radius: 6
                    color: sky.rotating ? "#203b4b" : "#121f2b"
                    border.color: sky.rotating ? "#59788d" : "#2a3d4c"
                    Canvas {
                        anchors.centerIn: parent
                        width: 30; height: 28
                        onPaint: {
                            const c = getContext("2d")
                            c.clearRect(0, 0, width, height)
                            c.strokeStyle = "#a4bfcd"; c.lineWidth = 1; c.lineCap = "round"
                            c.beginPath(); c.ellipse(6, 4, 18, 20); c.stroke()
                            c.beginPath(); c.ellipse(11, 4, 8, 20); c.stroke()
                            c.strokeStyle = "#698b9e"
                            c.beginPath(); c.moveTo(7, 10); c.lineTo(23, 10); c.moveTo(7, 18); c.lineTo(23, 18); c.stroke()
                            c.strokeStyle = "#c0d7e1"; c.lineWidth = 1.4
                            c.beginPath(); c.moveTo(5, 11); c.bezierCurveTo(-4, 21, 33, 22, 26, 12); c.stroke()
                            c.beginPath(); c.moveTo(23, 14); c.lineTo(26, 11); c.lineTo(29, 15); c.stroke()
                        }
                    }
                    TimeAction {
                        objectName: "earthRotationButton"
                        anchors.fill: parent
                        description: sky.rotating ? "Pause Earth rotation" : "Rotate Earth at " + sky.rotationSpeedLabel
                        highlighted: sky.rotating
                        onTriggered: sky.toggleEarthRotation()
                    }
                }
                Rectangle {
                    id: rotationSelector
                    width: 78; height: 32; radius: 5
                    color: rotationHit.containsMouse ? "#20303f" : "transparent"
                    Text { objectName: "rotationSpeedLabel"; anchors.centerIn: parent; text: sky.rotationSpeedLabel + "  \u2304"; font.family: "Segoe UI"; font.pixelSize: 11; color: "#a5b9c8" }
                    MouseArea { id: rotationHit; objectName: "rotationSpeedSelector"; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rotationMenu.visible = !rotationMenu.visible }
                    activeFocusOnTab: true
                    Accessible.role: Accessible.ComboBox
                    Accessible.name: "Earth rotation speed: " + sky.rotationSpeedLabel
                    Keys.onSpacePressed: rotationMenu.visible = !rotationMenu.visible
                    Keys.onReturnPressed: rotationMenu.visible = !rotationMenu.visible
                }
            }

            Rectangle {
                width: 48; height: 32; radius: 6
                color: "#121f2b"
                border.color: sky.live ? "#506d80" : "#2a3d4c"
                TimeAction {
                    objectName: "nowButton"
                    label: "Now"
                    description: "Return to the current live sky"
                    highlighted: sky.live
                    onTriggered: sky.goToNow()
                }
            }
        }
        Text {
            id: displayedTimeLabel
            objectName: "displayedTimeLabel"
            anchors.horizontalCenter: parent.horizontalCenter
            y: footer.controlsBottom + 6
            text: sky.displayedTime
            font.family: "Segoe UI"
            font.pixelSize: 11
            color: "#a5b4bf"
        }
        Text {
            id: attribution
            anchors.right: parent.right
            anchors.rightMargin: footer.sideMargin
            y: footer.separateAttributionRow ? displayedTimeLabel.y + displayedTimeLabel.implicitHeight + 4 : displayedTimeLabel.y
            text: "Map: NASA Blue Marble  ·  Moon: Gregory H. Revera"
            font.family: "Segoe UI"
            font.pixelSize: 10
            color: "#657e92"
        }
    }
}
