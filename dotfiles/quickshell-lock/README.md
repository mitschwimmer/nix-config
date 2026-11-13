# Workstation lock screen

`workstation-lock` starts a separate Quickshell 0.3.2 process using the pinned
unstable input. It shares the desktop's `DotClock.qml`, JetBrains Mono, square
password masks and red accents, but renders on an opaque black background.
SDDM continues to handle login. Restarting the desktop shell does not affect
the locker.

`WlSessionLock` covers every output using the Wayland session-lock protocol.
Only `PamResult.Success` from the dedicated NixOS `quickshell-lock` PAM service
releases the lock. Escape clears the field; it never unlocks. Wrong passwords
clear all fields and restart the PAM conversation after a short delay. PAM
errors keep the session locked. There is no unauthenticated unlock IPC.

## Entry points and recovery

- `Super+Alt+L` or `workstation-lock`: start the locker and wait for Niri to
  confirm coverage. Repeated requests share one systemd service. The shortcut
  works while locked, to recover from a crashed locker. `Mod+L` remains
  available for window navigation.
- `loginctl lock-session`: Swayidle uses the same entry point.
- Suspend: Swayidle's `-w` before-sleep hook waits for lock acknowledgement.
  Logind's delay-inhibitor budget is 10 seconds; startup is bounded to
  five seconds, with two seconds for cleanup on failure.

Quickshell is the sole locker. Failed startup reports failure and leaves the
session unlocked. If Quickshell crashes after locking, Niri keeps the screen
locked on its solid-color background. Retry `Super+Alt+L`, or switch to
another TTY with `Ctrl+Alt+F3`, log in as the same user, and run:

```sh
systemctl --user restart workstation-lock.service
```

Then return to the graphical TTY. Diagnose failures with
`journalctl --user -u workstation-lock.service`. There is no alternate
locker, automatic restart or idle timeout.

## Validation

```sh
niri validate --config dotfiles/niri/config.kdl
nix eval --no-update-lock-file --raw .#nixosConfigurations.meanovo.config.system.build.toplevel.drvPath
nix eval --no-update-lock-file --raw .#nixosConfigurations.meatab.config.system.build.toplevel.drvPath
nix eval --no-update-lock-file --impure --json --expr '
  let flake = builtins.getFlake (toString ./.);
  in import ./tests/profiles.nix { inherit (flake) nixosConfigurations; }
'
```

After deploying a generation, log out/in to restart Swayidle. Keep TTY/SSH
access for the first real-session checks. Verify:

- Successful and wrong passwords, rapid Enter, Escape, retry after PAM
  failure, and field clearing across displays.
- Different output sizes, fractional scaling, monitor hotplug while locked
  and black backgrounds on every output.
- Repeated manual locks, `loginctl lock-session`, suspend/resume and
  suspend immediately after requesting a lock.
- With the session locked, kill Quickshell using
  `systemctl --user kill --signal=SIGKILL --kill-whom=main workstation-lock.service`.
  Confirm the desktop stays inaccessible; recover via `Super+Alt+L` or a TTY.
- Restart the ordinary `workstation` Quickshell process while locked and
  confirm the standalone locker remains usable.
- Verify `systemctl --user show-environment` includes `WAYLAND_DISPLAY`.

PAM, compositor and suspend correctness require a physical Niri session.
