pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Lists keyboard evdev devices by parsing /proc/bus/input/devices.
// The scanner reads device metadata (names/handlers) only — never payloads.
QtObject {
    id: scanner

    readonly property string script: `
import os, json, re
exclude = ["power button", "video bus", "speaker", "headphone", "lid switch",
           "touchpad", "extra buttons", "uinput", "webcam", "mouse",
           "consumer control", "system control", "eisa"]
devs = []
try:
    with open('/proc/bus/input/devices', encoding='utf-8', errors='replace') as f:
        content = f.read()
except OSError:
    pass
else:
    for section in content.strip().split('\\n\\n'):
        name = ""
        handlers = ""
        for line in section.split('\\n'):
            if line.startswith('N: Name='):
                m = re.search(r'Name="([^"]+)"', line)
                if m:
                    name = m.group(1)
            elif line.startswith('H: Handlers='):
                handlers = line
        if not name or 'kbd' not in handlers:
            continue
        lower = name.lower()
        if any(x in lower for x in exclude):
            continue
        m = re.search(r'event(\\d+)', handlers)
        if not m:
            continue
        devs.append({"label": name + " (event" + m.group(1) + ")",
                     "value": "/dev/input/event" + m.group(1)})
print(json.dumps(devs))
`

    property Process scanProcess: Process {
        id: scanProc
        command: ["python3", "-c", scanner.script]
        running: false
        property var cb: null
        stdout: StdioCollector {
            onStreamFinished: scanProc.completeScan(text)
        }
        stderr: StdioCollector {}

        function completeScan(output) {
            if (!scanProc.cb)
                return;
            let devices;
            try {
                devices = JSON.parse(output.trim() || "[]");
                if (!Array.isArray(devices))
                    throw new Error("Keyboard scan did not return a list");
            } catch (error) {
                console.warn("[Sisyphus] Failed to parse keyboard scan output:", error);
                scanProc.cb([]);
                return;
            }
            scanProc.cb(devices);
        }
    }

    function listKeyboards(cb) {
        scanProc.cb = cb;
        scanProc.running = false;
        Qt.callLater(() => {
            scanProc.running = true;
        });
    }
}
