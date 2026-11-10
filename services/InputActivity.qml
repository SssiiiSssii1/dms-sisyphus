pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Global keyboard-activity listener for Sisyphus.
//
// PRIVACY CONTRACT:
//   - The child process (libinput/evtest) prints evdev event lines that contain
//     key names. Sisyphus matches the presence of key events only; names and
//     codes are immediately discarded. They are never stored, logged, shown,
//     or transmitted: the single output signal `activityPulse()` has no payload.
//   - Nothing needs root. Membership in the `input` group is required only so
//     the *user session* may read evdev devices.
// Parsing and process handling mirror the proven pattern used by the Bongo Cat
// plugin (libinput debug-events in Auto mode, evtest for a specific device).
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
    readonly property bool inputBroken: inputToolMissing || notInInputGroup || failLockout
    readonly property string requiredTool: selectedDevicePath === "all" ? "libinput" : "evtest"
    readonly property bool shouldListen: enabled && !demoMode && !inputToolMissing
                                        && !notInInputGroup && !failLockout

    // THE ONLY OUTPUT. No key identity ever leaves this component.
    signal activityPulse()

    function reportActivity() {
        root.lastActivityAt = Date.now();
        root.activityPulse();
    }

    Component.onCompleted: {
        console.log("[Sisyphus] listener armed: enabled=" + root.enabled
                    + " demo=" + root.demoMode + " device=" + root.selectedDevicePath
                    + " tool=" + root.requiredTool);
        checkPermissionsAndTools();
        if (root.demoMode)
            restartDemo();
        else
            inputRestartTimer.start();
    }

    onSelectedDevicePathChanged: {
        if (root.demoMode)
            return;
        inputProc.running = false;
        checkPermissionsAndTools();
        inputRestartTimer.restart();
    }

    onEnabledChanged: {
        if (!root.enabled) {
            demoStop();
            inputProc.running = false;
        } else {
            if (root.demoMode)
                restartDemo();
            else
                inputRestartTimer.restart();
        }
    }

    onDemoModeChanged: {
        if (root.demoMode) {
            inputProc.running = false;
            restartDemo();
        } else {
            demoStop();
            inputRestartTimer.restart();    // resume real listening
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
            inputRestartTimer.restart();
        }
    }

    Process {
        id: groupCheck
        command: ["sh", "-c", "id -nG | tr ' ' '\\n' | grep -qx input"]
        running: false
        onExited: exitCode => {
            root.notInInputGroup = (exitCode !== 0);
            inputRestartTimer.restart();
        }
    }

    // The listener has an explicit lifecycle so a mode/visibility toggle cannot
    // accidentally break a QML binding on Process.running.
    Process {
        id: inputProc

        command: root.selectedDevicePath === "all"
                 ? ["libinput", "debug-events", "--show-keycodes"]
                 : ["evtest", root.selectedDevicePath]

        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                // Nameless activity detection: matches presence only; key names
                // and codes are discarded, never stored or exposed.
                if (data.includes("EV_KEY")) {
                    if (data.includes("value 1") || data.includes("value 2"))
                        root.reportActivity();
                } else if (data.includes("KEYBOARD_KEY")) {
                    if (data.includes("pressed") || data.includes("repeat"))
                        root.reportActivity();
                }
            }
        }

        stderr: StdioCollector {}

        onExited: {
            // Unexpected exit (device hotplug, libinput crash): bounded respawn.
            if (root.shouldListen) {
                console.log("[Sisyphus] input listener exited, restarting shortly");
                bounceTimer.restart();
            }
        }
    }

    property bool failLockout: false
    property int retryCount: 0

    // 200 ms restart cadence, like the reference implementation.
    Timer {
        id: inputRestartTimer

        interval: 200
        onTriggered: {
            if (!root.shouldListen)
                return;
            if (!inputProc.running) {
                root.retryCount = 0;
                inputProc.running = true;
            }
        }
    }

    Timer {
        id: bounceTimer

        interval: 400
        onTriggered: {
            if (!root.shouldListen)
                return;
            if (root.retryCount < 5)
                root.retryCount++;
            else
                root.failLockout = true;        // surface status instead of spin-looping
            if (!root.failLockout)
                inputProc.running = true;
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
