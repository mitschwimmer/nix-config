# Workstation lock screen

`workstation-lock` starts a separate Quickshell 0.3.2 process from the existing
pinned NixOS unstable input. SDDM continues to handle login. The ordinary desktop
shell can restart without taking the locker with it.

The lock screen uses the desktop's `DotClock.qml`, JetBrains Mono, white text,
square password masks and restrained red accents. Each output shows a blurred,
dimmed snapshot of its desktop taken immediately before locking, including open
windows. The snapshot is frozen: the actual desktop is neither transparent nor
interactive behind the lock. Newly connected outputs and failed captures use
opaque black. The image is only rendered through the blur effect.

Snapshots are captured concurrently at half resolution with a shared one-second
deadline. They exist only inside a mode-0700 directory in `$XDG_RUNTIME_DIR`;
systemd removes the directory on unlock, crash or startup timeout. They are not
written to the home directory or screenshot history.

`WlSessionLock` covers every output. Only `PamResult.Success` from the dedicated
NixOS `quickshell-lock` PAM service releases the lock. Escape clears the field;
it does not dismiss the lock. Wrong passwords clear all fields and start a fresh
PAM conversation after a short delay. PAM errors keep the screen locked.

## Entry points and recovery

- `Super+L` or `workstation-lock`: start the locker and wait until the compositor
  confirms coverage. Repeated requests share the same systemd service.
- `loginctl lock-session`: handled by Swayidle using the same entry point.
- Suspend: Swayidle's `-w` before-sleep hook waits for that acknowledgement.
  Logind's delay-inhibitor budget is 15 seconds; Quickshell startup is bounded
  to five seconds, followed by a bounded emergency Swaylock start.
- `Super+Alt+L`: start the emergency Swaylock service, including while locked.
  This can recover Niri's solid-color screen after a dead locker. A running
  healthy locker keeps ownership of the lock.

Startup failure and crashes trigger `workstation-lock-fallback.service` through
systemd `OnFailure`. Swaylock stays installed with an explicit PAM service. There
is no automatic idle timeout, automatic suspend or unauthenticated unlock IPC.

## Validation

```sh
python3 -m unittest discover -s tests -p 'lock*_test.py'
nix eval --no-update-lock-file --raw .#nixosConfigurations.meanovo.config.system.build.toplevel.drvPath
nix eval --no-update-lock-file --raw .#nixosConfigurations.meatab.config.system.build.toplevel.drvPath
nix eval --no-update-lock-file --impure --json --expr '
  let flake = builtins.getFlake (toString ./.);
  in import ./tests/profiles.nix { inherit (flake) nixosConfigurations; }
'
```

After deploying a generation, log out/in to start Swayidle with the new session.
Keep TTY/SSH access for the first real-session checks. Verify:

- Successful and wrong passwords, rapid Enter, Escape, retry after PAM failure,
  and password clearing across multiple displays.
- Per-output snapshots, fractional scales, short outputs, monitor hotplug while
  locked, and black backgrounds when capture is unavailable.
- Repeated manual locks, `loginctl lock-session`, lid-close/suspend/resume, and
  suspend immediately after requesting a lock.
- With the session locked, kill the locker main process with
  `systemctl --user kill --signal=SIGKILL --kill-whom=main workstation-lock.service`.
  Confirm the desktop stays inaccessible and Swaylock takes over. Test the
  emergency binding as well. Never use a plain service stop as an unlock action.
- Restart the ordinary `workstation` Quickshell process while locked and confirm
  the separate locker remains usable.

Unit tests do not establish PAM, compositor or suspend correctness; these checks
require the physical Niri session.
