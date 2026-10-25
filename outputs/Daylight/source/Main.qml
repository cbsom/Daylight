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

    // Reserve the footer first; let the map occupy all remaining space.
    Item {
        id: mapViewport
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        clip: true

        Item {
            id: map
            anchors.fill: parent
            clip: true

            Image {
                anchors.fill: parent
                source: "image://earth/day"
                sourceSize.width: 5400
                smooth: true
            }
            Image {
                anchors.fill: parent
                source: "image://earth/night/" + sky.revision
                cache: false
                smooth: true
            }
            Image {
                anchors.fill: parent
                visible: constellationsToggle.checked
                source: "image://earth/zodiac/" + (labelsToggle.checked ? "labels/" : "no-labels/") + sky.revision
                sourceSize.width: Math.max(1, Math.round(map.width))
                sourceSize.height: Math.max(1, Math.round(map.height))
                cache: false
                smooth: true
            }
            // Farther bodies are created first, so nearer bodies cover them.
            Repeater {
                model: sky.markers
                delegate: Item {
                    required property var modelData
                    readonly property var marker: modelData
                    visible: marker.name === "Sun" ? sunToggle.checked
                             : marker.name === "Moon" ? moonToggle.checked : planetsToggle.checked
                    anchors.fill: parent
                    Repeater {
                        model: [-1, 0, 1]
                        delegate: Item {
                            required property int modelData
                            x: (marker.x + modelData) * map.width
                            y: marker.y * map.height
                            Image {
                                anchors.centerIn: parent
                                width: marker.size; height: marker.size
                                source: "image://earth/" + marker.image
                                cache: marker.name !== "Moon"
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

    component TimeButton: Rectangle {
        id: button
        property string label
        property string description
        property int direction: 0
        property bool highlighted: false
        signal triggered()
        width: direction === 0 ? 64 : 40
        height: 32
        radius: 7
        color: mouse.pressed ? "#2b4051" : mouse.containsMouse ? "#20303f" : "#121f2b"
        border.width: 1
        border.color: activeFocus ? "#829bad" : highlighted ? "#506d80" : "#2a3d4c"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: description
        Accessible.onPressAction: triggered()
        Keys.onSpacePressed: event => { triggered(); event.accepted = true }
        Keys.onReturnPressed: event => { triggered(); event.accepted = true }
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            anchors.centerIn: parent
            visible: button.direction === 0
            text: button.label
            font.family: "Segoe UI"
            font.pixelSize: 11
            color: button.highlighted ? "#c0d3df" : "#99adbc"
        }
        Canvas {
            anchors.centerIn: parent
            width: 12; height: 12
            visible: button.direction !== 0
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = "#b1c4d2"
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(button.direction < 0 ? 8 : 4, 2)
                ctx.lineTo(button.direction < 0 ? 4 : 8, 6)
                ctx.lineTo(button.direction < 0 ? 8 : 4, 10)
                ctx.stroke()
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { button.forceActiveFocus(Qt.MouseFocusReason); button.triggered() }
            // Count the second press of a quick pair as another navigation click.
            onDoubleClicked: event => { event.accepted = false }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        readonly property int sideMargin: 16
        readonly property int verticalPadding: 5
        readonly property int minimumFooterHeight: 100
        readonly property real topRowBottom: Math.max(titleText.y + titleText.implicitHeight, togglesRow.y + togglesRow.height)
        readonly property real navGroupHeight: timeControls.height + 4 + displayedTimeLabel.implicitHeight
        readonly property real lowerBandTop: topRowBottom + 4
        readonly property real lowerBandHeight: Math.max(0, footer.height - footer.verticalPadding - lowerBandTop)
        readonly property real navGroupTop: lowerBandTop + Math.max(0, (lowerBandHeight - navGroupHeight) / 2)
        height: minimumFooterHeight
        color: "#0b131d"
        Rectangle { width: parent.width; height: 1; color: "#1b2936" }
        Text {
            id: titleText
            anchors.left: parent.left
            anchors.leftMargin: footer.sideMargin
            y: footer.verticalPadding + 2
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
            y: footer.verticalPadding
            spacing: window.width < 850 ? 12 : 20
            VisibilityToggle { id: sunToggle; label: "Sun"; settingsKey: "sun" }
            VisibilityToggle { id: moonToggle; label: "Moon"; settingsKey: "moon" }
            VisibilityToggle { id: planetsToggle; label: "Planets"; settingsKey: "planets" }
            VisibilityToggle { id: constellationsToggle; label: "Constellations"; settingsKey: "constellations" }
            VisibilityToggle { id: labelsToggle; label: "Labels"; settingsKey: "labels" }
        }
        Row {
            id: timeControls
            anchors.horizontalCenter: parent.horizontalCenter
            y: footer.navGroupTop
            spacing: 6
            TimeButton {
                objectName: "previousDayButton"
                direction: -1
                description: "Back exactly 24 hours"
                onTriggered: sky.stepDay(-1)
            }
            TimeButton {
                objectName: "nowButton"
                label: "Now"
                description: "Return to the current live sky"
                highlighted: sky.live
                onTriggered: sky.goToNow()
            }
            TimeButton {
                objectName: "nextDayButton"
                direction: 1
                description: "Forward exactly 24 hours"
                onTriggered: sky.stepDay(1)
            }
        }
        Text {
            id: displayedTimeLabel
            objectName: "displayedTimeLabel"
            anchors.horizontalCenter: parent.horizontalCenter
            y: timeControls.y + timeControls.height + 4
            text: sky.displayedTime
            font.family: "Segoe UI"
            font.pixelSize: 11
            color: "#a5b4bf"
        }
        Text {
            id: attribution
            anchors.right: parent.right
            anchors.rightMargin: footer.sideMargin
            y: displayedTimeLabel.y
            text: "Map: NASA Blue Marble  ·  Moon: Gregory H. Revera"
            font.family: "Segoe UI"
            font.pixelSize: 10
            color: "#657e92"
        }
    }
}
