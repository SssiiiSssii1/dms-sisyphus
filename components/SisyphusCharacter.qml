pragma ComponentBehavior: Bound
import QtQuick

// Sisyphus character sprite frames: idle, push1, push2, victory.
// The sprite is anchored at the feet; the push frames face the boulder to the right.
Image {
    id: sisyphus

    required property string frameName    // "idle" | "push1" | "push2" | "victory"
    readonly property int spriteW: 24
    readonly property int spriteH: 28
    readonly property int feetOffsetFromTop: 25

    source: Qt.resolvedUrl("../assets/sprites/sisyphus_" + frameName + ".png")
    smooth: false
    mipmap: false
}
