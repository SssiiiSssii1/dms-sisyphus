pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// The complete Sisyphus vignette: endless mountain + rolling boulder + the
// man. Shared by the desktop widget (full 160x120 canvas) and the bar pill
// (cropped window scaled to `widgetThickness`). The camera never moves: only
// the world scrolls from `ctrl.dist`, which has no upper bound.
Item {
    id: sceneRoot

    required property var ctrl             // AnimationController instance
    property string themeName: "classic"
    property color customTint: "#6a82a8"
    property real charScale: 1.0

    width: 160
    height: 120

    readonly property color terrainTint: {
        switch (themeName) {
        case "twilight":
            return "#7588c6";
        case "forest":
            return "#78a36f";
        case "sunset":
            return "#e58d60";
        case "custom":
            return customTint;
        default:
            return "#464a66";
        }
    }
    readonly property real terrainColorization: themeName === "classic" ? 0 : 0.28

    Item {
        id: terrain

        anchors.fill: parent
        layer.enabled: sceneRoot.terrainColorization > 0
        layer.effect: MultiEffect {
            colorization: sceneRoot.terrainColorization
            colorizationColor: sceneRoot.terrainTint
        }

        EndlessMountain {
            id: mountain

            worldDist: sceneRoot.ctrl.dist
        }
    }

    Boulder {
        id: boulder

        readonly property var center: mountain.boulderCenter()
        readonly property real s: sceneRoot.charScale * 1.12

        x: center.x - spriteSize / 2 * s
        y: center.y - spriteSize / 2 * s
           + (sceneRoot.ctrl.state === "pushing" && sceneRoot.ctrl.pushFrame !== 0 ? 0.3 * s : 0)
        width: spriteSize * s
        height: spriteSize * s
        rotation: sceneRoot.ctrl.boulderAngle % 360
        z: 2
    }

    SisyphusCharacter {
        id: sisyphus

        readonly property real s: sceneRoot.charScale * 0.5
        readonly property var feet: mountain.sisyphusFeet()

        x: feet.x - spriteW / 2 * s
           + (sceneRoot.ctrl.state === "pushing" ? sceneRoot.ctrl.reach * 0.6 * s : 0)
        y: feet.y - feetOffsetFromTop * s
           + (sceneRoot.ctrl.state === "pushing" && sceneRoot.ctrl.pushFrame !== 0 ? 0.8 * s : 0)
        width: spriteW * s
        height: spriteH * s
        rotation: sceneRoot.ctrl.state === "pushing"
                  ? (sceneRoot.ctrl.pushFrame === 0 ? 1.2 : 2.0) : 0
        transformOrigin: Item.Center
        frameName: sceneRoot.ctrl.state === "pushing"
                   ? (sceneRoot.ctrl.pushFrame === 0 ? "push1" : "push2")
                   : "idle"
        z: 3
    }
}
