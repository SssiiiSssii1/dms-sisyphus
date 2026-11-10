# Sisyphus

Sisyphus is a DMS companion that pushes an endless boulder uphill while you
type. It provides a compact DankBar widget, an optional desktop scene, theme
controls, and a quiet optional rolling-stone sound.

## Install

Clone this repository into DMS's plugin directory, then restart DMS:

```sh
git clone https://github.com/SssiiiSssii1/dms-sisyphus.git \
  ~/.config/dms/plugins/sisyphus
dms restart
```

Enable the plugin in DMS plugin settings. Add Sisyphus to the bar from the
DankBar widget settings, or enable its desktop widget.

## Keyboard activity

Automatic detection uses `libinput` to detect key activity. Install the
`libinput` command-line tools and Python 3 for your distribution, and make sure
your user can read input devices (commonly by being in the `input` group).
Restart your session after changing group membership. The optional specific
keyboard mode also uses `evtest`.

Sisyphus only reacts to key activity. It does not record, display, or transmit
typed characters or key identities. If input access is unavailable, choose
Demo mode in Sisyphus settings.

## Controls

- Choose Classic, Twilight, Forest, Sunset, or a custom terrain tint.
- Adjust push speed and character size.
- Disable the rolling-stone sound in settings or the bar popout.
- Choose automatic keyboard detection, one keyboard, or Demo mode.

## Requirements

- DMS 2.0 or newer
- `libinput` for automatic keyboard activity detection
- Python 3 for the keyboard-device picker
- `evtest` for specific-keyboard detection

The animation and manual/demo modes do not require keyboard-device access.
