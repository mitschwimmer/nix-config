# Backup backlog for a fresh homelab rebuild

This is an **action backlog**, not an assertion that the backups do not exist.
Unchecked means **not verified in this repository**. Mark an item complete
only after an off-host copy and a recovery/readability test. Record the test
date and a non-secret pointer to its custody location here; never commit the
secret, its decrypted contents or a password-manager recovery code.

**Recovery contract:** rebuild the current configuration from
`nix-config` + `argo`, not the exact identity or a historical point in time.
Payload/user data from applications are backed up separately. The authoritative
rebuild sequence is [restore.md](restore.md).

## Required recovery material / high-value shortcuts

- [ ] **P0 — Secure Boot signing keys on `meawhite`.** Back up the complete
  `/var/lib/sbctl` key material, encrypted and *outside that host*. Confirm
  decryption, file integrity and that the restored keys can sign artifacts
  accepted by its current firmware policy. Document the private custody
  location and verification date (not key bytes).
- [ ] **P0 — Secure Boot signing keys on `meablack`.** Independently back up
  and test its `/var/lib/sbctl` material. Do not assume the hosts share keys.
  If intentionally choosing fresh firmware enrollment instead, explicitly
  document and test that alternative with physical console access.
- [ ] **P0 — LUKS recovery passphrase for `meawhite`.** The host README
  describes one independently generated passphrase protecting both encrypted
  root and mdadm RAID1-backed `/data`. Verify it unlocks **both** mappings
  at a physical console, then hold an encrypted/offline copy separately
  from the automatically erasing installer USB/ISO.
- [ ] **P0 — LUKS recovery passphrase and recovery key for `meablack`.**
  Preserve its installer-generated passphrase and the independent recovery
  key if one was created. Test a non-TPM unlock at the console. If the
  additional key has not yet been enrolled, do so using the documented
  `meablack/README.md` procedure and retain the original passphrase slot.
- [ ] **P0 — Independent administrative access.** Confirm an off-host
  recoverable copy of the workstation's SSH *private* key or an alternate
  console/bootstrap credential that matches the public keys in Git.
  Test access to a rebuilt host through a trusted SSH fingerprint workflow.
  A backup must remain accessible if both physical hosts fail.

These are required for a **quick, non-interactive-compatible rebuild with
the current firmware trust** or for access to surviving encrypted disks.
With physical access and permission to re-enroll firmware or erase disks,
new Secure Boot and LUKS keys *can* instead be generated, but that is a
different, slower recovery route. No secret material belongs in this public
repository.

## Non-declarative environment to capture

- [ ] **P1 — Router/DHCP configuration.** Export the router's configuration
  or maintain a tested recovery inventory of MAC-to-IP reservations,
  gateway/subnet/DNS and any firewall rules outside Git. The cluster
  requires cp-01's `02:6b:38:00:00:01` to resolve to `192.168.1.103`;
  the host addresses are `192.168.1.137` (`meawhite`) and
  `192.168.1.28` (`meablack`). The remaining guest MACs are in
  `kubernetes/nodes.nix`; record their actual leases as necessary.
  Test re-creating the essential reservations on a replacement router.
- [ ] **P1 — LUKS2 header backups for surviving volumes.** After checking
  the real disk identities, save encrypted/off-host headers for
  `meawhite` root and RAID1-backed data, and `meablack` root.
  Verify archive integrity and document which header belongs to which
  device. These help **repair existing encrypted disks**, not a
  wipe-and-rebuild where new encryption identities are acceptable.
- [ ] **P1 — Recovery custody and physical access.** Record, in a private
  recovery inventory, where encrypted key backups live, how to unlock
  *those backups*, how to access each machine's console, and the required
  Secure Boot firmware enrollment / TPM2 PCR-7 re-enrollment steps.
  Keep the decryption path independent of either failed host. Test that
  the process works without an active Kubernetes cluster.
- [ ] **P1 — External service credentials, if introduced.** Before adding
  applications that depend on external APIs, DNS services, a private Git
  repository or SOPS/age secrets, add their root decryption/recovery keys and
  account recovery procedure here. The current public `argo` root does not
  supply such a secret-distribution mechanism by itself.

## Useful but not required for cluster identity

- [ ] **P2 — Offline Git recovery copy.** Periodically verify an external
  clone/bundle of `nix-config` (including `flake.lock`) and `argo` can be
  read. GitHub access to the current public repositories is normally enough;
  this only reduces dependency on upstream availability during a disaster.
- [ ] **P2 — Rebuild drill.** On disposable infrastructure or a carefully
  isolated test environment, restore the saved host recovery material,
  validate key usability and follow [restore.md](restore.md) as far as
  practical. Record failures, corrections and the date. Never test by
  wiping the live cluster.

## Intentionally *not* in this backlog

- **No point-in-time K3s or etcd snapshot and no old K3s server/join token.**
  The new cp-01 generates the tokens and a fresh datastore.
- **No copy of MicroVM `state.img`, old Kubernetes objects/UIDs, node
  private keys, Argo CD initial administrator password or SSH *host*
  private keys.** All are intentionally regenerated for this contract.
- **No payload/application-user-data backups here.** Stateful applications
  need their own backup, restore and consistency checks.
- TPM2 PCR-7 sealed unlock state is hardware/policy-specific. Recover the
  passphrases or recovery keys and re-enroll TPM2 rather than copying a
  sealed token and assuming it works on replacement hardware.

## Evidence log

After an item is verified, add a dated entry without secrets:

| Date | Item | Verification | Non-secret custody reference |
| --- | --- | --- | --- |
| — | — | Not yet documented | — |

A copy without a tested way to decrypt and use it is **not** complete.
