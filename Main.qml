pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "./components"
import "./services"

// Sisyphus — a keyboard-driven desktop companion for Dux Shell (DMS).
// Sisyphus pushes his boulder uphill while you type. The mountain is endless:
// there is no summit and no finish line; stopping just means resting, and
// resuming continues from exactly where he left off.
DesktopPluginComponent {
    id: root

    pluginId: "sisyphus"
    pluginService: PluginService

    minWidth: 160
    minHeight: 120
    // DMS 2.0 reads default size from implicitWidth/implicitHeight
    implicitWidth: 320
    implicitHeight: 240

    // ---------------------------------------------------------------- settings
    // _settingsRev forces re-evaluation of the settings bindings below whenever
    // pluginService emits pluginDataChanged (global or per-instance).
    property int _settingsRev: 0

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedId) {
            if (changedId === root.pluginId)
                root._settingsRev++;
        }
    }

    // getData() reads per-instance config first, then falls back to global settings
    readonly property int pushSpeed: root._settingsRev >= 0 ? getData("pushSpeed", 7) : 7
    readonly property real charScale: (root._settingsRev >= 0 ? getData("charSize", 100) : 100) / 100
    readonly property bool soundEnabled: root._settingsRev >= 0 ? getData("soundEnabled", true) : true
    readonly property real backgroundOpacity: (root._settingsRev >= 0 ? getData("backgroundOpacity", 0) : 0) / 100
    readonly property string detectionMode: root._settingsRev >= 0 ? getData("detectionMode", "auto") : "auto"
    readonly property string selectedDevicePath: root._settingsRev >= 0 ? getData("selectedDevicePath", "all") : "all"
    readonly property string sceneTheme: root._settingsRev >= 0 ? getData("sceneTheme", "classic") : "classic"
    readonly property color sceneCustomColor: {
        const value = root._settingsRev >= 0 ? getData("sceneCustomColor", Theme.primary) : Theme.primary;
        return typeof value === "string" ? value : Theme.primary;
    }
    readonly property bool demoMode: detectionMode === "demo"

    // ---------------------------------------------------------------- actors
    AnimationController {
        id: ctrl

        speed: root.pushSpeed
        soundEnabled: root.soundEnabled
        frozen: root.lockScreen
        active: true
    }

    InputActivity {
        id: inputListener

        enabled: !root.lockScreen
        demoMode: root.demoMode
        selectedDevicePath: root.detectionMode === "device" ? root.selectedDevicePath : "all"
        onActivityPulse: ctrl.pulse()
    }

    // ---------------------------------------------------------------- chrome
    Rectangle {
        id: backgroundRect

        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surface, root.backgroundOpacity)
        border.color: Theme.withAlpha(Theme.outline, root.backgroundOpacity > 0 ? 0.2 : 0)
        border.width: 1
    }

    // ---------------------------------------------------------------- scene
    // Sprite canvas is 160x120 logical px; the whole scene scales to fit the
    // widget box while keeping its 4:3 frame.
    Item {
        id: sceneWrapper

        readonly property real scale: Math.max(0.5, Math.min(root.widgetWidth / 160, root.widgetHeight / 120))

        width: 160 * scale
        height: 120 * scale
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        Item {
            id: sceneHold

            width: 160
            height: 120
            transformOrigin: Item.TopLeft
            transform: Scale {
                xScale: sceneWrapper.scale
                yScale: sceneWrapper.scale
            }

            SisyphusScene {
                ctrl: ctrl
                themeName: root.sceneTheme
                customTint: root.sceneCustomColor
                charScale: root.charScale
            }
        }
    }

    // A little poke: clicking the scene nudges the boulder too.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: ctrl.pulse()
    }
}
