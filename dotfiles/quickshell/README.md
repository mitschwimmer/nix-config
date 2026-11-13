# Quickshell desktop

Home Manager installs the named `workstation` Quickshell configuration from this
directory. Niri starts it with `quickshell -c workstation`. It provides a
wallpaper, an application launcher, an edge-revealed status drawer, notification
popups and an on-screen display, using the palette in `Palette.qml`, with red
(`#D71921`) reserved for small accents.

- `shell.qml`: composition root.
- `NiriState.qml`: shared Niri event stream, focused output and workspace state.
- `Launcher.qml`: application index, search, selection and launcher IPC.
- `LauncherLogic.js`: GUI entry filtering and search ranking.
- `LauncherWindow.qml`: compact search panel, grayscale icons and blurred backdrop.
- `Wallpaper.qml`: existing per-output wallpaper rotation and effects.
- `Sidebar.qml`: edge sensors, reveal state, timing and shared wallpaper offset.
- `SidebarWindow.qml`: sliding status drawer on the selected output.
- `DesktopStatus.qml`: native UPower, NetworkManager and Bluetooth status.
- `AudioState.qml`: PipeWire devices, system defaults, output volume and mute.
- `SidebarAudio.qml`: inline device selectors and mouse volume controls.
- `SidebarSession.qml`: confirmed logout, restart and power-off controls.
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

## Application launcher

`Mod+D` toggles a 448 logical-pixel-wide launcher on the focused monitor (or the
first monitor until Niri reports one). It closes the status drawer and focuses
search immediately. Up/Down selects a result, Enter launches, and Escape,
`Mod+D` or clicking the backdrop closes it. Click a row to launch directly;
scroll to browse beyond the six visible rows. Closing clears the search.
Monitor hotplug closes the launcher and releases keyboard focus.

The panel uses `Palette.qml` in both appearances, with normal letter spacing for
the title-case heading and fully desaturated 20-pixel application icons. Missing
icons fall back to the application's initial. Set `showIcons: false` on the
`Launcher` in `shell.qml` for an icon-free list.

Quickshell indexes desktop applications from the session's XDG data paths,
including exported Flatpak desktop files. Hidden/NoDisplay entries are omitted;
the launcher additionally excludes `Terminal=true` applications, so terminal
editors and TUIs do not appear. Terminal emulators remain eligible as GUI apps.
Incorrectly labelled entries can be excluded with `excludedIds` on `Launcher`,
using desktop IDs without the `.desktop` suffix. No shell-command mode or PATH
scan is provided. All query words must match the name, generic name or keywords;
exact names rank before prefixes, substrings and metadata. Empty searches sort
alphabetically. Launching uses the desktop entry's parsed command and working
directory through Quickshell's native `execute()`.

The full-output layer dims and requests native background blur only while open.
Niri's `quickshell-launcher` layer rule disables xray so the blur includes
application windows instead of showing only wallpaper. Non-xray blur is
experimental in Niri 26.04 and costs more than wallpaper-only blur. If it causes
artifacts or excessive GPU use, set `blur false` in that rule; the dimmed backdrop
continues to work. Other monitors are left unobscured.

```sh
qs -c workstation ipc call launcher toggle
qs -c workstation ipc call launcher open
qs -c workstation ipc call launcher close
node --test tests/launcher.test.cjs
```

After switching generations, verify light/dark appearance, grayscale and missing
icons, keyboard navigation through more than six results, scrolling, empty/no
matches, long names, and mouse launch/dismissal. Check that GUI apps launch with
the right working directory, Helix/TUIs stay absent, installing/removing desktop
apps updates the list, and both Escape and `Mod+D` return keyboard focus to the
previous application. Test each output at its configured scale, hotplug while
open, and blur over changing application content. Compare with `blur false` if
needed. These focus and compositor checks require a real Niri session.

## Status drawer

Rest the pointer against an exposed left or right monitor edge for 150 ms to
reveal a 280 logical-pixel drawer on that side. Shared monitor boundaries have
no sensors, including the shared portions of staggered layouts. The invisible
sensors occupy two logical pixels, reserve no desktop space and take no keyboard
focus. The drawer shows local date/time (without seconds), system battery charge
and time estimate, the connected Wi-Fi network and signal, and connected Bluetooth
devices. It also provides an appearance button, audio input/output selectors,
output volume and mute controls, and session actions for logout, restart and
power-off. Missing hardware and disabled radios have explicit fallback states.

The drawer and wallpaper share a 220 ms animation. Only the wallpaper translates;
application windows retain their size and position. Wallpaper rotation,
crossfades and occupied-workspace effects continue as before. The drawer uses the
existing light/dark palette, with a true-black (`#000000`) drawer background in
dark mode, and disappears completely when closed. Quickshell exposes battery
charge as a 0–1 ratio; the displayed percentage multiplies it by 100 once.

Leaving the drawer closes it after 350 ms. A stationary pointer also closes it
after 15 seconds; a pointer parked on the trigger must leave the edge before
it can reveal the drawer again. Monitor layout changes close the drawer and
rebuild the edge sensors. Timing and width are defined at the top of `Sidebar.qml`.
UPower and BlueZ are enabled in the workstation profile; NetworkManager is already
enabled. Quickshell 0.3.2 from the pinned unstable input provides the native networking API.

### Session controls

The bottom of the scrollable drawer offers **Log out**, **Restart** and
**Power off**. Each asks for confirmation and warns about unsaved work. Cancel,
closing the drawer or changing the monitor layout clears the pending action.
Logout invokes `niri msg action quit --skip-confirmation` after the drawer's
confirmation; restart and shutdown invoke `systemctl reboot` and
`systemctl poweroff` through the active logind session. No shell or
elevated privileges are involved.

### Audio controls

Click the current output or input to expand its device list; click a device to
make it the system default. A small red dot marks the active default. Lists stay
inside the drawer’s scrollable area and close when the drawer is dismissed.
Only audio devices are listed, excluding application streams. Unavailable devices
disappear on disconnect and the selection follows PipeWire’s fallback.

The slider adjusts the current default output from 0–100%; increasing it above
zero unmutes that output. The separate Mute/Unmute button preserves its level.
Volume, mute and selection follow external changes, including the media keys.
The sidebar and OSD both use Quickshell’s native PipeWire state.

Device selection writes PipeWire’s preferred default, the same system choice as
pavucontrol’s “Set as fallback” in Output Devices / Input Devices. Changing that
choice in either tool updates the drawer. Per-application routing and hardware
profiles/ports remain available in pavucontrol; an explicitly routed application
may retain its own device rather than follow the default.

## Appearance and authentication

The drawer’s “Light mode” / “Dark mode” button switches appearance and updates
the GNOME color-scheme setting used by GTK applications. It replaces the former
`Mod+Shift+T` binding. The shell follows changes to the setting
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

## Wallpaper corners

The wallpaper has a 16 logical-pixel corner radius on every output, independent
of workspace occupancy or drawer visibility. The rounded alpha mask is applied
by the existing MultiEffect, so blur, saturation, crossfades and the sidebar's
wallpaper translation still work. The black wallpaper window shows through in
the clipped corners.

## Wallpaper loading errors

If the selected wallpaper fails to load, a small message at the bottom left
shows its filename using the shell's shared font and light/dark palette. The
message remains readable above the wallpaper's blur and dimming effects and
does not consume pointer input.

Only the selected image can show an error message. A failed preload remains
silent until that image is selected; selecting a working image clears the
message. Long filenames wrap so the complete name stays visible.

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
Check the session actions with Cancel and by closing the drawer while confirming;
only confirm logout, restart or power-off when it is safe to end the session.
Check the wallpaper's rounded corners across outputs and during drawer animation,
rotation, crossfades and occupied-workspace effects.
Check the appearance button in both modes and confirm GTK applications and
external dconf changes stay synchronized. Confirm `Mod+Shift+T` no longer changes
the theme. For audio, select outputs and inputs in the drawer, then use
pavucontrol’s “Set as fallback” for each direction and verify the selected row
follows. Test slider click/drag, mute/unmute, media-key and pavucontrol volume
updates, output switching while muted, device disconnect/reconnect, and a session
with no audio devices. Verify new playback/recording uses the chosen defaults;
check application-specific routes separately in pavucontrol. Expand long device
lists and scroll on a short output, checking that controls remain clickable and
the drawer does not close during interaction.

Check battery charging/unplugging, absent battery, Wi-Fi reconnect/rfkill, Bluetooth
connect/disconnect, light/dark mode and a midnight date change. Layer-shell input
and animation behavior require testing in the real Niri session.

The exposed-edge and battery-formatting regression checks run without a desktop:

```sh
nix shell nixpkgs#nodejs -c node --test tests/sidebar.test.cjs
```

The separate [Quickshell lock screen](../quickshell-lock/README.md) shares the
dot-matrix clock and visual style. It uses a solid black background and serves
as the sole screen locker.
