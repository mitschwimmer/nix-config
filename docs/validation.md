# Validation record

## Repository checks, 2026-11-09

- `git diff --check` and workflow YAML parsing passed.
- All six guest runner derivations evaluated against the locked NixOS 26.05
  and microvm.nix inputs.
- meablack, meawhite and both Secure Boot variants evaluated successfully.
- Shared account/desktop profile checks passed for all six installed-host
  configurations, including the two Secure Boot variants.
- Topology, unique MACs, TAP lengths, persistent state, SSH key location,
  host placement and opt-in/no-mass-restart checks passed. Enabled-host
  fixture derivations also evaluated; a concurrent repeat of the aggregate
  evaluation was killed, so the final configuration checks ran separately.
- The local test-guest build failed during build-environment setup: this
  environment's relocated Nix store could not resolve an absolute `/nix/store`
  symlink for the `getty` input. This is not a successful image build.
  The normal-store CI build remains required.

## Foundation acceptance on the physical hosts

No remote deployment has been performed. LAN access from the implementation
environment is unavailable. Complete these checks and record observations
before moving to K3s; [bootstrap.md](bootstrap.md) contains the commands.

| Check | Status |
| --- | --- |
| Cloud Hypervisor guest builds | Local relocated-store build blocked; CI build required |
| meawhite k8s-test boots with KVM | Pending on host |
| DHCP lease, LAN DNS and time synchronization | Pending on LAN |
| Host TAP attached to br0 | Pending on host |
| Persistent marker/SSH key/machine ID survive restart | Pending on host |
| Same state survives guest rebuild and selective restart | Pending on host |
| Guest autostarts with same state after host reboot | Pending on host |
| meablack NIC/MAC observed and bridge tested with rollback | Pending on host |
| K3s, etcd, VIP failover, Cilium, OpenEBS and snapshots | Not implemented |

Evaluation checks are tracked separately from boot/build results. The workflow
`.github/workflows/microvms.yml` evaluates default hosts, enabled-host fixtures,
all guest runners and builds the test guest. Fixtures use a fake NIC/MAC only
to exercise meablack's bridge configuration; they are never deployment values.
