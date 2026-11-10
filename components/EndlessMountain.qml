pragma ComponentBehavior: Bound
import QtQuick

// ENDLESS slope scenery (160x120 logical px, no summit, no flag).
//
// The slope line leaves the canvas through the top-right corner: there is no
// visible endpoint. The illusion of perpetual climbing comes from two moving
// layers that are functions of `worldDist` (distance traveled, unbounded):
//   1. a conveyor of small surface chips travelling downhill past the camera,
//   2. a far ridge + clouds scrolling at a fraction of the speed (parallax).
// Chip positions are periodic along the slope (period L). x/y derive from
// worldDist, so the pattern is seamless forever and never resets the journey.
Item {
    id: scene

    // ---- geometry constants (keep in sync with scripts/generate_assets.py) --
    readonly property int canvasW: 160
    readonly property int canvasH: 120
    readonly property real sx0: 22
    readonly property real sy0: 104
    readonly property real dirX: 130 / 147.65
    readonly property real dirY: -70 / 147.65
    readonly property real normX: dirY          // surface normal pointing up-left
    readonly property real normY: -dirX
    readonly property real boulderRadius: 11

    // world offset bound by the AnimationController (px traveled uphill)
    property real worldDist: 0

    // ---- anchors (the boulder and character hold ONE place on screen; the
    // mountain itself never reaches anywhere — it goes on forever) -----------
    // anchor contact point t = 130 along the slope, measured from (22,104)
    readonly property real contactX: sx0 + dirX * 130
    readonly property real contactY: sy0 + dirY * 130

    function boulderCenter() {
        const lag = boulderRadius * 0.55;
        return Qt.point(contactX + normX * boulderRadius + dirX * lag,
                        contactY + normY * boulderRadius + dirY * lag);
    }

    function sisyphusFeet() {
        const behind = boulderRadius + 2 + 11;
        return Qt.point(contactX - dirX * behind, contactY - dirY * behind);
    }

    // ---- static silhouette ---------------------------------------------------
    Image {
        source: Qt.resolvedUrl("../assets/sprites/mountain_body.png")
        smooth: false
        mipmap: false
    }

    // ---- far parallax ridge (tileable 160px, scrolls slowly) -----------------
    Image {
        source: Qt.resolvedUrl("../assets/sprites/far_ridge.png")
        y: 4
        x: -mod2(scene.worldDist * 0.16, 160)
        smooth: false
        mipmap: false
        opacity: 0.85
    }

    Image {
        source: Qt.resolvedUrl("../assets/sprites/far_ridge.png")
        y: 4
        x: -mod2(scene.worldDist * 0.16, 160) + 160
        smooth: false
        mipmap: false
        opacity: 0.85
    }

    // ---- drifting clouds (very slow) ------------------------------------------
    Image {
        source: Qt.resolvedUrl("../assets/sprites/cloud.png")
        y: 10
        x: -mod2(scene.worldDist * 0.06, 230)
        smooth: true
        mipmap: false
    }

    Image {
        source: Qt.resolvedUrl("../assets/sprites/cloud.png")
        y: 20
        x: -mod2(scene.worldDist * 0.06, 230) + 115
        smooth: true
        opacity: 0.7
        mipmap: false
    }

    function mod2(v, m) {
        const r = v % m;
        return r < 0 ? r + m : r;
    }

    // ---- surface chip conveyor -------------------------------------------------
    // Each chip has a phase f in 0..period, a depth into the slope face and a
    // sprite kind/scale. `along` grows with worldDist, so chips flow downhill
    // past the stationary camera; the cast is seamless because the phase space
    // is periodic. Kinds: 0 pebble, 1 snow, 2 grass tuft.
    readonly property real chipPeriod: 210
    readonly property var chipAnchorX: sx0 + dirX * chipPeriod      // off-canvas top-right
    readonly property real chipAnchorY: sy0 + dirY * chipPeriod
    readonly property var chipSprites: [
        Qt.resolvedUrl("../assets/sprites/chip_pebble.png"),
        Qt.resolvedUrl("../assets/sprites/chip_snow.png"),
        Qt.resolvedUrl("../assets/sprites/chip_tuft.png")
    ]
    readonly property var chipDefs: [
        { f: 0.02, d: 7,  k: 0, s: 1.0 },
        { f: 0.07, d: 16, k: 1, s: 1.0 },
        { f: 0.13, d: 28, k: 0, s: 1.3 },
        { f: 0.19, d: 9,  k: 2, s: 1.0 },
        { f: 0.24, d: 22, k: 1, s: 1.2 },
        { f: 0.31, d: 12, k: 0, s: 0.9 },
        { f: 0.37, d: 34, k: 2, s: 1.1 },
        { f: 0.43, d: 6,  k: 1, s: 1.0 },
        { f: 0.50, d: 19, k: 0, s: 1.1 },
        { f: 0.56, d: 30, k: 1, s: 0.9 },
        { f: 0.63, d: 10, k: 2, s: 1.0 },
        { f: 0.70, d: 24, k: 0, s: 1.2 },
        { f: 0.77, d: 14, k: 1, s: 1.0 },
        { f: 0.84, d: 33, k: 0, s: 0.8 },
        { f: 0.91, d: 8,  k: 2, s: 1.0 },
        { f: 0.97, d: 20, k: 1, s: 1.1 }
    ]

    Repeater {
        model: scene.chipDefs

        delegate: Image {
            id: chip

            required property var modelData

            readonly property real along: {
                const raw = (modelData.f * scene.chipPeriod + scene.worldDist) % scene.chipPeriod;
                return raw < 0 ? raw + scene.chipPeriod : raw;
            }
            // anchor + (-dir)*along + (-normal)*depth
            x: scene.chipAnchorX - scene.dirX * along - scene.normX * modelData.d
               - width * modelData.s / 2
            y: scene.chipAnchorY - scene.dirY * along - scene.normY * modelData.d
               - height * modelData.s / 2
            width: implicitWidth * modelData.s
            height: implicitHeight * modelData.s
            source: scene.chipSprites[modelData.k]
            smooth: false
            mipmap: false
            z: 1
        }
    }
}
