pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "../services"

PluginSettings {
    id: settingsRoot

    pluginId: "sisyphus"

    // ------------------------------------------------------------- diagnostics
    property bool toolMissing: true
    property bool notInInput: false
    property var devices: []
    property bool scanning: false
    property string mode: ""
    property string sceneTheme: "classic"

    InputScanner {
        id: inputScanner
    }

    readonly property var modeOptions: [
        {
            label: I18n.trFor("sisyphus", "Auto (all keyboards)"),
            value: "auto"
        },
        {
            label: I18n.trFor("sisyphus", "Pick a keyboard"),
            value: "device"
        },
        {
            label: I18n.trFor("sisyphus", "Demo mode"),
            value: "demo"
        }
    ]

    readonly property var sceneThemeOptions: [
        { label: I18n.trFor("sisyphus", "Classic"), value: "classic" },
        { label: I18n.trFor("sisyphus", "Twilight"), value: "twilight" },
        { label: I18n.trFor("sisyphus", "Forest"), value: "forest" },
        { label: I18n.trFor("sisyphus", "Sunset"), value: "sunset" },
        { label: I18n.trFor("sisyphus", "Custom"), value: "custom" }
    ]

    function refreshSettings() {
        mode = loadValue("detectionMode", "auto");
        sceneTheme = loadValue("sceneTheme", "classic");
    }

    onSettingChanged: settingsRoot.refreshSettings()
    onPluginServiceChanged: settingsRoot.refreshSettings()

    Connections {
        target: settingsRoot.pluginService
        enabled: settingsRoot.pluginService !== null

        function onPluginDataChanged(changedId) {
            if (changedId === settingsRoot.pluginId)
                settingsRoot.refreshSettings();
        }
    }

    Process {
        id: toolProbe

        command: ["sh", "-c", "command -v libinput >/dev/null 2>&1"]
        running: false
        onExited: exitCode => settingsRoot.toolMissing = (exitCode !== 0)
    }

    Process {
        id: groupProbe

        command: ["sh", "-c", "id -nG | tr ' ' '\\n' | grep -qx input"]
        running: false
        onExited: exitCode => settingsRoot.notInInput = (exitCode !== 0)
    }

    Component.onCompleted: {
        toolProbe.running = true;
        groupProbe.running = true;
        refreshDevices();
        refreshSettings();
    }

    function refreshDevices() {
        scanning = true;
        inputScanner.listKeyboards(devices => {
            settingsRoot.devices = devices;
            scanning = false;
        });
    }

    // Check whether the bar widget capability is active, purely informational
    readonly property string surfaceNote: I18n.trFor("sisyphus", "Sisyphus can live in the DankBar (add him under bar widgets) and/or on the desktop as a floating pixel scene.")

    // ---------------------------------------------------------------- content
    StyledText {
        width: parent.width
        text: I18n.trFor("sisyphus", "Sisyphus")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("sisyphus", "He pushes the boulder uphill while you type. There is no summit — the task, like the myth, is endless.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "sceneTheme"
        label: I18n.trFor("sisyphus", "Scene theme")
        description: I18n.trFor("sisyphus", "Choose a landscape palette, or set a custom terrain tint.")
        defaultValue: "classic"
        options: settingsRoot.sceneThemeOptions
    }

    ColorSetting {
        visible: settingsRoot.sceneTheme === "custom"
        settingKey: "sceneCustomColor"
        label: I18n.trFor("sisyphus", "Custom terrain tint")
        description: I18n.trFor("sisyphus", "Used by the Custom scene theme.")
        defaultValue: Theme.primary
    }

    // Detection mode
    SelectionSetting {
        settingKey: "detectionMode"
        label: I18n.trFor("sisyphus", "Detection mode")
        description: I18n.trFor("sisyphus", "Auto uses the libinput CLI to watch all keyboards. Demo mode needs no permissions at all.")
        defaultValue: "auto"
        options: settingsRoot.modeOptions
    }

    // Specific device picker
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: settingsRoot.mode === "device"

        Row {
            width: parent.width - Theme.spacingM
            spacing: Theme.spacingM

            DDropdown {
                width: parent.width - 140
                text: I18n.trFor("sisyphus", "Keyboard device")
                description: settingsRoot.devices.length === 0 ? I18n.trFor("sisyphus", "No keyboard devices found") : ""
                currentValue: {
                    const v = loadValue("selectedDevicePath", "all");
                    for (let i = 0; i < settingsRoot.devices.length; i++)
                        if (settingsRoot.devices[i].value === v)
                            return settingsRoot.devices[i].label;
                    return v === "all" ? I18n.trFor("sisyphus", "All keyboards (Auto)") : v;
                }
                options: {
                    const opts = [I18n.trFor("sisyphus", "All keyboards (Auto)")];
                    for (let i = 0; i < settingsRoot.devices.length; i++)
                        opts.push(settingsRoot.devices[i].label);
                    return opts;
                }
                onValueChanged: newValue => {
                    for (let i = 0; i < settingsRoot.devices.length; i++)
                        if (settingsRoot.devices[i].label === newValue) {
                            saveValue("selectedDevicePath", settingsRoot.devices[i].value);
                            return;
                        }
                    saveValue("selectedDevicePath", "all");
                }
            }

            DButton {
                width: 130
                text: settingsRoot.scanning ? I18n.trFor("sisyphus", "Scanning…") : I18n.trFor("sisyphus", "Rescan")
                enabled: !settingsRoot.scanning
                onClicked: settingsRoot.refreshDevices()
            }
        }
    }

    // Status hints
    Column {
        width: parent.width
        spacing: Theme.spacingXS
        visible: settingsRoot.mode !== "demo"

        StyledText {
            width: parent.width
            visible: settingsRoot.notInInput
            text: I18n.trFor("sisyphus", "Your user is not in the 'input' group, so typing cannot be detected. Run: sudo usermod -aG input $USER, then log out and back in.")
            color: Theme.error
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        StyledText {
            width: parent.width
            visible: settingsRoot.toolMissing && !settingsRoot.notInInput
            text: I18n.trFor("sisyphus", "The 'libinput' CLI was not found. Install it (Fedora: libinput-utils, Debian/Ubuntu: libinput-tools) or use Demo mode.")
            color: Theme.error
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        StyledText {
            width: parent.width
            visible: !settingsRoot.notInInput && !settingsRoot.toolMissing
            text: I18n.trFor("sisyphus", "Sisyphus only watches for typing activity. No key content is ever read, stored, or transmitted.")
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }

    // Behaviour
    ToggleSetting {
        settingKey: "soundEnabled"
        label: I18n.trFor("sisyphus", "Rolling stone sound")
        description: I18n.trFor("sisyphus", "Play a quiet stone-on-rock sound as the boulder rolls. Fast keystrokes are combined without overlapping audio.")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "pushSpeed"
        label: I18n.trFor("sisyphus", "Push speed")
        description: I18n.trFor("sisyphus", "How fast the boulder climbs while you type")
        defaultValue: 7
        minimum: 1
        maximum: 20
    }

    SliderSetting {
        settingKey: "charSize"
        label: I18n.trFor("sisyphus", "Character size")
        description: I18n.trFor("sisyphus", "Scene size; Sisyphus stays smaller than the boulder")
        defaultValue: 100
        minimum: 50
        maximum: 200
        unit: "%"
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: I18n.trFor("sisyphus", "Background opacity")
        description: I18n.trFor("sisyphus", "Adds a subtle panel behind the desktop scene (0 keeps it transparent; bar pill is always transparent)")
        defaultValue: 0
        minimum: 0
        maximum: 100
        unit: "%"
    }
}
