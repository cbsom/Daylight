import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 1280
    height: 720
    minimumWidth: 720
    minimumHeight: 420
    visible: true
    title: "Daylight"
    color: "#080f18"

    Item {
        id: map
        width: Math.min(parent.width - 32, (parent.height - 52) * 2)
        height: width / 2
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -6
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
        // Copies at either side keep markers whole across the date line.
        Repeater {
            model: [-1, 0, 1]
            delegate: Item {
                required property int modelData
                x: (sky.sunX + modelData) * map.width
                y: sky.sunY * map.height
                Image {
                    anchors.centerIn: parent
                    width: 24; height: 24
                    source: "image://earth/sun"
                    smooth: true
                }
            }
        }
        Repeater {
            model: [-1, 0, 1]
            delegate: Item {
                required property int modelData
                x: (sky.moonX + modelData) * map.width
                y: sky.moonY * map.height
                Image {
                    anchors.centerIn: parent
                    width: 25; height: 25
                    source: "image://earth/moon/" + sky.revision
                    cache: false
                    smooth: true
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#385364"
            border.width: 1
        }
    }
    Text {
        anchors.top: map.bottom
        anchors.topMargin: 10
        anchors.left: map.left
        text: "DAYLIGHT"
        font.family: "Segoe UI"
        font.pixelSize: 11
        font.letterSpacing: 2
        color: "#8197aa"
    }
    Text {
        anchors.top: map.bottom
        anchors.topMargin: 10
        anchors.right: map.right
        text: "Map: NASA Blue Marble  ·  Moon: Gregory H. Revera"
        font.family: "Segoe UI"
        font.pixelSize: 10
        color: "#657e92"
    }
}
