/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-FileCopyrightText: 2025 breuel (Plasma Quick Display Change – standalone variant)
    SPDX-License-Identifier: GPL-3.0-or-later

    Main UI panel.  Uses standard Kirigami / QtQuick.Controls types
    so it can run outside the Plasma shell (via qml6).
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: fullRoot

    property var layoutEditor: layoutEditorLoader.item
    property string overwriteProfileName: ""
    property string pendingSaveProfileName: ""
    property int pendingDeleteIndex: -1
    property string pendingDeleteName: ""

    function openOverwritePrompt(profileName) {
        overwriteProfileName = (profileName || "").trim();
        overwriteDialogLoader.active = true;
    }

    function closeOverwritePrompt() {
        overwriteDialogLoader.active = false;
    }

    function closeSaveProfileDialog() {
        saveProfileDialogLoader.active = false;
    }

    function openSaveProfileDialog(initialName) {
        pendingSaveProfileName = (initialName || "").trim();
        saveProfileDialogLoader.active = true;
    }

    function openDeleteConfirm(index, profileName) {
        pendingDeleteIndex = index;
        pendingDeleteName = profileName || "";
        deleteConfirmDialogLoader.active = true;
    }

    function closeDeleteConfirm() {
        deleteConfirmDialogLoader.active = false;
        pendingDeleteIndex = -1;
        pendingDeleteName = "";
    }

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                level: 3
                text: root.tr("Plasma Quick Display Change")
                Layout.fillWidth: true
            }

            QQC2.ToolButton {
                icon.name: "view-refresh"
                onClicked: root.refreshMonitors()
                QQC2.ToolTip.text: root.tr("Refresh monitors")
                QQC2.ToolTip.visible: hovered
            }

            QQC2.ToolButton {
                icon.name: "globe"
                onClicked: openSettings()
                QQC2.ToolTip.text: root.tr("Widget Settings")
                QQC2.ToolTip.visible: hovered
            }

            QQC2.ToolButton {
                icon.name: "configure"
                onClicked: settingsProcess.run("systemsettings kcm_kscreen")
                QQC2.ToolTip.text: root.tr("Open Display Settings")
                QQC2.ToolTip.visible: hovered
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ── Saved Profiles ──
        Kirigami.Heading {
            level: 5
            text: root.tr("Saved Profiles")
        }

        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.savedProfiles
                delegate: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Label {
                        text: modelData.name || ("Profile " + (index + 1))
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Button {
                        icon.name: "dialog-ok-apply"
                        text: root.tr("Apply")
                        onClicked: root.applyProfile(modelData)
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: "edit-delete"
                        onClicked: {
                            if (root.configConfirmDelete) {
                                fullRoot.openDeleteConfirm(index, modelData.name || "");
                            } else {
                                root.removeProfile(index);
                            }
                        }
                        PlasmaComponents.ToolTip.text: root.tr("Delete profile")
                        PlasmaComponents.ToolTip.visible: hovered
                    }
                }
            }
        }

        PlasmaComponents.Button {
            icon.name: "document-save-as"
            text: root.tr("Save current as profile")
            onClicked: fullRoot.openSaveProfileDialog("")
        }

        Loader {
            id: saveProfileDialogLoader
            active: false
            sourceComponent: QQC2.Popup {
                id: saveProfilePopup
                parent: fullRoot
                readonly property int _margin: Kirigami.Units.largeSpacing
                width: Math.min(Kirigami.Units.gridUnit * 18, parent.width - _margin * 2)
                height: Math.min(Kirigami.Units.gridUnit * 11, parent.height - _margin * 2)
                x: Math.max(_margin, Math.min((parent.width - width) / 2, parent.width - width - _margin))
                y: Math.max(_margin, Math.min((parent.height - height) / 2, parent.height - height - _margin))
                modal: true
                focus: true
                visible: true
                closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

                onClosed: {
                    profileNameField.text = "";
                    saveProfilePopup.parent.closeSaveProfileDialog();
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: root.tr("Profile name")
                    }
                    QQC2.TextField {
                        id: profileNameField
                        Layout.fillWidth: true
                        placeholderText: root.tr("e.g. Home, Office")
                        onAccepted: acceptSave()
                    }
                    PlasmaComponents.Label {
                        text: root.tr("A profile with this name already exists. Click Save to overwrite it.")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.maximumHeight: Kirigami.Units.gridUnit * 2.5
                        visible: profileNameField.text.trim() !== "" && root.profileExists(profileNameField.text.trim())
                        opacity: visible ? 1 : 0
                        color: Kirigami.Theme.negativeTextColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Button {
                            text: root.tr("Cancel")
                            onClicked: saveProfilePopup.close()
                        }
                        PlasmaComponents.Button {
                            text: root.tr("Save")
                            icon.name: "document-save"
                            onClicked: acceptSave()
                        }
                    }
                }

                function acceptSave() {
                    const name = profileNameField.text.trim();
                    if (!name) return;
                    if (root.profileExists(name)) {
                        saveProfilePopup.parent.pendingSaveProfileName = name;
                        saveProfilePopup.close();
                        Qt.callLater(function() {
                            fullRoot.openOverwritePrompt(name);
                        });
                        return;
                    }
                    root.saveCurrentAsProfile(name);
                    saveProfilePopup.close();
                }
                Component.onCompleted: {
                    profileNameField.text = fullRoot.pendingSaveProfileName || "";
                    profileNameField.forceActiveFocus();
                    profileNameField.selectAll();
                }
            }
        }

        Loader {
            id: overwriteDialogLoader
            active: false
            sourceComponent: QQC2.Popup {
                id: overwritePopup
                parent: fullRoot
                readonly property int _margin: Kirigami.Units.largeSpacing
                width: Math.min(Kirigami.Units.gridUnit * 22, parent.width - _margin * 2)
                height: Math.min(Kirigami.Units.gridUnit * 8, parent.height - _margin * 2)
                x: Math.max(_margin, Math.min((parent.width - width) / 2, parent.width - width - _margin))
                y: Math.max(_margin, Math.min((parent.height - height) / 2, parent.height - height - _margin))
                modal: true
                focus: true
                visible: true
                closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

                onClosed: {
                    overwritePopup.parent.closeOverwritePrompt();
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    PlasmaComponents.Label {
                        text: root.tr("A profile named \"%1\" already exists. Overwrite?").arg(overwritePopup.parent ? overwritePopup.parent.overwriteProfileName || "" : "")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Button {
                            text: root.tr("Cancel")
                            onClicked: {
                                const name = overwritePopup.parent.overwriteProfileName;
                                overwritePopup.close();
                                Qt.callLater(function() {
                                    fullRoot.openSaveProfileDialog(name);
                                });
                            }
                        }
                        PlasmaComponents.Button {
                            text: root.tr("Overwrite")
                            icon.name: "document-save"
                            onClicked: {
                                var rep = overwritePopup.parent;
                                root.saveCurrentAsProfile(rep.overwriteProfileName, true);
                                overwritePopup.close();
                            }
                        }
                    }
                }
            }
        }

        Loader {
            id: deleteConfirmDialogLoader
            active: false
            sourceComponent: QQC2.Popup {
                id: deletePopup
                parent: fullRoot
                readonly property int _margin: Kirigami.Units.largeSpacing
                width: Math.min(Kirigami.Units.gridUnit * 22, parent.width - _margin * 2)
                height: Math.min(Kirigami.Units.gridUnit * 8, parent.height - _margin * 2)
                x: Math.max(_margin, Math.min((parent.width - width) / 2, parent.width - width - _margin))
                y: Math.max(_margin, Math.min((parent.height - height) / 2, parent.height - height - _margin))
                modal: true
                focus: true
                visible: true
                closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

                onClosed: deletePopup.parent.closeDeleteConfirm()

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    PlasmaComponents.Label {
                        text: root.tr("Delete profile \"%1\"?").arg(fullRoot.pendingDeleteName || "")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Button {
                            text: root.tr("Cancel")
                            onClicked: deletePopup.close()
                        }
                        PlasmaComponents.Button {
                            text: root.tr("Delete")
                            icon.name: "edit-delete"
                            onClicked: {
                                if (fullRoot.pendingDeleteIndex >= 0) {
                                    root.removeProfile(fullRoot.pendingDeleteIndex);
                                }
                                deletePopup.close();
                            }
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // ── Quick Layout Presets ──
        Kirigami.Heading {
            level: 5
            text: root.tr("Quick Layouts")
        }

        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Button {
                icon.name: "view-split-left-right"
                text: root.tr("Side by Side")
                onClicked: applyPresetLayout("sidebyside")
                enabled: root.monitors.filter(m => m.connected).length >= 2
            }

            PlasmaComponents.Button {
                icon.name: "view-right-new"
                text: root.tr("Extend Right")
                onClicked: applyPresetLayout("extendright")
                enabled: root.monitors.filter(m => m.connected).length >= 2
            }

            PlasmaComponents.Button {
                icon.name: "view-left-new"
                text: root.tr("Extend Left")
                onClicked: applyPresetLayout("extendleft")
                enabled: root.monitors.filter(m => m.connected).length >= 2
            }

            PlasmaComponents.Button {
                icon.name: "view-split-top-bottom"
                text: root.tr("Stacked")
                onClicked: applyPresetLayout("stacked")
                enabled: root.monitors.filter(m => m.connected).length >= 2
            }

            PlasmaComponents.Button {
                icon.name: "video-display-symbolic"
                text: root.tr("Mirror")
                onClicked: applyPresetLayout("mirror")
                enabled: root.monitors.filter(m => m.connected).length >= 2
            }

            PlasmaComponents.Button {
                icon.name: "computer-laptop"
                text: root.tr("Primary Only")
                onClicked: applyPresetLayout("primaryonly")
            }

            PlasmaComponents.Button {
                icon.name: "documentinfo"
                text: root.tr("Identify")
                onClicked: identifyMonitors()
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            level: 5
            text: root.tr("Monitors") + " (" + root.monitors.length + ")"
        }

        Repeater {
            model: root.monitors
            delegate: MonitorDelegate {
                Layout.fillWidth: true
                monitor: modelData
                onToggleEnabled: function(monitorName, enabled) {
                    let cmd = enabled ? "enable" : "disable";
                    root.applyMonitorSettings(["output." + monitorName + "." + cmd]);
                }
                onSetPrimary: function(monitorName) {
                    root.applyMonitorSettings(["output." + monitorName + ".priority.1"]);
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true

            Kirigami.Heading {
                level: 5
                text: root.tr("Layout Preview")
            }

            PlasmaComponents.Label {
                text: "↕ " + root.tr("Expand for better view")
                opacity: 0.6
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                visible: layoutEditorLoader.height < Kirigami.Units.gridUnit * 8
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.Button {
                icon.name: "dialog-ok-apply"
                text: root.tr("Apply")
                enabled: layoutEditor && layoutEditor.hasChanges
                onClicked: {
                    if (layoutEditor) {
                        applyLayoutPositions(layoutEditor.getPendingPositions());
                        layoutEditor.hasChanges = false;
                        layoutEditor.pendingPositions = {};
                    }
                }
            }
        }

        Loader {
            id: layoutEditorLoader
            Layout.fillWidth: true
            Layout.fillHeight: true

            sourceComponent: LayoutEditor {
                anchors.fill: parent
                monitors: root.monitors
            }

            property var monitorsRef: root.monitors
            onMonitorsRefChanged: {
                active = false;
                active = true;
            }
        }
    }

    // ── Preset logic ──

    function applyPresetLayout(preset) {
        let connectedMonitors = root.monitors.filter(m => m.connected);
        if (connectedMonitors.length < 1) return;

        let commands = [];

        switch (preset) {
            case "sidebyside":
            case "extendright": {
                let xPos = 0;
                for (let i = 0; i < connectedMonitors.length; i++) {
                    let m = connectedMonitors[i];
                    commands.push("output." + m.name + ".enable");
                    commands.push("output." + m.name + ".position." + xPos + ",0");
                    xPos += m.geometry.width > 0 ? m.geometry.width : 1920;
                }
                break;
            }
            case "extendleft": {
                let monitors = connectedMonitors.slice().reverse();
                let xPos = 0;
                for (let i = 0; i < monitors.length; i++) {
                    let m = monitors[i];
                    commands.push("output." + m.name + ".enable");
                    commands.push("output." + m.name + ".position." + xPos + ",0");
                    xPos += m.geometry.width > 0 ? m.geometry.width : 1920;
                }
                break;
            }
            case "stacked": {
                let yPos = 0;
                for (let i = 0; i < connectedMonitors.length; i++) {
                    let m = connectedMonitors[i];
                    commands.push("output." + m.name + ".enable");
                    commands.push("output." + m.name + ".position.0," + yPos);
                    yPos += m.geometry.height > 0 ? m.geometry.height : 1080;
                }
                break;
            }
            case "mirror": {
                for (let m of connectedMonitors) {
                    commands.push("output." + m.name + ".enable");
                    commands.push("output." + m.name + ".position.0,0");
                }
                break;
            }
            case "primaryonly": {
                let primary = connectedMonitors.find(m => m.primary) || connectedMonitors[0];
                for (let m of connectedMonitors) {
                    if (m.name === primary.name) {
                        commands.push("output." + m.name + ".enable");
                        commands.push("output." + m.name + ".position.0,0");
                    } else {
                        commands.push("output." + m.name + ".disable");
                    }
                }
                break;
            }
        }

        if (commands.length > 0) {
            root.applyMonitorSettings(commands);
        }
    }

    function applyLayoutPositions(positions) {
        let commands = [];
        for (let pos of positions) {
            let cmd = "output." + pos.name + ".position." + Math.round(pos.x) + "," + Math.round(pos.y);
            commands.push(cmd);
        }
        if (commands.length > 0) {
            root.applyMonitorSettings(commands);
        }
    }

    property var identifyWindows: []

    function identifyMonitors() {
        for (let w of identifyWindows) {
            if (w) w.destroy();
        }
        identifyWindows = [];

        let enabledMonitors = root.monitors.filter(m => m.enabled);

        for (let m of enabledMonitors) {
            let component = Qt.createComponent("IdentifyWindow.qml");
            if (component.status === Component.Ready) {
                let window = component.createObject(fullRoot, {
                    monitorName: m.name,
                    resolution: m.geometry.width + "x" + m.geometry.height,
                    monitorX: m.geometry.x,
                    monitorY: m.geometry.y,
                    monitorWidth: m.geometry.width || 1920,
                    monitorHeight: m.geometry.height || 1080
                });
                identifyWindows.push(window);
            } else {
                console.log("Error creating IdentifyWindow:", component.errorString());
            }
        }
    }

    CommandRunner {
        id: settingsProcess
    }

    Loader {
        id: configDialogLoader
        active: false

        sourceComponent: QQC2.Popup {
            id: configDialog
            parent: fullRoot
            anchors.centerIn: parent
            width: Kirigami.Units.gridUnit * 20
            height: Kirigami.Units.gridUnit * 12
            modal: true
            focus: true
            visible: true

            onClosed: configDialogLoader.active = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Heading {
                    level: 3
                    text: root.tr("Widget Settings")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: root.tr("Language:")
                    }

                    PlasmaComponents.ComboBox {
                        id: languageCombo
                        Layout.fillWidth: true
                        model: [
                            root.tr("System default"), "English", "Magyar", "Deutsch",
                            "Français", "Español", "Italiano", "Português (Brasil)",
                            "Русский", "Polski", "Nederlands", "Türkçe",
                            "日本語", "한국어", "简体中文", "繁體中文"
                        ]
                        property var languageValues: [
                            "system", "en_US", "hu_HU", "de_DE", "fr_FR", "es_ES",
                            "it_IT", "pt_BR", "ru_RU", "pl_PL", "nl_NL", "tr_TR",
                            "ja_JP", "ko_KR", "zh_CN", "zh_TW"
                        ]
                        currentIndex: languageValues.indexOf(root.configLanguage)
                        onActivated: function(index) {
                            let newLang = languageValues[index];
                            if (root.configLanguage !== newLang) {
                                root.setLanguage(newLang);
                                configDialog.close();
                            }
                        }
                    }
                }

                PlasmaComponents.Label {
                    text: root.tr("Language changes apply immediately.")
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                    Layout.fillWidth: true
                }

                PlasmaComponents.CheckBox {
                    id: showBadgeCheckbox
                    text: root.tr("Show monitor count badge")
                    checked: root.configShowBadge
                    onToggled: root.setShowBadge(checked)
                }

                PlasmaComponents.CheckBox {
                    id: confirmDeleteCheckbox
                    text: root.tr("Confirm before deleting profiles")
                    checked: root.configConfirmDelete
                    onToggled: root.setConfirmDelete(checked)
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: "v1.0.0"
                        opacity: 0.5
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Button {
                        text: root.tr("Close")
                        onClicked: configDialog.close()
                    }
                }
            }
        }
    }

    function openSettings() {
        configDialogLoader.active = true;
    }
}
