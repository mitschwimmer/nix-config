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
  The normal-store build remains required; run the MicroVM foundation workflow
  manually once it is registered on main (or build locally).

## Foundation acceptance on the physical hosts

No remote deployment has been performed. LAN access from the implementation
environment is unavailable. Complete these checks and record observations
before moving to K3s; [bootstrap.md](bootstrap.md) contains the commands.

| Check | Status |
| --- | --- |
| Cloud Hypervisor guest builds | Local relocated-store build blocked; manual CI build required |
| meawhite k8s-test boots with KVM | Pending on host |
| DHCP lease, LAN DNS and time synchronization | Pending on LAN |
| Host TAP attached to br0 | Pending on host |
| Persistent marker/SSH key/machine ID survive restart | Pending on host |
| Same state survives guest rebuild and selective restart | Pending on host |
| Guest autostarts with same state after host reboot | Pending on host |
| meablack NIC/MAC observed and bridge tested with rollback | Pending on host |
| K3s on k8s-cp-01 and etcd | Declaratively configured; not built, deployed or runtime-tested |
| Remaining K3s joins, VIP, Cilium, OpenEBS and snapshots | Not implemented |

Evaluation checks are tracked separately from boot/build results. The workflow
`.github/workflows/microvms.yml` is manually dispatched and evaluates default hosts, enabled-host fixtures,
all guest runners and builds the test guest. Fixtures use a fake NIC/MAC only
to exercise meablack's bridge configuration; they are never deployment values.

## CI policy and main integration, 2026-11-11

The PR incorporates main's dependency updates, ble.sh multiline navigation fixes
and Ly logging change. The earlier evaluation results above apply to the old
lock file; they have not been repeated against the updated dependencies.

Automatic CI now checks Nix/Bash syntax and lock-file JSON only. Full evaluation
and image builds are available through manual workflows as described in the
root README. Passing syntax checks does not establish foundation build or runtime
acceptance. Repeat the manual evaluation/build checks with the updated lock file
before deployment.

## Initial K3s bootstrap PR, 2026-11-11

- Changed the first deployment target to `k8s-cp-01` on meawhite, using the
  Secure Boot `meawhite-secure` flake output. The operator elected to skip
  `k8s-test`; no real-guest runtime acceptance has been recorded.
- Added K3s embedded-etcd bootstrap with initial token generation on the guest,
  persistent node-password link and firewall openings for the first server.
  Further nodes remain disabled until secure join token delivery exists.
- The updated repository tests assert the one active guest, K3s bootstrap
  settings and persistent node-password linkage, as well as unique vsock CIDs.
- Validation by actual `nix eval`, `nix build` and physical-host checks is
  **pending**. Do not interpret GitHub syntax CI as a completed deployment.
