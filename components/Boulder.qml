pragma ComponentBehavior: Bound
import QtQuick

// The boulder sprite (26x26 px PNG, radius 11 logical px). The parent
// positions it at the boulder's visual center minus half the scaled sprite
// size; rotation is applied about the center via transformOrigin.
Image {
    id: boulder

    property int spriteSize: 26

    source: Qt.resolvedUrl("../assets/sprites/boulder.png")
    smooth: false
    mipmap: false
    transformOrigin: Item.Center
}
