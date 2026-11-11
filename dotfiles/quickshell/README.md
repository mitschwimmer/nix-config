# Quickshell desktop

Home Manager installs the named `workstation` Quickshell configuration from this
directory. Niri starts it with `quickshell -c workstation`. It provides a
wallpaper, notification popups and an on-screen display, using the palette in
`Palette.qml`, with red (`#D71921`) reserved for small accents.

- `shell.qml`: composition root.
- `NiriState.qml`: shared Niri event stream, focused output and workspace state.
- `Wallpaper.qml`: existing per-output wallpaper rotation and effects.
- `Notifications.qml`: freedesktop notification server and popup state.
- `NotificationWindow.qml`: popup layout and per-monitor placement.
- `NotificationCard.qml`: individual notification and its action buttons.
- `Osd.qml`: PipeWire audio, MPRIS transport, brightness and IPC.
- `OsdWindow.qml`: visual on-screen display.
- `Palette.qml`: light/dark appearance synchronized with the desktop setting.
- `Polkit.qml`: system authentication agent.
- `PolkitDialog.qml`: authentication window and PAM responses.

Notifications and the OSD appear on the focused monitor, or the first monitor
until Niri reports one. No permanent bar or notification history is kept.

## Appearance and authentication

`Mod+Shift+T` switches light/dark mode and updates the GNOME color-scheme
setting used by GTK applications. The shell follows changes to the setting
made by other tools. The same switch is exposed through Quickshell IPC:

```sh
qs -c workstation ipc call theme toggle
qs -c workstation ipc call theme light
qs -c workstation ipc call theme dark
```

The built-in Polkit agent presents requests in a standard floating window.
It displays the requesting action, supports multiple PAM conversation prompts
and selectable identities, and clears entered responses. Only one agent can
register in a graphical session; stop any separately started Polkit agent.

To test with a deliberately unprivileged command:

```sh
pkexec /run/current-system/sw/bin/id
```

Cancel the prompt once, then retry and authenticate. Also verify that wrong
passwords, keyboard focus and Enter-to-submit work.

The login display manager is still Ly; Quickshell runs inside the Niri session.

## Manual checks

After switching to the new NixOS generation, log out and back in so Niri
starts the new shell.

```sh
qs -c workstation ipc show
qs -c workstation ipc call osd volumeUp
qs -c workstation ipc call osd volumeMute
qs -c workstation ipc call osd micMute
qs -c workstation ipc call osd brightnessUp
qs -c workstation ipc call osd mediaPlayPause
nix shell nixpkgs#libnotify -c notify-send -a "Quickshell test" "Notification" "Popups should appear on the focused monitor"
```

Check keyboard volume, microphone, brightness and media keys, notification
actions and close buttons, multiple monitors, wallpaper dimming on occupied
workspaces, rotation and crossfades.

The lock screen and launcher remain Swaylock and Fuzzel.
