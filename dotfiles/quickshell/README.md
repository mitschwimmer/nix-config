# Quickshell desktop

The Niri session starts one Quickshell process with a wallpaper, notification
popups and an on-screen display. It uses the monochrome palette in
`Palette.qml`, with red (`#D71921`) reserved for small accents.

- `shell.qml`: composition root.
- `NiriState.qml`: shared Niri event stream, focused output and workspace state.
- `Wallpaper.qml`: existing per-output wallpaper rotation and effects.
- `Notifications.qml`: freedesktop notification server and interactive popups.
- `Osd.qml`: PipeWire audio, MPRIS transport and brightness control.

Notifications and the OSD appear on the focused monitor, or the first monitor
until Niri reports one. No permanent bar or notification history is kept.

## Manual checks

After switching to the new NixOS generation, log out and back in so Niri
starts the new shell.

```sh
qs ipc show
qs ipc call osd volumeUp
qs ipc call osd volumeMute
qs ipc call osd micMute
qs ipc call osd brightnessUp
qs ipc call osd mediaPlayPause
nix shell nixpkgs#libnotify -c notify-send -a "Quickshell test" "Notification" "Popups should appear on the focused monitor"
```

Check keyboard volume, microphone, brightness and media keys, notification
actions and close buttons, multiple monitors, wallpaper dimming on occupied
workspaces, rotation and crossfades.

The lock screen and launcher remain Swaylock and Fuzzel.
