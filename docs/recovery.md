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
- For the cp-02 staging expansion, encrypted off-host backup and restore
  verification were explicitly deferred on 2026-11-14. They are still
  outstanding; the deployment must not be described as recoverable or HA.
- With exactly two etcd voters, either member being unavailable loses quorum.
  Do not perform a failure/reboot test or remove a member casually. For a
  partial join, preserve the guest's state image and inspect K3s/etcd logs and
  membership before choosing recovery. Never use `cluster-reset` or delete
  etcd state as an automatic retry.
- Retired Talos images at `/var/lib/libvirt/talos` and `/data/talos`
  are separate legacy data. Do not delete or import them implicitly.

- Before cp-03 joins, a failed meablack bridge test can revert to its preserved
  host closure through the timed procedure in [operations.md](operations.md).
  The timer is runtime-only and needs a functioning host; it is not a network
  recovery guarantee or an etcd backup. Use console if reconnection fails.
- Once cp-03 joins, host-network rollback may also stop that etcd member.
  It does not undo cluster membership or restore its datastore. Check health
  and quorum first; preserve the guest image and use a reviewed recovery plan.
