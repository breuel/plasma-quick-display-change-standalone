/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents

Rectangle {
    id: monitorDelegate

    property var monitor
    signal toggleEnabled(string monitorName, bool enabled)
    signal setPrimary(string monitorName)

    // Let implicitHeight determine size
    implicitHeight: contentRow.implicitHeight + Kirigami.Units.smallSpacing * 2
    radius: Kirigami.Units.smallSpacing
    color: monitor.enabled ? Kirigami.Theme.activeBackgroundColor : Kirigami.Theme.backgroundColor
    border.color: monitor.primary ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
    border.width: monitor.primary ? 2 : 1
    opacity: monitor.enabled ? 1.0 : 0.7

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: Qt.resolvedUrl("../icons/monitor-single.svg")
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            opacity: monitor.enabled ? 1.0 : 0.5
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            PlasmaComponents.Label {
                text: monitor.name
                font.bold: true
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: {
                    let res = monitor.geometry.width > 0
                        ? monitor.geometry.width + "x" + monitor.geometry.height
                        : root.tr("Disabled");
                    return res;
                }
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                opacity: 0.7
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: {
                    if (monitor.enabled && monitor.currentMode) {
                        let match = monitor.currentMode.match(/\d+:(\d+x\d+@[\d.]+)/);
                        if (match) {
                            return match[1];
                        }
                    }
                    if (monitor.enabled) {
                        return root.tra("Position: %1, %2", monitor.geometry.x, monitor.geometry.y);
                    }
                    return root.tr("Not active");
                }
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                opacity: 0.7
                Layout.fillWidth: true
            }
        }

        // Primary indicator
        PlasmaComponents.ToolButton {
            icon.name: monitor.primary ? "starred" : "non-starred"
            onClicked: {
                if (!monitor.primary) {
                    setPrimary(monitor.name);
                }
            }
            enabled: monitor.enabled && !monitor.primary
            opacity: monitor.enabled ? 1.0 : 0.3
            PlasmaComponents.ToolTip.text: monitor.primary ? root.tr("Primary display") : root.tr("Set as Primary")
            PlasmaComponents.ToolTip.visible: hovered
        }

        // Enable/Disable switch
        PlasmaComponents.Switch {
            checked: monitor.enabled
            onToggled: {
                toggleEnabled(monitor.name, checked);
            }
            PlasmaComponents.ToolTip.text: monitor.enabled ? root.tr("Disable display") : root.tr("Enable display")
            PlasmaComponents.ToolTip.visible: hovered
        }
    }
}
