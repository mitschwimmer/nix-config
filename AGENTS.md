# Working on this configuration

## Explore progressively

Start here, then read only the row relevant to the task. `flake.nix` is the
composition root: `mkHost` adds base, account and Home Manager modules to every
installed host. Desktop support is explicitly selected for meatab and meanovo.
All outputs target x86_64-linux.

| Task | Read first | Follow only as needed |
| --- | --- | --- |
| Host composition or inputs | `flake.nix` | Selected host's `configuration.nix`, `flake.lock` only for dependency work |
| Shared NixOS defaults or SSH | `profiles/base.nix` | `users/henner.nix`, selected host's overrides |
| Desktop system services, VPN or login | `profiles/workstation.nix` | `home/henner/desktop.nix` |
| meanovo Secure Boot, TPM or boot display modes | `meanovo/README.md` | `flake.nix`, `meanovo/secure-boot.nix`, `meanovo/hardware-configuration.nix` |
| Account or shared SSH keys | `users/henner.nix` | `users/henner/authorized_keys` |
| CLI tools, Git or Helix | `home/henner/cli.nix` | Referenced files in `dotfiles/` |
| Bash, ble.sh or shell integration | `home/henner/shell.nix` | `profiles/base.nix` for system Bash |
| tmux | `home/henner/tmux.nix` | README's Terminal section |
| Graphical apps or desktop dotfiles | `home/henner/desktop.nix` | Only the relevant app directory in `dotfiles/` |
| Server hardware, storage or installation | `<host>/configuration.nix` | Host-local `disko.nix`, `installer.nix`, referenced scripts; runbook section in `<host>/README.md` |
| MicroVM hosts or bridge | `<host>/microvms.nix` | `profiles/microvm-host.nix`, `docs/bootstrap.md` |
| Kubernetes guest identity, resources or storage | `kubernetes/nodes.nix` | `kubernetes/guest.nix`, `docs/architecture.md`, `docs/operations.md` |
| Shared profile expectations | `tests/profiles.nix` | `.github/workflows/validation.yml` |

Use `rg --files` to locate files and `rg -n 'pattern' <relevant-paths>` to locate
settings. For runbooks, list headings first with `rg -n '^##' <file>`, then read
the relevant section. Avoid reading every host, dotfile or runbook for one task.
For a host removal, search the entire tracked tree, including workflows, with
`git grep -n -E 'host-a|host-b'` and inspect peripheral settings before deleting.

## Change boundaries

- Keep shared system settings in profiles, user preferences in Home Manager,
  native app configuration in dotfiles, and workloads beside their host.
- Keep imports explicit. Introduce another module when it isolates a coherent
  task; avoid automatic directory imports and one-option wrapper modules.
- For Quickshell QML, separate state/services from windows and visual components.
  Pass dependencies through required properties; prefer shallow, cohesive
  components over deep nesting or trivial wrapper files.
- Preserve system and Home Manager state versions during unrelated changes.
- Server Secure Boot variants extend installed hosts; the laptop's
  `meanovo` target is already secure by default, `meanovo-secure` aliases it,
  and `meanovo-legacy` is explicitly unsigned recovery only. Installer live
  systems are separate; installer builds require a recovery file and
  intentionally use `--impure`. Read the host runbook before recovery.
- Update the relevant routing row when moving an entry point. Keep operational
  procedures in their existing runbooks rather than copying them here.

## Validate in increasing cost

Run from the repository root. Stage new Nix files before flake evaluation so
Git-backed flake sources include them. Inspect `git diff --check` first.
Automatic CI in `.github/workflows/defaults.yml` checks syntax only; deeper
workflows are manual (see README). Parse Nix with `nix-instantiate --parse`,
check Bash with `bash -n`, and validate `flake.lock` with `python3 -m json.tool`.

For each affected installed host (also its `-secure` variant for server changes):

```sh
nix eval --no-update-lock-file --raw .#nixosConfigurations.meanovo.config.system.build.toplevel.drvPath
```

For shared profiles, users or Home Manager changes:

```sh
nix eval --no-update-lock-file --impure --json --expr '
  let flake = builtins.getFlake (toString ./.);
  in import ./tests/profiles.nix { inherit (flake) nixosConfigurations; }
'
```

For installer scripts, use `bash -n`, ShellCheck, and the host's mock disk tests:
`python3 meablack/test-select-disk.py` or `bash meawhite/test-check-disks.sh`.
For Foot, use the pinned-package check in `.github/workflows/validation.yml`.
For MicroVMs, evaluate `tests/microvms.nix` as described in
`docs/operations.md`, then evaluate each guest's `config.microvm.declaredRunner.drvPath`.
The manual microvms workflow also builds the k8s-cp-01 runner. LAN, K3s API,
persistence and host-reboot acceptance must be checked on the real guest before
joining additional cluster nodes.

Use `.github/workflows/<host>.yml` for full server and installer builds.
Evaluation does not establish build or runtime success. Report which checks ran
and any unavailable checks; do not deploy or execute installer scripts as tests.
