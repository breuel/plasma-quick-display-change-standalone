/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later

    Command runner using QProcess for Plasma 6
*/

import QtQuick

Item {
    id: runner

    signal finished(int exitCode, string stdout, string stderr)

    property string _command: ""
    property var _process: null

    function run(command) {
        _command = command;

        // Use Qt.createQmlObject to create a process
        if (_process) {
            _process.destroy();
        }

        // For Plasma 6, we need to use a different approach
        // Using the executable data engine through a Loader
        execLoader.active = false;
        execLoader.active = true;
    }

    Loader {
        id: execLoader
        active: false
        sourceComponent: Component {
            Item {
                id: execItem

                property string cmd: runner._command
                property var dataSource: null

                Component.onCompleted: {
                    // Create data source dynamically
                    try {
                        dataSource = Qt.createQmlObject('
                            import org.kde.plasma.plasma5support as Plasma5Support
                            Plasma5Support.DataSource {
                                engine: "executable"
                                connectedSources: []
                            }
                        ', execItem, "DataSource");

                        if (dataSource) {
                            dataSource.onNewData.connect(function(source, data) {
                                var stdout = data["stdout"] || "";
                                var stderr = data["stderr"] || "";
                                var exitCode = data["exit code"] || 0;

                                runner.finished(exitCode, stdout, stderr);
                                dataSource.disconnectSource(source);
                                execLoader.active = false;
                            });

                            dataSource.connectSource(cmd);
                        }
                    } catch (e) {
                        console.log("DataSource creation failed, trying alternative: " + e);
                        // Fallback: try older import
                        tryAlternativeDataSource();
                    }
                }

                function tryAlternativeDataSource() {
                    try {
                        dataSource = Qt.createQmlObject('
                            import org.kde.plasma.core 2.0 as PlasmaCore
                            PlasmaCore.DataSource {
                                engine: "executable"
                                connectedSources: []
                            }
                        ', execItem, "DataSource2");

                        if (dataSource) {
                            dataSource.onNewData.connect(function(source, data) {
                                var stdout = data["stdout"] || "";
                                var stderr = data["stderr"] || "";
                                var exitCode = data["exit code"] || 0;

                                runner.finished(exitCode, stdout, stderr);
                                dataSource.disconnectSource(source);
                                execLoader.active = false;
                            });

                            dataSource.connectSource(cmd);
                        }
                    } catch (e2) {
                        console.log("Alternative DataSource also failed: " + e2);
                        runner.finished(-1, "", "Failed to create command runner");
                        execLoader.active = false;
                    }
                }

                Component.onDestruction: {
                    if (dataSource) {
                        dataSource.destroy();
                    }
                }
            }
        }
    }
}
