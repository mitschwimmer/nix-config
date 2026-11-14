# NixOS configuration

For targeted exploration and validation commands, start with [AGENTS.md](AGENTS.md).
Host installation and recovery procedures are in [meablack/README.md](meablack/README.md),
[meawhite/README.md](meawhite/README.md), and the staged workstation
[meanovo boot runbook](meanovo/README.md). The Kubernetes MicroVM foundation
and implementation status are in [docs/architecture.md](docs/architecture.md);
start deployment with [docs/bootstrap.md](docs/bootstrap.md).

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
additionally select the workstation profile. Server Secure Boot variants inherit
the installed-host configuration. On the laptop, `meanovo` uses Lanzaboote,
Secure Boot and TPM2 unlock by default; `meanovo-secure` remains an alias,
while `meanovo-legacy` is an unsigned recovery-only target that requires
disabling firmware Secure Boot before booting. Installer live systems remain
separate and include the composed target system for offline use.

Add settings needed everywhere to the baseline or shared Home Manager modules.
Add graphical settings to the workstation/desktop modules. Keep workload tools
and services in their host configuration. Unstable Home Manager packages are
passed only to the workstation configuration.

## Workstation login

The workstation profile uses SDDM (Wayland greeter via Weston) for both
`meanovo` and `meatab`. Niri remains the default session, and automatic
login is disabled. The SDDM Wayland greeter is still experimental upstream.
The login theme echoes the Quickshell Polkit dialog's typography and red
accent, using pure OLED black, an unframed left-of-center login, and understated
field underlines. Its source is in `dotfiles/sddm/workstation/`; see that
directory's README for testing and recovery.

Before activating, verify the `henner` account password works for a local
login and that another TTY (Ctrl+Alt+F2 or F3) and SSH recovery are available.
Evaluate each workstation before deployment:

```sh
nix eval --no-update-lock-file --raw .#nixosConfigurations.meanovo.config.system.build.toplevel.drvPath
nix eval --no-update-lock-file --raw .#nixosConfigurations.meatab.config.system.build.toplevel.drvPath
```

Switch the display manager **at reboot**, not inside the running graphical
session. On `meanovo`, this command now uses the signed Secure Boot configuration
and requires the local `/var/lib/sbctl` signing keys. For the host being tested:

```sh
sudo nixos-rebuild boot --flake .#meanovo
sudo reboot
```

At the greeter, select Niri if needed, enter the existing account password,
and test logout/relogin. If the greeter fails, switch to a text TTY, inspect
`journalctl -b -u display-manager`, select the previous system generation
from the boot menu (hold Space while booting if the menu is hidden), or boot
a previous generation with `sudo nixos-rebuild boot --rollback` and reboot.
Only then migrate the second workstation.

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

Automatic CI currently runs syntax checks only: every tracked Nix file is parsed
with `nix-instantiate --parse`, Bash scripts with `bash -n`, and `flake.lock` as
JSON. It does not fetch flake inputs, evaluate NixOS options or build images.
Superseded syntax runs on the same branch are cancelled.

Deeper checks are retained as manual workflows:

- **Shared machine defaults (manual)** (`validation.yml`): evaluate installed
  hosts, check shared accounts and desktop boundaries, and validate Foot.
- **meablack NixOS build** / **meawhite NixOS build**: evaluate and build the
  server, Secure Boot variant and offline installer; check installer scripts.
- **MicroVM foundation**: evaluate topology, enabled-host fixtures and guest
  runners, then build the three control-plane guest images.

Once a workflow exists on `main`, use **Actions → Run workflow** and select the
branch to check. Newly added manual workflows become dispatchable after merging;
until then, use the equivalent local commands in AGENTS.md and docs/operations.md.
A green automatic check establishes syntax validity only; evaluation, image
builds and host acceptance remain separate requirements before deployment.
