/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents

Rectangle {
    id: layoutEditor

    property var monitors: []
    property var pendingPositions: ({})  // Store pending positions until Apply
    property bool hasChanges: false
    property string draggingMonitor: ""  // Name of monitor currently being dragged

    signal applyLayout()

    // Use a darker/distinct background so monitors don't blend in
    color: Qt.darker(Kirigami.Theme.backgroundColor, 1.15)
    border.color: Kirigami.Theme.disabledTextColor
    border.width: 1
    radius: Kirigami.Units.smallSpacing
    clip: true

    // Padding around the workspace - enough space to drag monitors above/below
    readonly property real workspacePadding: Kirigami.Units.gridUnit

    // Dynamic scale factor - calculate based on total monitor area and available space
    // Must allow for all monitors side-by-side OR stacked vertically
    readonly property real scaleFactor: {
        if (monitors.length === 0) return 0.04;

        // Calculate total width/height if all monitors are side-by-side or stacked
        let totalWidthSideBySide = 0;
        let totalHeightStacked = 0;
        let maxSingleWidth = 0;
        let maxSingleHeight = 0;
        let enabledCount = 0;

        for (let m of monitors) {
            if (m.enabled) {
                enabledCount++;
                let mw = m.geometry.width || 1920;
                let mh = m.geometry.height || 1080;

                totalWidthSideBySide += mw;
                totalHeightStacked += mh;
                if (mw > maxSingleWidth) maxSingleWidth = mw;
                if (mh > maxSingleHeight) maxSingleHeight = mh;
            }
        }

        if (enabledCount === 0) {
            return 0.04;
        }

        // Virtual workspace must fit:
        // - All monitors side-by-side (width = totalWidthSideBySide)
        // - Or all monitors stacked (height = totalHeightStacked)
        // Use the maximum of both scenarios
        let virtualWidth = totalWidthSideBySide;
        let virtualHeight = totalHeightStacked;

        let availableWidth = width - workspacePadding * 2;
        let availableHeight = height - workspacePadding * 2;

        let scaleX = availableWidth / virtualWidth;
        let scaleY = availableHeight / virtualHeight;

        let scale = Math.min(scaleX, scaleY);

        return scale;
    }

    // Flag to prevent recursive resets
    property bool isResetting: false

    // Reset pending positions when monitors change
    onMonitorsChanged: {
        if (!isResetting) {
            pendingPositions = {};
            hasChanges = false;
        }
    }

    // Public function to reset all pending changes
    function resetChanges() {
        pendingPositions = {};
        hasChanges = false;
        // Force Repeater to rebuild by temporarily clearing and restoring model
        isResetting = true;
        let savedMonitors = monitors;
        monitors = [];
        monitors = savedMonitors;
        isResetting = false;
    }

    // Get position for a monitor (pending or original)
    function getMonitorX(m) {
        if (pendingPositions[m.name] !== undefined) {
            return pendingPositions[m.name].x;
        }
        return m.geometry.x;
    }

    function getMonitorY(m) {
        if (pendingPositions[m.name] !== undefined) {
            return pendingPositions[m.name].y;
        }
        return m.geometry.y;
    }

    // Snap to other monitors - exact KDE kscreen logic
    // Source: https://invent.kde.org/plasma/kscreen/-/raw/master/kcm/output_model.cpp
    // Snap area scaled to real coordinates - 20px in preview = snapArea in real coords
    readonly property real snapArea: scaleFactor > 0 ? (20 / scaleFactor) : 500

    function isVerticalClose(target, rect) {
        if (target.y - (rect.y + rect.h) > snapArea) return false;
        if (rect.y - (target.y + target.h) > snapArea) return false;
        return true;
    }

    function snapToRight(target, size, dest) {
        // My left edge to target's right edge
        if (Math.abs(target.x + target.w - dest.x) < snapArea) {
            dest.x = target.x + target.w;
            return true;
        }
        // My right edge to target's right edge
        if (Math.abs(target.x + target.w - (dest.x + size.w)) < snapArea) {
            dest.x = target.x + target.w - size.w;
            return true;
        }
        return false;
    }

    function snapToLeft(target, size, dest) {
        // My left edge to target's left edge
        if (Math.abs(target.x - dest.x) < snapArea) {
            dest.x = target.x;
            return true;
        }
        // My right edge to target's left edge
        if (Math.abs(target.x - (dest.x + size.w)) < snapArea) {
            dest.x = target.x - size.w;
            return true;
        }
        return false;
    }

    function snapHorizontal(target, size, dest) {
        if (snapToRight(target, size, dest)) return true;
        if (snapToLeft(target, size, dest)) return true;
        return false;
    }

    function snapToBottom(target, size, dest) {
        // My top edge to target's bottom edge
        if (Math.abs(target.y + target.h - dest.y) < snapArea) {
            dest.y = target.y + target.h;
            return true;
        }
        // My bottom edge to target's bottom edge
        if (Math.abs(target.y + target.h - (dest.y + size.h)) < snapArea) {
            dest.y = target.y + target.h - size.h;
            return true;
        }
        return false;
    }

    function snapToTop(target, size, dest) {
        // My top edge to target's top edge
        if (Math.abs(target.y - dest.y) < snapArea) {
            dest.y = target.y;
            return true;
        }
        // My bottom edge to target's top edge
        if (Math.abs(target.y - (dest.y + size.h)) < snapArea) {
            dest.y = target.y - size.h;
            return true;
        }
        return false;
    }

    function snapVertical(target, size, dest) {
        if (snapToBottom(target, size, dest)) return true;
        if (snapToTop(target, size, dest)) return true;
        return false;
    }

    // Corner snap threshold (in real coordinates)
    readonly property real cornerSnapThreshold: 100
    // Edge switch threshold - how far to move before switching edges
    readonly property real edgeSwitchThreshold: 300

    function snapPositionSticky(monitorName, newX, newY, monitorWidth, monitorHeight, currentEdge) {
        let size = { w: monitorWidth, h: monitorHeight };

        // Get list of other enabled monitors
        let others = [];
        for (let m of monitors) {
            if (!m.enabled || m.name === monitorName) continue;
            let ox = pendingPositions[m.name] !== undefined ? pendingPositions[m.name].x : m.geometry.x;
            let oy = pendingPositions[m.name] !== undefined ? pendingPositions[m.name].y : m.geometry.y;
            others.push({
                x: ox,
                y: oy,
                w: m.geometry.width || 1920,
                h: m.geometry.height || 1080,
                name: m.name
            });
        }

        if (others.length === 0) {
            return { x: newX, y: newY, edge: null };
        }

        // If we have a current edge, try to stick to it
        if (currentEdge) {
            let t = others.find(o => o.name === currentEdge.targetName);
            if (t) {
                let distFromEdge;
                if (currentEdge.type === 'right') {
                    distFromEdge = Math.abs(newX - (t.x + t.w));
                } else if (currentEdge.type === 'left') {
                    distFromEdge = Math.abs((newX + size.w) - t.x);
                } else if (currentEdge.type === 'bottom') {
                    distFromEdge = Math.abs(newY - (t.y + t.h));
                } else if (currentEdge.type === 'top') {
                    distFromEdge = Math.abs((newY + size.h) - t.y);
                }

                // Stick to current edge if still close
                if (distFromEdge < edgeSwitchThreshold) {
                    let result = applyEdgeSnap(currentEdge.type, t, size, newX, newY);
                    return { x: result.x, y: result.y, edge: currentEdge };
                }
            }
        }

        // Find closest edge
        let bestEdge = null;
        let bestEdgeDist = Infinity;

        for (let t of others) {
            let rightEdgeDist = Math.abs(newX - (t.x + t.w));
            let leftEdgeDist = Math.abs((newX + size.w) - t.x);
            let bottomEdgeDist = Math.abs(newY - (t.y + t.h));
            let topEdgeDist = Math.abs((newY + size.h) - t.y);

            if (rightEdgeDist < bestEdgeDist) {
                bestEdgeDist = rightEdgeDist;
                bestEdge = { type: 'right', target: t, targetName: t.name };
            }
            if (leftEdgeDist < bestEdgeDist) {
                bestEdgeDist = leftEdgeDist;
                bestEdge = { type: 'left', target: t, targetName: t.name };
            }
            if (bottomEdgeDist < bestEdgeDist) {
                bestEdgeDist = bottomEdgeDist;
                bestEdge = { type: 'bottom', target: t, targetName: t.name };
            }
            if (topEdgeDist < bestEdgeDist) {
                bestEdgeDist = topEdgeDist;
                bestEdge = { type: 'top', target: t, targetName: t.name };
            }
        }

        if (!bestEdge) {
            return { x: newX, y: newY, edge: null };
        }

        let result = applyEdgeSnap(bestEdge.type, bestEdge.target, size, newX, newY);
        return { x: result.x, y: result.y, edge: bestEdge };
    }

    function applyEdgeSnap(edgeType, t, size, newX, newY) {
        let resultX = newX;
        let resultY = newY;

        if (edgeType === 'right') {
            resultX = t.x + t.w;
            resultY = newY;
            // Corner snap
            if (Math.abs(newY - t.y) < cornerSnapThreshold) resultY = t.y;
            else if (Math.abs(newY - (t.y + t.h - size.h)) < cornerSnapThreshold) resultY = t.y + t.h - size.h;
        } else if (edgeType === 'left') {
            resultX = t.x - size.w;
            resultY = newY;
            if (Math.abs(newY - t.y) < cornerSnapThreshold) resultY = t.y;
            else if (Math.abs(newY - (t.y + t.h - size.h)) < cornerSnapThreshold) resultY = t.y + t.h - size.h;
        } else if (edgeType === 'bottom') {
            resultY = t.y + t.h;
            resultX = newX;
            if (Math.abs(newX - t.x) < cornerSnapThreshold) resultX = t.x;
            else if (Math.abs(newX - (t.x + t.w - size.w)) < cornerSnapThreshold) resultX = t.x + t.w - size.w;
        } else if (edgeType === 'top') {
            resultY = t.y - size.h;
            resultX = newX;
            if (Math.abs(newX - t.x) < cornerSnapThreshold) resultX = t.x;
            else if (Math.abs(newX - (t.x + t.w - size.w)) < cornerSnapThreshold) resultX = t.x + t.w - size.w;
        }

        return { x: resultX, y: resultY };
    }

    function snapPosition(monitorName, newX, newY, monitorWidth, monitorHeight) {
        let size = { w: monitorWidth, h: monitorHeight };

        // Get list of other enabled monitors
        let others = [];
        for (let m of monitors) {
            if (!m.enabled || m.name === monitorName) continue;
            let ox = pendingPositions[m.name] !== undefined ? pendingPositions[m.name].x : m.geometry.x;
            let oy = pendingPositions[m.name] !== undefined ? pendingPositions[m.name].y : m.geometry.y;
            others.push({
                x: ox,
                y: oy,
                w: m.geometry.width || 1920,
                h: m.geometry.height || 1080
            });
        }

        if (others.length === 0) {
            return { x: newX, y: newY };
        }

        // Find which edge we're closest to
        let bestEdge = null;
        let bestEdgeDist = Infinity;

        for (let t of others) {
            // Distance to each edge
            let rightEdgeDist = Math.abs(newX - (t.x + t.w));  // my left to their right
            let leftEdgeDist = Math.abs((newX + size.w) - t.x); // my right to their left
            let bottomEdgeDist = Math.abs(newY - (t.y + t.h)); // my top to their bottom
            let topEdgeDist = Math.abs((newY + size.h) - t.y); // my bottom to their top

            if (rightEdgeDist < bestEdgeDist) {
                bestEdgeDist = rightEdgeDist;
                bestEdge = { type: 'right', target: t, attachX: t.x + t.w };
            }
            if (leftEdgeDist < bestEdgeDist) {
                bestEdgeDist = leftEdgeDist;
                bestEdge = { type: 'left', target: t, attachX: t.x - size.w };
            }
            if (bottomEdgeDist < bestEdgeDist) {
                bestEdgeDist = bottomEdgeDist;
                bestEdge = { type: 'bottom', target: t, attachY: t.y + t.h };
            }
            if (topEdgeDist < bestEdgeDist) {
                bestEdgeDist = topEdgeDist;
                bestEdge = { type: 'top', target: t, attachY: t.y - size.h };
            }
        }

        if (!bestEdge) {
            return { x: newX, y: newY };
        }

        let t = bestEdge.target;
        let resultX = newX;
        let resultY = newY;

        // Attach to the edge
        if (bestEdge.type === 'right' || bestEdge.type === 'left') {
            // Horizontal edge - X is fixed, Y slides freely
            resultX = bestEdge.attachX;
            resultY = newY;

            // Only snap Y to corners if very close (not aggressive)
            let ySnaps = [
                { y: t.y, dist: Math.abs(newY - t.y) },                              // tops aligned
                { y: t.y + t.h - size.h, dist: Math.abs(newY - (t.y + t.h - size.h)) } // bottoms aligned
            ];

            // Find closest snap point
            let bestSnap = null;
            let bestDist = cornerSnapThreshold;
            for (let s of ySnaps) {
                if (s.dist < bestDist) {
                    bestDist = s.dist;
                    bestSnap = s.y;
                }
            }
            if (bestSnap !== null) {
                resultY = bestSnap;
            }

        } else {
            // Vertical edge - Y is fixed, X slides freely
            resultY = bestEdge.attachY;
            resultX = newX;

            // Only snap X to corners if very close (not aggressive)
            let xSnaps = [
                { x: t.x, dist: Math.abs(newX - t.x) },                              // lefts aligned
                { x: t.x + t.w - size.w, dist: Math.abs(newX - (t.x + t.w - size.w)) } // rights aligned
            ];

            // Find closest snap point
            let bestSnap = null;
            let bestDist = cornerSnapThreshold;
            for (let s of xSnaps) {
                if (s.dist < bestDist) {
                    bestDist = s.dist;
                    bestSnap = s.x;
                }
            }
            if (bestSnap !== null) {
                resultX = bestSnap;
            }
        }

        return { x: resultX, y: resultY };
    }

    // Simple snap - attach to nearest edge of other monitors
    // This version finds the closest edge first, then snaps to it
    function snapPositionSimple(monitorName, newX, newY, monitorWidth, monitorHeight) {
        let size = { w: monitorWidth, h: monitorHeight };

        // Get list of other enabled monitors
        let others = [];
        for (let m of monitors) {
            if (!m.enabled || m.name === monitorName) continue;
            let ox = pendingPositions[m.name] !== undefined ? pendingPositions[m.name].x : m.geometry.x;
            let oy = pendingPositions[m.name] !== undefined ? pendingPositions[m.name].y : m.geometry.y;
            others.push({
                x: ox,
                y: oy,
                w: m.geometry.width || 1920,
                h: m.geometry.height || 1080,
                name: m.name
            });
        }

        if (others.length === 0) {
            return { x: newX, y: newY };
        }

        // Calculate center of dragged monitor
        let centerX = newX + size.w / 2;
        let centerY = newY + size.h / 2;

        // Find the closest edge from any other monitor
        let bestEdge = null;
        let bestEdgeDist = Infinity;

        for (let t of others) {
            // Calculate center of target monitor
            let tCenterX = t.x + t.w / 2;
            let tCenterY = t.y + t.h / 2;

            // Determine which edge we're closest to based on relative position
            // Check right edge of target (attach to right)
            let rightEdgeDist = Math.abs(newX - (t.x + t.w));
            // Check left edge of target (attach to left)
            let leftEdgeDist = Math.abs((newX + size.w) - t.x);
            // Check bottom edge of target (attach below)
            let bottomEdgeDist = Math.abs(newY - (t.y + t.h));
            // Check top edge of target (attach above)
            let topEdgeDist = Math.abs((newY + size.h) - t.y);

            // Only consider edges that make sense based on position
            // If we're to the right of target center, consider its right edge
            if (centerX > tCenterX && rightEdgeDist < bestEdgeDist) {
                bestEdgeDist = rightEdgeDist;
                bestEdge = { type: 'right', target: t };
            }
            // If we're to the left of target center, consider its left edge
            if (centerX < tCenterX && leftEdgeDist < bestEdgeDist) {
                bestEdgeDist = leftEdgeDist;
                bestEdge = { type: 'left', target: t };
            }
            // If we're below target center, consider its bottom edge
            if (centerY > tCenterY && bottomEdgeDist < bestEdgeDist) {
                bestEdgeDist = bottomEdgeDist;
                bestEdge = { type: 'bottom', target: t };
            }
            // If we're above target center, consider its top edge
            if (centerY < tCenterY && topEdgeDist < bestEdgeDist) {
                bestEdgeDist = topEdgeDist;
                bestEdge = { type: 'top', target: t };
            }
        }

        if (!bestEdge) {
            return { x: newX, y: newY };
        }

        let t = bestEdge.target;
        let resultX = newX;
        let resultY = newY;

        // Snap to the best edge
        if (bestEdge.type === 'right') {
            // Attach to right edge of target
            resultX = t.x + t.w;
            // Keep Y position, but snap to corners if close
            if (Math.abs(newY - t.y) < cornerSnapThreshold) {
                resultY = t.y;
            } else if (Math.abs((newY + size.h) - (t.y + t.h)) < cornerSnapThreshold) {
                resultY = t.y + t.h - size.h;
            }
        } else if (bestEdge.type === 'left') {
            // Attach to left edge of target
            resultX = t.x - size.w;
            if (Math.abs(newY - t.y) < cornerSnapThreshold) {
                resultY = t.y;
            } else if (Math.abs((newY + size.h) - (t.y + t.h)) < cornerSnapThreshold) {
                resultY = t.y + t.h - size.h;
            }
        } else if (bestEdge.type === 'bottom') {
            // Attach below target
            resultY = t.y + t.h;
            if (Math.abs(newX - t.x) < cornerSnapThreshold) {
                resultX = t.x;
            } else if (Math.abs((newX + size.w) - (t.x + t.w)) < cornerSnapThreshold) {
                resultX = t.x + t.w - size.w;
            }
        } else if (bestEdge.type === 'top') {
            // Attach above target
            resultY = t.y - size.h;
            if (Math.abs(newX - t.x) < cornerSnapThreshold) {
                resultX = t.x;
            } else if (Math.abs((newX + size.w) - (t.x + t.w)) < cornerSnapThreshold) {
                resultX = t.x + t.w - size.w;
            }
        }

        return { x: resultX, y: resultY };
    }

    // Get all pending positions for apply
    function getPendingPositions() {
        let positions = [];
        for (let m of monitors) {
            if (m.enabled) {
                positions.push({
                    name: m.name,
                    x: getMonitorX(m),
                    y: getMonitorY(m)
                });
            }
        }
        return positions;
    }

    // Grid background
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        anchors.margins: 1

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = Qt.rgba(Kirigami.Theme.disabledTextColor.r,
                                       Kirigami.Theme.disabledTextColor.g,
                                       Kirigami.Theme.disabledTextColor.b, 0.2);
            ctx.lineWidth = 1;

            let gridSize = 20;
            for (let x = 0; x < width; x += gridSize) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
                ctx.stroke();
            }
            for (let y = 0; y < height; y += gridSize) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }
        }
    }

    // Monitor representations - show all monitors but hide disabled ones
    // Note: This Repeater is inside a Loader that gets recreated when monitors change
    Repeater {
        id: monitorRepeater
        model: monitors

        delegate: Rectangle {
            id: monitorRect

            property var monitorData: modelData

            // Only show enabled monitors
            visible: monitorData.enabled
            property bool isDragging: false
            // Store drag position separately to avoid binding loops
            property real dragX: 0
            property real dragY: 0
            // Pending position for this monitor (after drag, before apply)
            property real pendingX: pendingPositions[monitorData.name] !== undefined ? pendingPositions[monitorData.name].x : -1
            property real pendingY: pendingPositions[monitorData.name] !== undefined ? pendingPositions[monitorData.name].y : -1
            // Effective display position - use pending if set, otherwise geometry
            property real displayX: pendingX >= 0 ? pendingX : monitorData.geometry.x
            property real displayY: pendingY >= 0 ? pendingY : monitorData.geometry.y

            // Z-order: dragging monitor on top, otherwise use index (later items on top)
            z: isDragging ? 1000 : index


            // Use binding for position - updates when scaleFactor or displayX/Y changes
            // During drag, use dragX/Y instead
            x: isDragging ? dragX : workspacePadding + displayX * scaleFactor
            y: isDragging ? dragY : workspacePadding + displayY * scaleFactor

            width: (monitorData.geometry.width || 1920) * scaleFactor
            height: (monitorData.geometry.height || 1080) * scaleFactor

            color: monitorData.primary ? Kirigami.Theme.highlightColor : Kirigami.Theme.activeBackgroundColor
            border.color: isDragging ? Kirigami.Theme.focusColor : (hasChanges && pendingPositions[monitorData.name] ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor)
            border.width: isDragging ? 2 : 1
            radius: 3
            opacity: isDragging ? 0.8 : 1.0

            // Monitor label
            Column {
                anchors.centerIn: parent
                spacing: 1

                PlasmaComponents.Label {
                    text: monitorData.name
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true
                    color: monitorData.primary ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                PlasmaComponents.Label {
                    text: (monitorData.geometry.width || 1920) + "x" + (monitorData.geometry.height || 1080)
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 0.8
                    color: monitorData.primary ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    opacity: 0.8
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Primary indicator
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 3
                width: 8
                height: 8
                radius: 4
                color: "gold"
                visible: monitorData.primary
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                // Only enable if no other monitor is being dragged, or this one is being dragged
                enabled: draggingMonitor === "" || draggingMonitor === monitorData.name

                property real startMouseX: 0
                property real startMouseY: 0
                property real startRectX: 0
                property real startRectY: 0

                onPressed: function(mouse) {
                    // Don't start drag if another monitor is already being dragged
                    if (draggingMonitor !== "" && draggingMonitor !== monitorData.name) {
                        mouse.accepted = false;
                        return;
                    }
                    startMouseX = mapToItem(layoutEditor, mouse.x, mouse.y).x;
                    startMouseY = mapToItem(layoutEditor, mouse.x, mouse.y).y;
                    startRectX = monitorRect.x;
                    startRectY = monitorRect.y;
                    dragX = startRectX;
                    dragY = startRectY;
                    isDragging = true;
                    draggingMonitor = monitorData.name;
                }

                onPositionChanged: function(mouse) {
                    if (!isDragging || draggingMonitor !== monitorData.name) return;
                    let currentPos = mapToItem(layoutEditor, mouse.x, mouse.y);
                    dragX = startRectX + (currentPos.x - startMouseX);
                    dragY = startRectY + (currentPos.y - startMouseY);
                }

                onReleased: {
                    // Only process if we were actually dragging this monitor
                    if (draggingMonitor !== monitorData.name) return;

                    // Calculate snapped position from current visual position
                    let rawX = (dragX - workspacePadding) / scaleFactor;
                    let rawY = (dragY - workspacePadding) / scaleFactor;
                    let mw = monitorData.geometry.width || 1920;
                    let mh = monitorData.geometry.height || 1080;

                    // Use simple snap - find nearest edge attachment
                    let result = snapPositionSimple(monitorData.name, rawX, rawY, mw, mh);

                    // Store snapped position
                    let snappedX = Math.max(0, result.x);
                    let snappedY = Math.max(0, result.y);

                    // Update pending positions - this triggers pendingX/Y bindings to update
                    // which in turn updates displayX/Y
                    let newPending = {};
                    for (let key in pendingPositions) {
                        newPending[key] = pendingPositions[key];
                    }
                    newPending[monitorData.name] = { x: snappedX, y: snappedY };
                    pendingPositions = newPending;
                    hasChanges = true;

                    // End drag - the binding will now use displayX/Y which reads from pendingPositions
                    isDragging = false;
                    draggingMonitor = "";
                }
            }

            // Tooltip
            PlasmaComponents.ToolTip {
                text: root.tra("Drag to reposition\n%1 at %2,%3",
                          monitorData.name,
                          Math.round(displayX),
                          Math.round(displayY))
            }
        }
    }

    // Empty state
    PlasmaComponents.Label {
        anchors.centerIn: parent
        text: root.tr("No enabled monitors")
        visible: monitors.filter(m => m.enabled).length === 0
        opacity: 0.5
    }
}
