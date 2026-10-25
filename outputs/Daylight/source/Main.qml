import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 1280
    height: width / 2 + 64
    minimumWidth: 720
    minimumHeight: 424
    visible: true
    title: "Daylight"
    color: "#080f18"

    Item {
        id: map
        width: parent.width
        height: width / 2        
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

    Rectangle {
        id: footer
        anchors.top: map.bottom
        width: parent.width
        height: 64
        color: "#0b131d"
        Rectangle { width: parent.width; height: 1; color: "#1b2936" }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            y: 14
            text: "DAYLIGHT"
            font.family: "Segoe UI"
            font.pixelSize: 10
            font.letterSpacing: 2
            color: "#8197aa"
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 4
            spacing: window.width < 850 ? 12 : 20
            VisibilityToggle { id: sunToggle; label: "Sun"; settingsKey: "sun" }
            VisibilityToggle { id: moonToggle; label: "Moon"; settingsKey: "moon" }
            VisibilityToggle { id: planetsToggle; label: "Planets"; settingsKey: "planets" }
            VisibilityToggle { id: constellationsToggle; label: "Constellations"; settingsKey: "constellations" }
            VisibilityToggle { id: labelsToggle; label: "Labels"; settingsKey: "labels" }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 43
            text: "Map: NASA Blue Marble  ·  Moon: Gregory H. Revera"
            font.family: "Segoe UI"
            font.pixelSize: 10
            color: "#657e92"
        }
    }
}
