pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int nextClientId: 0
    property var clients: ({})
    property var listeners: ({})
    property var lockedOutSources: ({})
    property var restartQueue: []

    readonly property string listenerScript: `
import re
import signal
import subprocess
import sys

source = sys.argv[1]
command = ["libinput", "debug-events"] if source == "all" else ["evtest", source]
child = None

def stop(_signum, _frame):
    if child is not None and child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=1)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
    raise SystemExit(0)

signal.signal(signal.SIGTERM, stop)
try:
    child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             text=True, bufsize=1)
    for line in child.stdout:
        if source == "all":
            is_activity = "KEYBOARD_KEY" in line and ("pressed" in line or "repeat" in line)
        else:
            is_activity = "EV_KEY" in line and re.search(r"\\bvalue [12]\\b", line)
        if is_activity:
            print("activity", flush=True)
    sys.exit(child.wait())
except OSError as error:
    print("[Sisyphus] Failed to start keyboard listener:", error, file=sys.stderr)
    raise SystemExit(127)
finally:
    if child is not None and child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=1)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
`

    signal activityPulse(string sourcePath)
    signal listenerStateChanged(string sourcePath)

    function registerClient(sourcePath) {
        const clientId = ++root.nextClientId;
        root.clients[clientId] = sourcePath;
        root.clients = Object.assign({}, root.clients);
        root.ensureListener(sourcePath);
        return clientId;
    }

    function updateClient(clientId, sourcePath) {
        const oldPath = root.clients[clientId];
        if (oldPath === undefined || oldPath === sourcePath)
            return;

        root.clients[clientId] = sourcePath;
        root.clients = Object.assign({}, root.clients);
        root.reconcileListener(oldPath);
        root.ensureListener(sourcePath);
    }

    function unregisterClient(clientId) {
        const sourcePath = root.clients[clientId];
        if (sourcePath === undefined)
            return;

        delete root.clients[clientId];
        root.clients = Object.assign({}, root.clients);
        root.reconcileListener(sourcePath);
    }

    function clientCount(sourcePath) {
        let count = 0;
        for (const id in root.clients) {
            if (root.clients[id] === sourcePath)
                count++;
        }
        return count;
    }

    function ensureListener(sourcePath) {
        if (root.clientCount(sourcePath) === 0 || root.listeners[sourcePath])
            return;

        const process = listenerComponent.createObject(root, {
            sourcePath: sourcePath
        });
        if (!process) {
            console.warn("[Sisyphus] Failed to create keyboard listener for", sourcePath);
            return;
        }

        root.listeners[sourcePath] = process;
        root.listeners = Object.assign({}, root.listeners);
        process.running = true;
    }

    function reconcileListener(sourcePath) {
        if (root.clientCount(sourcePath) > 0) {
            root.ensureListener(sourcePath);
            return;
        }

        const process = root.listeners[sourcePath];
        if (!process)
            return;

        delete root.listeners[sourcePath];
        root.listeners = Object.assign({}, root.listeners);
        root.restartQueue = root.restartQueue.filter(path => path !== sourcePath);
        process.running = false;
        process.destroy();
    }

    function isLockedOut(sourcePath) {
        return root.lockedOutSources[sourcePath] === true;
    }

    function resetLockout(sourcePath) {
        if (root.lockedOutSources[sourcePath]) {
            delete root.lockedOutSources[sourcePath];
            root.lockedOutSources = Object.assign({}, root.lockedOutSources);
        }
        const process = root.listeners[sourcePath];
        if (!process)
            return;

        process.failLockout = false;
        process.retryCount = 0;
        if (root.clientCount(sourcePath) > 0 && !process.running)
            process.running = true;
        root.listenerStateChanged(sourcePath);
    }

    function handleProcessExit(process, exitCode) {
        const sourcePath = process.sourcePath;
        if (root.listeners[sourcePath] !== process || root.clientCount(sourcePath) === 0)
            return;

        if (process.retryCount >= 5) {
            process.failLockout = true;
            root.lockedOutSources[sourcePath] = true;
            root.lockedOutSources = Object.assign({}, root.lockedOutSources);
            console.warn("[Sisyphus] Keyboard listener stopped for", sourcePath,
                         "after repeated failures; exit code", exitCode);
            root.listenerStateChanged(sourcePath);
            return;
        }

        process.retryCount++;
        if (!root.restartQueue.includes(sourcePath))
            root.restartQueue = root.restartQueue.concat([sourcePath]);
        root.restartTimer.restart();
    }

    property Component listenerComponent: Component {
        Process {
            id: listener

            property string sourcePath: ""
            property int retryCount: 0
            property bool failLockout: false

            command: ["python3", "-u", "-c", root.listenerScript, sourcePath]

            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    if (data !== "activity")
                        return;
                    listener.retryCount = 0;
                    root.activityPulse(listener.sourcePath);
                }
            }

            stderr: StdioCollector {
                id: listenerErrors

                onStreamFinished: {
                    const output = listenerErrors.text.trim();
                    if (output)
                        console.warn("[Sisyphus] Keyboard listener:", output);
                }
            }

            onExited: exitCode => root.handleProcessExit(listener, exitCode)
        }
    }

    property Timer restartTimer: Timer {
        interval: 400
        onTriggered: {
            const pending = root.restartQueue.slice();
            root.restartQueue = [];
            for (let i = 0; i < pending.length; i++) {
                const process = root.listeners[pending[i]];
                if (process && root.clientCount(pending[i]) > 0 && !process.failLockout)
                    process.running = true;
            }
        }
    }
}
