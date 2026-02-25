/*
    SPDX-FileCopyrightText: 2025 breuel
    SPDX-License-Identifier: GPL-3.0-or-later

    Standalone launcher – runs the widget as a normal window application
    without requiring the Plasma shell.
    Usage:  qml6 main.qml
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtCore
import org.kde.kirigami 2.20 as Kirigami

QQC2.ApplicationWindow {
    id: root

    title: tr("Plasma Quick Display Change")
    width: Kirigami.Units.gridUnit * 28
    height: Kirigami.Units.gridUnit * 38
    minimumWidth: Kirigami.Units.gridUnit * 24
    minimumHeight: Kirigami.Units.gridUnit * 28
    visible: true

    property var monitors: []
    property bool isRefreshing: false
    property var savedProfiles: []
    property bool expanded: true
    property bool inSystemTray: false

    // ── Translations ──

    Translations {
        id: trans
        currentLanguage: appSettings.language || "system"
    }

    property int translationVersion: trans.version
    property string configLanguage: appSettings.language || "system"

    function setLanguage(lang) {
        appSettings.language = lang;
        configLanguage = lang;
        trans.currentLanguage = lang;
    }

    property bool configShowBadge: appSettings.showBadge
    function setShowBadge(show) {
        appSettings.showBadge = show;
        configShowBadge = show;
    }

    property bool configConfirmDelete: appSettings.confirmDelete
    function setConfirmDelete(val) {
        appSettings.confirmDelete = val;
        configConfirmDelete = val;
    }

    function tr(text) { return trans.tr(text); }
    function trn(singular, plural, count) { return trans.trn(singular, plural, count); }
    function tra(text) {
        var result = tr(text);
        for (var i = 1; i < arguments.length; i++)
            result = result.replace("%" + i, String(arguments[i]));
        return result;
    }

    // ── Persistent settings (Qt.labs.settings) ──

    Settings {
        id: appSettings
        category: "PlasmaQuickDisplayChange"
        property string language: "system"
        property bool showBadge: true
        property bool confirmDelete: true
        property string savedProfiles: "[]"
    }

    // ── Lifecycle ──

    Component.onCompleted: {
        Qt.application.desktopFileName = "plasma-quick-display-change";
        refreshMonitors();
        loadSavedProfiles();
    }

    // ── Profile management ──

    function loadSavedProfiles() {
        try {
            const raw = appSettings.savedProfiles || "[]";
            savedProfiles = JSON.parse(raw);
        } catch (e) {
            savedProfiles = [];
        }
    }

    function saveSavedProfiles() {
        appSettings.savedProfiles = JSON.stringify(savedProfiles);
    }

    function buildKscreenDoctorCommand(jsonStr) {
        try {
            const data = JSON.parse(jsonStr);
            const outputs = data.outputs || [];
            const args = [];
            for (const o of outputs) {
                const name = o.name;
                if (!name) continue;
                if (o.enabled) {
                    args.push("output." + name + ".enable");
                    const pos = o.pos || o.position;
                    if (pos && typeof pos.x === "number" && typeof pos.y === "number")
                        args.push("output." + name + ".position." + pos.x + "," + pos.y);
                    const modeId = o.currentModeId || o.modeId || o.mode;
                    if (modeId)
                        args.push("output." + name + ".mode." + modeId);
                } else {
                    args.push("output." + name + ".disable");
                }
            }
            return args.length ? "kscreen-doctor " + args.join(" ") : "";
        } catch (e) {
            return "";
        }
    }

    function profileExists(profileName) {
        return savedProfiles.some(p => (p.name || "").trim() === (profileName || "").trim());
    }

    function saveCurrentAsProfile(profileName, overwrite) {
        const name = (profileName || "").trim();
        if (!name) return;
        if (_profileSaveInProgress) {
            _profileSaveQueue.push({ name: name, overwrite: !!overwrite });
            return;
        }
        _profileSaveInProgress = true;
        _pendingProfileName = name;
        _pendingOverwrite = !!overwrite;
        profileSaveProcess.run("kscreen-doctor -j");
    }
    property string _pendingProfileName: ""
    property bool _pendingOverwrite: false
    property bool _profileSaveInProgress: false
    property var _profileSaveQueue: []

    function applyProfile(profile) {
        const cmd = buildKscreenDoctorCommand(profile.config);
        if (cmd) {
            applyProcess.run(cmd);
        }
    }

    function removeProfile(index) {
        savedProfiles = savedProfiles.filter((_, i) => i !== index);
        saveSavedProfiles();
    }

    // ── Monitor control ──

    function refreshMonitors() {
        isRefreshing = true;
        monitorProcess.run("kscreen-doctor -o");
    }

    function applyMonitorSettings(commands) {
        if (commands.length > 0) {
            let cmdStr = "kscreen-doctor " + commands.join(" ");
            applyProcess.run(cmdStr);
        }
    }

    // ── Command runners ──

    CommandRunner {
        id: monitorProcess
        onFinished: function(exitCode, stdout, stderr) {
            parseMonitorOutput(stdout);
            isRefreshing = false;
        }
    }

    CommandRunner {
        id: applyProcess
        onFinished: function(exitCode, stdout, stderr) {
            Qt.callLater(refreshMonitors);
        }
    }

    CommandRunner {
        id: profileSaveProcess
        onFinished: function(exitCode, stdout, stderr) {
            _profileSaveInProgress = false;
            if (exitCode === 0 && stdout && _pendingProfileName) {
                const name = _pendingProfileName;
                const doOverwrite = _pendingOverwrite;
                _pendingProfileName = "";
                _pendingOverwrite = false;

                let anyMatch = false;
                if (doOverwrite) {
                    const next = [];
                    for (let i = 0; i < savedProfiles.length; i++) {
                        const p = savedProfiles[i];
                        if ((p.name || "").trim() === name) {
                            anyMatch = true;
                            next.push({ name: String(p.name || name), config: String(stdout) });
                        } else {
                            next.push(p);
                        }
                    }
                    if (anyMatch) {
                        savedProfiles = next;
                        saveSavedProfiles();
                    } else {
                        savedProfiles = savedProfiles.concat([{ name: name, config: String(stdout) }]);
                        saveSavedProfiles();
                    }
                } else {
                    savedProfiles = savedProfiles.concat([{ name: name, config: String(stdout) }]);
                    saveSavedProfiles();
                }
            }
            if (_profileSaveQueue.length > 0) {
                const nextReq = _profileSaveQueue.shift();
                Qt.callLater(function() {
                    saveCurrentAsProfile(nextReq.name, nextReq.overwrite);
                });
            }
        }
    }

    // ── Parser ──

    function parseMonitorOutput(output) {
        output = output.replace(/\x1b\[[0-9;]*m/g, '');
        let lines = output.split("\n");
        let newMonitors = [];
        let currentMonitor = null;

        for (let line of lines) {
            let outputMatch = line.match(/Output:\s+(\d+)\s+(\S+)/);
            if (outputMatch) {
                if (currentMonitor) newMonitors.push(currentMonitor);
                currentMonitor = {
                    id: outputMatch[1],
                    name: outputMatch[2],
                    enabled: false,
                    connected: false,
                    primary: false,
                    geometry: { x: 0, y: 0, width: 0, height: 0 },
                    modes: [],
                    currentMode: ""
                };
            }
            if (currentMonitor) {
                if (line.includes("enabled") && !line.includes("disabled")) currentMonitor.enabled = true;
                if (line.includes("connected") && !line.includes("disconnected")) currentMonitor.connected = true;
                if (line.includes("priority 1")) currentMonitor.primary = true;
                let geoMatch = line.match(/Geometry:\s+(\d+),(\d+)\s+(\d+)x(\d+)/);
                if (geoMatch) {
                    currentMonitor.geometry = {
                        x: parseInt(geoMatch[1]),
                        y: parseInt(geoMatch[2]),
                        width: parseInt(geoMatch[3]),
                        height: parseInt(geoMatch[4])
                    };
                }
                let modeMatch = line.match(/(\d+:\d+x\d+@[\d.]+)\*/);
                if (modeMatch) currentMonitor.currentMode = modeMatch[1];
                let modesMatch = line.match(/Modes:\s+(.+)/);
                if (modesMatch) {
                    let modesStr = modesMatch[1];
                    let modes = modesStr.match(/\d+:\d+x\d+@[\d.]+/g);
                    if (modes) currentMonitor.modes = modes;
                }
            }
        }
        if (currentMonitor) newMonitors.push(currentMonitor);
        monitors = newMonitors.filter(m => m.connected);
    }

    // ── UI ──

    FullRepresentation {
        anchors.fill: parent
    }
}
