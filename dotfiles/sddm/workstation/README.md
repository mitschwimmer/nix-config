# Workstation SDDM theme

Pure Qt 6 / Qt Quick theme for the existing Weston-based SDDM greeter.
The card follows `dotfiles/quickshell/PolkitDialog.qml` and
`dotfiles/quickshell/Palette.qml`: near-black, muted gray borders,
JetBrainsMono Nerd Font, red accent, uppercase labels, square password masks.

No Quickshell service is needed at login. The SDDM greeter has its own process,
session models and authentication API.

The username is editable, initialized from SDDM's last user. Passwords are
cleared on submission and failures. Session selection is available when SDDM
offers more than one session. Restart and shutdown buttons use SDDM's own API.

Preview with a test-capable SDDM Qt 6 greeter, if available:

```sh
sddm-greeter-qt6 --test --theme "$PWD/dotfiles/sddm/workstation"
```

Before activating on a physical machine:

```sh
nix eval --no-update-lock-file --raw .#nixosConfigurations.meanovo.config.system.build.toplevel.drvPath
sudo nixos-rebuild boot --flake .#meanovo
sudo reboot
```

Test successful login, wrong password retry, empty username, session choice
(if present), and keyboard focus/Enter on the real greeter. Keep TTY/SSH
access and a known-good signed generation for recovery. Do not test a new
display manager theme with `nixos-rebuild switch` from the running session.
