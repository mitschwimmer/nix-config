# Recovery boundaries

- Preserve `/var/lib/microvms/<guest>/state.img`; removing it destroys
  that guest's persistent K3s and SSH state. A NixOS rollback does not restore
  its contents. Never mount a running guest's image read-write on the host.
- When boot or SSH fails, inspect `journalctl -b -u microvm@<guest>`, the
  runner's `current` and `booted` links, host disk space, TAP/bridge and
  the guest's DHCP lease. Use the saved runner root in [operations.md](operations.md).
- For a failed host bridge change, restore the previous NixOS generation
  through console or a timed rollback. Do not run installation/disko scripts.
- Secure an encrypted off-host K3s server token, etcd snapshots and future
  SOPS/age keys. Test restore before claiming durability; local snapshots do
  not protect against physical-host loss.
- Retired Talos images at `/var/lib/libvirt/talos` and `/data/talos`
  are separate legacy data. Do not delete or import them implicitly.
