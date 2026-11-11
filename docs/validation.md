# Validation status

- The 2026-11-09 foundation evaluation used an earlier lock file; it is not
  validation of the current K3s bootstrap. A prior image build was blocked
  by a relocated Nix store, not by a demonstrated guest build failure.
- GitHub's automatic CI checks syntax only. Manual MicroVM CI and the local
  `nix eval` / `nix build` commands in [bootstrap.md](bootstrap.md)
  must pass against the current lock.
- No physical-host deployment or runtime acceptance has been reported.
  Verify KVM/bridge/DHCP, guest persistence across restart, K3s API/etcd,
  server-token custody and recovery before joining more nodes.
- meablack's actual wired NIC/MAC and safe bridge activation remain pending.
  Joiners, API VIP/Keepalived, Cilium and OpenEBS are not implemented.
