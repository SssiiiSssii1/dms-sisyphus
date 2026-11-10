pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia
import Quickshell

// ENDLESS animation controller for Sisyphus (Camus: there is no summit).
//
// States: idle -> pushing <-> resting (nothing else, ever).
// `dist` is distance traveled along the slope in logical px. It only ever
// grows while typing; stopping twice never rewinds it. The looping terrain
// (see EndlessMountain) is drawn from `dist`, but dist itself never resets.
Item {
    id: ctrl

    // ---- configuration ----------------------------------------------------
    property int speed: 7                 // 1..20, from settings
    property bool frozen: false           // host lock screen: pause everything
    property bool active: true            // caller gates visibility (bar autohide)
    property bool testMode: false         // autonomous scene test; disabled in production
    property bool soundEnabled: true
    property bool soundQueued: false

    // ---- outputs read by the scene ----------------------------------------
    property real dist: 0                 // px traveled uphill, NEVER decreases via logic
    property string state: "idle"         // idle | pushing | resting
    property int pushFrame: 0             // alternates between the two push poses
    property real reach: 0                // 0..1 lean intensity while pushing

    readonly property bool busy: state !== "idle"

    // ---- internal ----------------------------------------------------------
    property real velocity: 0             // px per second
    property real lastPulseTime: 0        // ms epoch
    property real lastToggleTime: 0       // ms epoch (push frame cadence)
    readonly property int toggleHoldMs: 90
    readonly property real boulderRadius: 11   // must match sprites/EndlessMountain
    readonly property real slopeLen: 147.65    // logical px of the full slope line
    readonly property real pushVel: slopeLen / Math.max(2.5, 45 / Math.max(1, speed))
    readonly property int typingGapMs: 350

    // boulder wheel angle in degrees: the wheel keeps turning forever;
    // the view wraps it mod 360, which is rotation, not progress.
    readonly property real boulderAngle: dist / boulderRadius * 57.2958

    function playRollSound() {
        if (!soundEnabled)
            return;
        if (rollSound.playing) {
            soundQueued = true;
            return;
        }
        soundQueued = false;
        rollSound.play();
    }

    function pulse() {
        lastPulseTime = Date.now();
        if (frozen)
            return;
        playRollSound();
        if (state !== "pushing")
            state = "pushing";
        // small tactile kick, capped so it cannot outrun full push speed
        velocity = Math.min(velocity + 1.2, pushVel * 1.4);
    }

    function step(dt) {
        const now = Date.now();
        if (state === "pushing") {
            const active = (now - lastPulseTime) < typingGapMs;
            if (active && now - lastToggleTime >= toggleHoldMs) {
                pushFrame = pushFrame === 0 ? 1 : 0;
                lastToggleTime = now;
            }
            const target = active ? pushVel : 0;
            const k = Math.min(1, dt * (active ? 9 : 4));
            velocity += (target - velocity) * k;
            if (velocity > 0.001)
                dist += velocity * dt;
            if (!active && velocity < 0.5) {
                velocity = 0;
                state = "resting";
            }
        } else if (state === "resting") {
            velocity += (0 - velocity) * Math.min(1, dt * 8);
            if (velocity < 0.05) {
                velocity = 0;
                state = "idle";
            }
        }

        reach = state === "pushing" ? Math.min(1, reach + dt * 6) : Math.max(0, reach - dt * 6);
    }

    Timer {
        id: tick

        interval: 33
        repeat: true
        running: (ctrl.busy || ctrl.testMode) && !ctrl.frozen && ctrl.active
        onTriggered: ctrl.step(0.033)
    }

    Timer {
        interval: 160
        repeat: true
        running: ctrl.testMode && !ctrl.frozen && ctrl.active
        onTriggered: ctrl.pulse()
    }

    SoundEffect {
        id: rollSound

        source: Qt.resolvedUrl("../assets/sounds/stone_roll.wav")
        volume: 0.16

        onPlayingChanged: {
            if (!playing && ctrl.soundQueued && ctrl.soundEnabled) {
                ctrl.soundQueued = false;
                play();
            }
        }
    }

    onSoundEnabledChanged: {
        if (!soundEnabled) {
            soundQueued = false;
            rollSound.stop();
        }
    }

    onFrozenChanged: {
        if (!frozen)
            lastPulseTime = 0;            // avoid instant timeout after unlock
    }

    onStateChanged: {
        if (state === "idle") {
            reach = 0;
            velocity = 0;
        }
    }
}
