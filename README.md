# NixOS configuration

For targeted exploration and validation commands, start with [AGENTS.md](AGENTS.md).
Host installation and recovery procedures are in [meablack/README.md](meablack/README.md)
and [meawhite/README.md](meawhite/README.md); Talos operations are in
[meawhite/talos/README.md](meawhite/talos/README.md).

Every installed machine is composed through `mkHost` in `flake.nix`:

| Module | Purpose |
| --- | --- |
| `profiles/base.nix` | Nix settings, timezone, Bash/ble.sh, key-only SSH and terminal definitions |
| `users/henner.nix` | Henner's account, wheel membership, SSH keys and Home Manager integration |
| `home/henner/default.nix` | Shared shell, CLI packages, Git identities, Helix and tmux configuration |
| `profiles/workstation.nix` | Desktop system services, NetworkManager membership and desktop Home Manager imports |
| `home/henner/desktop.nix` | Graphical applications, desktop dotfiles and aliases |
| `<host>/configuration.nix` | Hardware, boot, networking and host workloads |

meablack and meawhite use the shared system and user modules. meatab and meanovo
additionally select the workstation profile. Secure Boot
variants inherit the complete installed-host configuration. Installer live
systems remain separate and include the composed target system for offline use.

Add settings needed everywhere to the baseline or shared Home Manager modules.
Add graphical settings to the workstation/desktop modules. Keep workload tools
and services in their host configuration. Unstable Home Manager packages are
passed only to the workstation configuration.

## Account migration

Henner's shared public keys are in `users/henner/authorized_keys`, initially
copied from the identical reviewed server key files. These keys now allow
`ssh henner@<host>` on every installed machine. Existing workstation passwords
and mutable authorized keys are retained; the server-specific root key files
continue to provide key-only root access.

New server accounts have no initial password. After deploying, use the existing
root access to run `passwd henner` on each server, then verify Henner's SSH login
and `sudo -v` before retiring any root access. SSH password authentication stays
disabled; the password is for local authentication and sudo. Sudo continues to
require a password. No password or password hash is committed here.

Home Manager backs up conflicting unmanaged files with the `.hm-backup` suffix.
Inspect existing files and backups before the first server activation; resolve
any pre-existing backup collision before retrying activation. System and Home
Manager state versions retain their existing values.

## Terminal

Foot replaces Ghostty on workstations. Niri's Mod+T opens a Foot
session. Home Manager configures tmux in `home/henner/tmux.nix` on all hosts.
Its prefix is Ctrl+B. After the
prefix, h/j/k/l selects a pane, s followed by h/j/k/l opens a pane in that
direction, c creates a new window, and n/p changes windows. Window and pane
indices begin at 1. Prefix ? shows tmux's built-in keybinding help, z zooms a
pane, and d detaches; `tmux attach` reconnects.

The status bar centers the tmux server's hostname and numbered windows as one
group, with the active window highlighted using rounded Powerline glyphs from
the terminal's Nerd Font. It follows the terminal's default foreground and
background colors, without a clock, date or plugin theme. Restart existing tmux servers after
deploying the prefix change; Home Manager's default Ctrl+B binding is only
initialized automatically when tmux starts.

Foot uses JetBrainsMono Nerd Font and Gruvbox. Ctrl+Shift+T switches between dark
and light palettes; Ctrl+plus/minus/0 adjusts or resets the font size.

## SSH

SSH accepts public keys only, limits authentication attempts and login grace
time, applies per-source penalties, and disables X11 forwarding. Root SSH login
is disabled by default. meablack and meawhite explicitly retain key-only root
access through their reviewed `authorized_keys` files for headless administration.
Henner's keys can be managed through the shared key file or
`users.users.henner.openssh.authorizedKeys`. Workstations also retain the existing
user `~/.ssh/authorized_keys` file; servers use their existing system-only
`AuthorizedKeysFile` setting.

The unattended offline installer images keep networking and SSH disabled.

The shared-defaults workflow evaluates all installed-machine profiles, checks the
shared account and workstation/server boundary with `tests/profiles.nix`, and
checks Foot's configuration using the pinned Nix package. Server build workflows
also run when shared profiles, user configuration or dotfiles change.
