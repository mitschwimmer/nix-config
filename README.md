# NixOS configuration

`base.nix` supplies tmux and key-only OpenSSH to every installed machine.
`common.nix` adds the workstation desktop and imports that baseline. The headless
meablack and meawhite configurations import the baseline directly; their Secure
Boot variants inherit it.

## Terminal

Foot replaces Ghostty on workstations. Niri's Mod+T opens Foot with a new tmux
session. Use Ctrl+A as the tmux prefix: c creates a window, n/p changes windows,
h/j/k/l selects panes, % splits horizontally, and " splits vertically. Prefix z
zooms a pane, d detaches, and `tmux attach` reconnects. Send a literal Ctrl+A with
prefix a.

Foot uses JetBrainsMono Nerd Font and Gruvbox. Ctrl+Shift+T switches between dark
and light palettes; Ctrl+plus/minus/0 adjusts or resets the font size.

## SSH

SSH accepts public keys only, limits authentication attempts and login grace
time, applies per-source penalties, and disables X11 forwarding. Root SSH login
is disabled by default. meablack and meawhite explicitly retain key-only root
access through their reviewed `authorized_keys` files for headless administration.
Workstation keys can be managed through `users.users.henner.openssh.authorizedKeys`
or the existing user `~/.ssh/authorized_keys` file.

The unattended offline installer images keep networking and SSH disabled.

The shared-defaults workflow evaluates all installed-machine profiles and checks
Foot's configuration using the pinned Nix package.
