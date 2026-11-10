pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "./components"
import "./services"

// Sisyphus as a native bar widget (same integration pattern as the Bongo Cat
// plugin): a PluginComponent providing horizontalBarPill / verticalBarPill.
// Each bar instance runs its own AnimationController + InputActivity, exactly
// like the cat runs one listener per instance.
PluginComponent {
    id: root

    pluginId: "sisyphus"
    pluginService: PluginService

    // ---- settings (auto-loaded into pluginData by PluginComponent) ---------
    property alias animationController: ctrl
    readonly property int pushSpeed: (pluginData && pluginData.pushSpeed !== undefined) ? pluginData.pushSpeed : 7
    readonly property real charScale: (pluginData && pluginData.charSize !== undefined ? pluginData.charSize : 100) / 100
    readonly property bool soundEnabled: pluginData && pluginData.soundEnabled !== undefined ? pluginData.soundEnabled : true
    readonly property bool demoMode: (pluginData && pluginData.detectionMode !== undefined) ? pluginData.detectionMode === "demo" : false
    readonly property string detectionMode: (pluginData && pluginData.detectionMode !== undefined) ? pluginData.detectionMode : "auto"
    readonly property string selectedDevicePath: (pluginData && pluginData.selectedDevicePath !== undefined) ? pluginData.selectedDevicePath : "all"
    readonly property string sceneTheme: (pluginData && pluginData.sceneTheme !== undefined) ? pluginData.sceneTheme : "classic"
    readonly property color sceneCustomColor: (pluginData && typeof pluginData.sceneCustomColor === "string") ? pluginData.sceneCustomColor : Theme.primary
    readonly property color sceneSkyColor: {
        switch (sceneTheme) {
        case "twilight":
            return Theme.surfaceContainerHigh;
        case "forest":
            return Theme.surfaceContainerHighest;
        case "sunset":
            return Theme.secondaryContainer;
        case "custom":
            return Qt.darker(sceneCustomColor, 1.8);
        default:
            return Theme.surfaceContainer;
        }
    }
    readonly property var sceneThemeOptions: [
        { label: I18n.trFor("sisyphus", "Classic"), value: "classic" },
        { label: I18n.trFor("sisyphus", "Twilight"), value: "twilight" },
        { label: I18n.trFor("sisyphus", "Forest"), value: "forest" },
        { label: I18n.trFor("sisyphus", "Sunset"), value: "sunset" },
        { label: I18n.trFor("sisyphus", "Custom"), value: "custom" }
    ]

    function saveSetting(key, value) {
        try {
            pluginService.savePluginData(pluginId, key, value);
            if (pluginData)
                pluginData[key] = value;
        } catch (error) {
            console.warn("[Sisyphus] Failed to save setting:", key, error);
        }
    }

    AnimationController {
        id: ctrl

        speed: root.pushSpeed
        soundEnabled: root.soundEnabled
        active: root.surfaceLive
    }

    InputActivity {
        id: inputListener

        enabled: root.surfaceLive
        demoMode: root.demoMode
        selectedDevicePath: root.detectionMode === "device" ? root.selectedDevicePath : "all"
        onActivityPulse: ctrl.pulse()
    }

    readonly property bool inputBroken: inputListener.inputBroken

    // Keep the existing pill viewport size while zooming around both actors.
    readonly property var sceneFocus: Qt.point(124, 35)
    readonly property real sceneZoom: 1.7
    readonly property real hCropW: 92
    readonly property real hCropH: 56
    readonly property real barPillPadding: 6 * root.widgetThickness / 30
    readonly property real vCropS: 64

    horizontalBarPill: Component {
        Item {
            id: hPill

            readonly property real s: Math.max(0.4, Math.min(0.9, root.widgetThickness * 0.92 / root.hCropH))

            implicitWidth: hScene.width - root.barPillPadding * 2
            implicitHeight: Math.max(root.iconSize, hScene.height)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerPopout()
            }

            Item {
                id: hScene

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: root.hCropW * hPill.s + root.barPillPadding * 2
                height: root.hCropH * hPill.s
                clip: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: roundedMask
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.height / 2
                    color: root.sceneSkyColor
                }

                Rectangle {
                    id: roundedMask

                    anchors.fill: parent
                    radius: parent.height / 2
                    color: "white"
                    visible: false
                    layer.enabled: true
                }

                Item {
                    id: hOffset

                    width: 160
                    height: 120
                    x: hScene.width / 2 - root.sceneFocus.x * hPill.s * root.sceneZoom
                    y: hScene.height / 2 - root.sceneFocus.y * hPill.s * root.sceneZoom
                    transformOrigin: Item.TopLeft
                    transform: Scale {
                        xScale: hPill.s * root.sceneZoom
                        yScale: hPill.s * root.sceneZoom
                    }

                    SisyphusScene {
                        ctrl: root.animationController
                        themeName: root.sceneTheme
                        customTint: root.sceneCustomColor
                        charScale: root.charScale
                    }
                }
            }

            DIcon {
                visible: root.inputBroken
                name: "warning"
                size: Math.max(12, Math.round(root.iconSize * 0.5))
                color: Theme.error
                anchors.top: parent.top
                anchors.right: parent.right
            }
        }
    }

    verticalBarPill: Component {
        Item {
            id: vPill

            readonly property real s: Math.max(0.35, Math.min(0.8, root.widgetThickness * 0.86 / root.vCropS))

            implicitWidth: root.vCropS * s
            implicitHeight: Math.max(root.iconSize, root.vCropS * s)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerPopout()
            }

            Item {
                id: vScene

                anchors.centerIn: parent
                width: root.vCropS * vPill.s
                height: root.vCropS * vPill.s
                clip: true

                Item {
                    id: vOffset

                    width: 160
                    height: 120
                    x: vScene.width / 2 - root.sceneFocus.x * vPill.s * root.sceneZoom
                    y: vScene.height / 2 - root.sceneFocus.y * vPill.s * root.sceneZoom
                    transformOrigin: Item.TopLeft
                    transform: Scale {
                        xScale: vPill.s * root.sceneZoom
                        yScale: vPill.s * root.sceneZoom
                    }

                    SisyphusScene {
                        ctrl: root.animationController
                        themeName: root.sceneTheme
                        customTint: root.sceneCustomColor
                        charScale: root.charScale
                    }
                }

            }

            DIcon {
                visible: root.inputBroken
                name: "warning"
                size: Theme.iconSizeSmall
                color: Theme.error
                anchors.top: parent.top
                anchors.left: parent.left
            }
        }
    }

    popoutWidth: 320
    popoutHeight: 0

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: I18n.trFor("sisyphus", "Sisyphus")
            showCloseButton: false

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    width: parent.width
                    text: I18n.trFor("sisyphus", "Appearance")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                DDropdown {
                    width: parent.width
                    text: I18n.trFor("sisyphus", "Scene theme")
                    options: root.sceneThemeOptions.map(option => option.label)
                    currentValue: {
                        for (let i = 0; i < root.sceneThemeOptions.length; i++) {
                            if (root.sceneThemeOptions[i].value === root.sceneTheme)
                                return root.sceneThemeOptions[i].label;
                        }
                        return root.sceneThemeOptions[0].label;
                    }
                    onValueChanged: label => {
                        for (let i = 0; i < root.sceneThemeOptions.length; i++) {
                            if (root.sceneThemeOptions[i].label === label) {
                                root.saveSetting("sceneTheme", root.sceneThemeOptions[i].value);
                                return;
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.trFor("sisyphus", "Custom terrain tint is configured in Sisyphus settings.")
                    visible: root.sceneTheme === "custom"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                DButton {
                    width: parent.width
                    text: root.soundEnabled
                          ? I18n.trFor("sisyphus", "Stone sound: On")
                          : I18n.trFor("sisyphus", "Stone sound: Off")
                    onClicked: root.saveSetting("soundEnabled", !root.soundEnabled)
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width * 0.3
                        text: I18n.trFor("sisyphus", "Push speed")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DSlider {
                        width: parent.width * 0.7 - Theme.spacingS
                        value: root.pushSpeed
                        minimum: 1
                        maximum: 20
                        showValue: true
                        onSliderValueChanged: value => root.saveSetting("pushSpeed", value)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width * 0.3
                        text: I18n.trFor("sisyphus", "Character size")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DSlider {
                        width: parent.width * 0.7 - Theme.spacingS
                        value: root.charScale * 100
                        minimum: 50
                        maximum: 200
                        showValue: true
                        unit: "%"
                        onSliderValueChanged: value => root.saveSetting("charSize", value)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
