import QtQuick
import QtMultimedia

Item {
    id: root

    property alias playing: sound.playing

    function play() {
        sound.play();
    }

    function stop() {
        sound.stop();
    }

    SoundEffect {
        id: sound

        source: Qt.resolvedUrl("../assets/sounds/stone_roll.wav")
        volume: 0.16
    }
}
