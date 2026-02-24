/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Window
import org.kde.kirigami 2.20 as Kirigami

Window {
    id: identifyWindow

    property string monitorName: ""
    property string resolution: ""
    property int monitorX: 0
    property int monitorY: 0
    property int monitorWidth: 1920
    property int monitorHeight: 1080

    width: 300
    height: 150

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    visible: false

    Component.onCompleted: {
        // Find the screen that matches our monitor position
        let targetScreen = null;
        for (let i = 0; i < Qt.application.screens.length; i++) {
            let s = Qt.application.screens[i];
            if (s.virtualX === monitorX && s.virtualY === monitorY) {
                targetScreen = s;
                break;
            }
        }

        if (targetScreen) {
            identifyWindow.screen = targetScreen;
            // Position relative to screen
            identifyWindow.x = targetScreen.virtualX + Math.floor((targetScreen.width - width) / 2);
            identifyWindow.y = targetScreen.virtualY + Math.floor((targetScreen.height - height) / 2);
        } else {
            // Fallback to provided coordinates
            identifyWindow.x = monitorX + Math.floor((monitorWidth - width) / 2);
            identifyWindow.y = monitorY + Math.floor((monitorHeight - height) / 2);
        }

        identifyWindow.visible = true;
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: 10
        color: Kirigami.Theme.backgroundColor
        opacity: 0.9
        border.color: Kirigami.Theme.highlightColor
        border.width: 3
    }

    Column {
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            width: parent.width
            text: monitorName
            font.pixelSize: 32
            font.bold: true
            color: Kirigami.Theme.textColor
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: resolution
            font.pixelSize: 18
            color: Kirigami.Theme.textColor
            opacity: 0.8
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Auto close after 3 seconds
    Timer {
        interval: 3000
        running: true
        onTriggered: identifyWindow.close()
    }
}
