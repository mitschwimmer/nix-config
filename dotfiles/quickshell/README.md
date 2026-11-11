# Quickshell desktop

Home Manager installs the named `workstation` Quickshell configuration from this
directory. Niri starts it with `quickshell -c workstation`. It provides a
wallpaper, an edge-revealed status drawer, notification popups and an on-screen
display, using the palette in `Palette.qml`, with red (`#D71921`) reserved for small accents.

- `shell.qml`: composition root.
- `NiriState.qml`: shared Niri event stream, focused output and workspace state.
- `Wallpaper.qml`: existing per-output wallpaper rotation and effects.
- `Sidebar.qml`: edge sensors, reveal state, timing and shared wallpaper offset.
- `SidebarWindow.qml`: sliding status drawer on the selected output.
- `DesktopStatus.qml`: native UPower, NetworkManager and Bluetooth status.
- `DotClock.qml`: font-independent dot-matrix clock.
- `SidebarLogic.js`: exposed monitor edges and battery estimate formatting.
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

## Status drawer

Rest the pointer against an exposed left or right monitor edge for 150 ms to
reveal a 280 logical-pixel drawer on that side. Shared monitor boundaries have
no sensors, including the shared portions of staggered layouts. The invisible
sensors occupy two logical pixels, reserve no desktop space and take no keyboard
focus. The drawer shows local date/time (without seconds), system battery charge
and time estimate, the connected Wi-Fi network and signal, and connected Bluetooth
devices. Missing hardware and disabled radios have explicit fallback states.

The drawer and wallpaper share a 220 ms animation. Only the wallpaper translates;
application windows retain their size and position. Wallpaper rotation,
crossfades and occupied-workspace effects continue as before. The drawer uses the
existing light/dark palette and disappears completely when closed.

Leaving the drawer closes it after 350 ms. A stationary pointer also closes it
after 15 seconds; a pointer parked on the trigger must leave the edge before
it can reveal the drawer again. Monitor layout changes close the drawer and
rebuild the edge sensors. Timing and width are defined at the top of `Sidebar.qml`.
UPower and BlueZ are enabled in the workstation profile; NetworkManager is already
enabled. Quickshell 0.3.0 from the pinned Nixpkgs provides the native networking API.

## Appearance and authentication

`Mod+Shift+T` switches light/dark mode and updates the GNOME color-scheme
setting used by GTK applications. The shell follows changes to the setting
made by other tools. The same switch is exposed through Quickshell IPC:

```sh
qs -c workstation ipc call theme toggle
qs -c workstation ipc call theme light
qs -c workstation ipc call theme dark
```

The built-in Polkit agent presents requests in a compact, content-sized
floating window, matched by title in Niri's window rules. It retains the
full authorization reason and muted action ID, supports multiple PAM prompts
and selectable identities, and clears entered responses. Passwords use spaced
square mask characters. Only one agent can register in a graphical session;
stop any separately started Polkit agent.

To test with a deliberately unprivileged command:

```sh
pkexec /run/current-system/sw/bin/id
```

Cancel the prompt once, then retry and authenticate. Also verify that wrong
passwords, keyboard focus and Enter-to-submit work.

SDDM uses the separate, Qt 6-only `dotfiles/sddm/workstation/` greeter theme,
which mirrors the Polkit dialog's palette and layout. Quickshell itself runs
only inside the Niri session.

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

For the drawer, check both edges, entering/leaving during animation, crossing
monitor seams, staggered/fractionally scaled outputs, unplugging an output while
open, scrolling on a short output, long network/device names, and the 15-second
stationary-pointer timeout both inside the drawer and directly on the edge.
Verify the wallpaper returns exactly to its original position, applications
receive input outside the drawer and keyboard focus stays on the application.
Check battery charging/unplugging, absent battery, Wi-Fi reconnect/rfkill, Bluetooth
connect/disconnect, light/dark mode and a midnight date change. Layer-shell input
and animation behavior require testing in the real Niri session.

The exposed-edge and battery-formatting regression checks run without a desktop:

```sh
nix shell nixpkgs#nodejs -c node --test tests/sidebar.test.cjs
```

The lock screen and launcher remain Swaylock and Fuzzel.
