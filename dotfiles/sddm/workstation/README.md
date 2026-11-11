# Workstation SDDM theme

Qt 6 / Qt Quick theme for the existing Weston-based SDDM greeter.

The theme takes the Polkit dialog's typography and restrained red accent
(`dotfiles/quickshell/PolkitDialog.qml` and `Palette.qml`) into an
unframed, typography-first login on a **pure black** (`#000000`) OLED
background. There is no wallpaper, card, border or filled button. A
left-of-center layout, oversized heading, generous vertical spacing and
thin underlines give the login screen its structure.

No Quickshell service is needed at login. The SDDM greeter has its own process,
session models and authentication API.

The username is editable, initialized from SDDM's last user. Passwords are
cleared on submission and failures. Session selection is available when SDDM
offers more than one session. Restart and shutdown buttons use SDDM's own API.

Preview with the SDDM Qt 6 greeter:

```sh
sddm-greeter-qt6 --test-mode --theme "$PWD/dotfiles/sddm/workstation"
```

Test mode opens a preview without changing the active display manager,
and login/reboot controls do not perform real actions. A full greeter test
requires deploying a NixOS generation.

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
