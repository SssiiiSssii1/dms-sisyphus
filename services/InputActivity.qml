pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "."

// Global keyboard-activity listener for Sisyphus.
//
// PRIVACY CONTRACT:
//   - InputListenerService filters press/repeat events and replaces every
//     matching line with a constant marker before it reaches QML. The wrapper's
//     only output signal `activityPulse()` carries no payload.
//   - Nothing needs root. Membership in the `input` group is required only so
//     the *user session* may read evdev devices.
Item {
    id: root

    // --- configuration (bound by Main.qml) ----------------------------------
    property string selectedDevicePath: "all"   // "all" | "/dev/input/eventN"
    property bool demoMode: false
    property bool enabled: true                 // caller gates: lock screen etc.

    // --- status (consumed by Settings UI) -----------------------------------
    property bool inputToolMissing: false
    property bool notInInputGroup: false
    property double lastActivityAt: 0
    readonly property bool inputBroken: inputToolMissing || notInInputGroup
                                        || InputListenerService.isLockedOut(root.selectedDevicePath)
    readonly property string requiredTool: selectedDevicePath === "all" ? "libinput" : "evtest"
    readonly property bool shouldListen: enabled && !demoMode && !inputToolMissing
                                        && !notInInputGroup
                                        && !InputListenerService.isLockedOut(root.selectedDevicePath)

    // THE ONLY OUTPUT. No key identity ever leaves this component.
    signal activityPulse()
    property int listenerClientId: -1

    function reportActivity() {
        root.lastActivityAt = Date.now();
        root.activityPulse();
    }

    function syncListener(resetLockout) {
        if (resetLockout)
            InputListenerService.resetLockout(root.selectedDevicePath);

        if (!root.shouldListen) {
            if (root.listenerClientId >= 0) {
                InputListenerService.unregisterClient(root.listenerClientId);
                root.listenerClientId = -1;
            }
            return;
        }

        if (root.listenerClientId < 0)
            root.listenerClientId = InputListenerService.registerClient(root.selectedDevicePath);
        else
            InputListenerService.updateClient(root.listenerClientId, root.selectedDevicePath);
    }

    Component.onCompleted: {
        console.log("[Sisyphus] listener armed: enabled=" + root.enabled
                    + " demo=" + root.demoMode + " device=" + root.selectedDevicePath
                    + " tool=" + root.requiredTool);
        checkPermissionsAndTools();
        if (root.demoMode) {
            restartDemo();
        } else {
            syncListener(false);
        }
    }

    Component.onDestruction: {
        demoStop();
        if (root.listenerClientId >= 0)
            InputListenerService.unregisterClient(root.listenerClientId);
    }

    onSelectedDevicePathChanged: {
        checkPermissionsAndTools();
        syncListener(true);
    }

    onEnabledChanged: {
        if (!root.enabled) {
            demoStop();
        } else {
            if (root.demoMode)
                restartDemo();
        }
        syncListener(root.enabled);
    }

    onDemoModeChanged: {
        if (root.demoMode) {
            restartDemo();
        } else {
            demoStop();
        }
        syncListener(true);
    }

    Connections {
        target: InputListenerService

        function onActivityPulse(sourcePath) {
            if (sourcePath === root.selectedDevicePath && root.shouldListen)
                root.reportActivity();
        }

        function onListenerStateChanged(sourcePath) {
            if (sourcePath === root.selectedDevicePath)
                root.syncListener(false);
        }
    }

    function checkPermissionsAndTools() {
        toolCheck.running = true;
        groupCheck.running = true;
    }

    Process {
        id: toolCheck
        command: ["sh", "-c", "command -v \"$1\" >/dev/null 2>&1", "sh", root.requiredTool]
        running: false
        onExited: exitCode => {
            root.inputToolMissing = (exitCode !== 0);
            root.syncListener(!root.inputToolMissing && !root.notInInputGroup);
        }
    }

    Process {
        id: groupCheck
        command: ["sh", "-c", "id -nG | tr ' ' '\\n' | grep -qx input"]
        running: false
        onExited: exitCode => {
            root.notInInputGroup = (exitCode !== 0);
            root.syncListener(!root.inputToolMissing && !root.notInInputGroup);
        }
    }

    // ------------------------------------------------------------------ demo
    // Demo mode needs no permissions at all: a synthetic typing pattern.
    Timer {
        id: demoBurstTimer

        interval: 260
        repeat: true
        onTriggered: root.reportActivity()
    }

    Timer {
        id: demoBurstEndTimer

        interval: 1200
        onTriggered: {
            demoBurstTimer.stop();
            demoRestTimer.start();
        }
    }

    Timer {
        id: demoRestTimer

        interval: 1800
        onTriggered: root.restartDemo()
    }

    function restartDemo() {
        if (!root.enabled || !root.demoMode)
            return;
        demoBurstTimer.start();
        demoBurstEndTimer.start();
    }

    function demoStop() {
        demoBurstTimer.stop();
        demoBurstEndTimer.stop();
        demoRestTimer.stop();
    }
}
