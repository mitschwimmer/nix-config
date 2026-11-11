# MicroVM foundation recovery

## Guest fails to boot

Use `journalctl -u microvm@<guest> -b` on its host. Check free space under
`/var/lib/microvms`, the state image and the `current` and `booted` runner
targets. Follow the single-guest runner rollback in [operations.md](operations.md).
Preserve its image; deleting it creates an empty replacement at the next start.

If SSH fails, inspect the DHCP lease by the guest's MAC and the TAP's bridge
attachment. Review the serial console in the systemd journal. Do not change
MAC or hostname to work around a missing lease: both are persistent identities.

## Host network change fails

Recover through the prepared console/timed rollback and the previous host
generation. Restore the previous bridge/NIC DHCP ownership before retrying.
Host disk installation and Secure Boot recovery remain in each host's README.
Do not run installer or disko scripts to repair a VM networking problem.

## State and secret recovery boundary

The Nix image reconstructs the OS. It does not reconstruct `/var`, private
SSH keys or future Kubernetes state. A NixOS generation rollback changes the
software and configuration, not the raw disk's contents.

K3s/etcd recovery is not implemented in phase 1. Before cluster deployment,
document secure custody of the K3s server token (needed to decrypt bootstrap
data during snapshot restores), the sops age identity/recipients, and manual
etcd snapshot verification. Never embed those secrets in the Nix store.
Before phase-2 acceptance, test a failed server update recovery using a
matching K3s version, token and known snapshot. CSI snapshots are local storage
features and do not by themselves provide off-host recovery.

The former Talos raw state is not imported by these guests. Its qcow2 files
remain at `/var/lib/libvirt/talos` and `/data/talos`. Recovery of that former
VM requires its original private configuration and a reviewed pre-retirement
repository revision. No action in this implementation deletes those files.
