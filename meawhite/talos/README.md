# Talos on meawhite (declarative KVM)

The NixOS module [../talos-vm.nix](../talos-vm.nix) declares **one** KVM
VM, one NIC on the host LAN bridge and two persistent qcow2 volumes via
[NixVirt](https://github.com/AshleyYakeley/NixVirt). NixOS owns the
hypervisor and disk files; Talos owns its node OS; Kubernetes/Argo CD own
cluster workloads. No Incus or OpenTofu is involved.

## Intentional constraints

- Four vCPUs, 12 GiB fixed memory; **no ballooning**.
- 64 GiB Talos system disk on the encrypted NVMe root filesystem,
  under `/var/lib/libvirt/talos`.
- A separate, sparse 256 GiB data disk on the encrypted RAID1 mount at
  `/data/talos`. The `nixvirt` service requires `data.mount` and will
  refuse to run if it is unavailable. These are *virtual* disks, not
  physical disks passed to the guest. Ensure actual host free space
  before writing to them.
- One virtio NIC using host bridge `br0` on the `192.168.1.0/24`
  LAN, with MAC `52:54:00:7a:10:01`. The LAN's DHCP server assigns
  the guest address. Once the router sees this MAC and assigns a lease,
  make that lease permanent in the router. Do not assume any address
  before the first LAN boot.
  Talos API (50000) and Kubernetes API (6443) will become LAN-reachable:
  restrict LAN access as needed and do not forward them on the router.
  The former `talos` libvirt NAT network is removed on activation.
- Legacy BIOS (q35), not Secure Boot. No GPU passthrough, extra Talos
  extensions, or VM memory hotplug.
- The NixVirt-managed `qemu:///system` domain/network/pool lists are
  **authoritative**: NixVirt can undefine libvirt objects omitted from
  these lists. Do not use this connection for unrelated VMs.
- For the installed guest, `meawhite.talos.start = true` and
  `meawhite.talos.installerIso = null`. NixVirt uses `restart = false`
  and does not power-cycle an already running domain on rebuild.
  **Shut the VM down gracefully before the first activation of this
  network change** so NixVirt can replace its NIC and remove the old
  NAT network without disconnecting a running guest.
- The qcow2 volumes are created only if absent; ordinary NixOS
  rebuilds do not reformat or replace them. Removing a managed storage
  pool definition does *not* delete its backing files, but manually
  deleting a volume is destructive. Keep tested off-host backups.

## Migrate the existing Talos cluster from NAT to LAN

The host bridge `br0` is already tested and persistent. This change
replaces the guest's **only** NIC (`52:54:00:7a:10:01`) with a bridged
NIC using the same MAC. There is no second NIC and no libvirt NAT
network. VM disks and Talos credentials are unchanged.

No user workloads are deployed yet, so an interruption to the
single-node Kubernetes cluster is acceptable. **Do not re-bootstrap etcd
or regenerate Talos secrets as a routine part of the migration.**

1. Before the switch, preserve the current private Talos configuration
   and kubeconfig from `meanovo`. With the existing SSH tunnels running,
   confirm that the node is ready, and shut Talos down cleanly with
   authenticated `talosctl shutdown` (using the old NAT endpoint).
   Confirm `virsh -c qemu:///system domstate talos` is `shut off`.
2. Build and activate the NixOS configuration from this change on
   `meawhite`. With the guest shut down, NixVirt can redefine the
   persistent domain to use `br0` and remove the previous managed NAT
   network. `meawhite.talos.start = true` requests guest startup.
   Review `virsh -c qemu:///system dumpxml talos --inactive` to verify
   exactly one NIC, type `bridge`, source `br0`, and the original MAC.
3. Allow the VM's LAN NIC to obtain its initial address via DHCP.
   Find the new lease in the router using MAC `52:54:00:7a:10:01`,
   then mark the router's assigned address as fixed. Talos uses DHCP
   when no static network configuration has been supplied; inspect
   the guest console if it does not appear. Test the Talos API from
   `meanovo` with the *existing* Talos credentials at the assigned IP.
4. Check Talos health, etcd member health, node IP selection, the
   Kubernetes API, and Cilium. The original control-plane endpoint,
   kubeconfig server, and API certificate SANs may still reference
   `192.168.127.10`. Update the **existing** Talos machine config and
   kubeconfig to the chosen LAN address, preserving existing PKI;
   validate TLS and API access before declaring the migration complete.
   A change of node address can require Kubernetes/Cilium reconciliation.
   No applications depend on this cluster yet, so repairing or
   rebuilding the guest is an acceptable last resort.

Never rerun `talosctl bootstrap` on the existing etcd data. Do not
`virsh destroy` the VM or reattach its installation ISO. The host stays
accessible via SSH on `192.168.1.137` throughout; libvirt's serial
console provides guest recovery even if Talos networking is broken.

## Automatic Cilium bootstrap

Talos v1.14.5's `KubeInlineManifestConfig` automatically applies
**rendered Kubernetes resources** at cluster bootstrap. Talos does not
run Helm or a Helm controller: the Helm chart must be rendered first.

The source of truth for the initial CNI is [cilium-values.yaml](cilium-values.yaml),
derived from Digital Garden's working Talos-safe Cilium settings, with
Cilium **v1.20.4** pinned in [render-cilium.sh](render-cilium.sh).
Render the chart in `nix develop .#meawhite-talos`, which provides pinned
`talosctl`, `helm` and Cilium CLI tooling. The renderer writes a **typed
Talos patch** into the private state directory, not into Git or the
Nix store. Include that patch at first machine-config generation.

This is **not a Helm release** and not ongoing GitOps. Upgrades and
a future Argo CD ownership handoff require an explicit plan; never
install a second Cilium copy with `helm install` or implicitly hand
its resources to Argo. Talos's bootstrap manifest is only an initial
installation mechanism. Cilium v1.20.4 has been e2e-tested up to
Kubernetes 1.36, while Talos v1.14.5 generates Kubernetes 1.37.1;
do not treat the version pairing as production-supported without
acceptance tests.

## First installation (new cluster only)

For a brand-new cluster using the LAN bridge, boot the guest to obtain a
DHCP lease, then make that lease fixed in the router and set `TALOS_IP`
to the assigned address (example: `export TALOS_IP=<actual-leased-ip>`). The commands below describe
*initial installation*, not migration of the already bootstrapped
`meawhite` cluster.

**Do not run the old meawhite unattended host installer to create or
repair a VM.** That USB installer erases the physical host disks.

1. Install and unlock the NixOS host, confirm `findmnt /data`, RAID
   health and sufficient space on both filesystems, then apply the
   meawhite NixOS configuration. The libvirt VM is defined and may be started automatically when `meawhite.talos.start = true`.
   Check `systemctl status nixvirt`, `virsh -c qemu:///system list --all`,
   `virsh -c qemu:///system pool-list --all`, and
   `virsh -c qemu:///system net-list --all`.
2. Download and **verify the upstream SHA256** for Talos v1.14.5
   `metal-amd64.iso` from the official release on a trusted machine.
   Copy the ISO to `/var/lib/libvirt/talos/metal-amd64.iso` on meawhite.
   This is a runtime file, not a Nix input.
3. Temporarily set these two options in the host configuration:

   ```nix
   meawhite.talos.installerIso = "/var/lib/libvirt/talos/metal-amd64.iso";
   meawhite.talos.start = true;
   ```

   Rebuild the host. Check the serial console with
   `virsh -c qemu:///system console talos` (exit with Ctrl+]).
   The ISO boots first while attached. If bootloader output is not
   visible on the serial console, use `virt-viewer` or the graphical
   console to inspect the installer; do not guess disk identities.
4. From meawhite or a machine with a route into the LAN,
   use a `talosctl` client matching **v1.14.5** to inspect the guest
   disks **before generating configuration**:

   ```sh
   talosctl get disks --insecure --nodes "$TALOS_IP" -o yaml
   ```

   Verify which disk is the 64 GiB system disk and which is the 256 GiB
   data disk; the `talos-system`/`talos-data` libvirt serials help,
   but never infer the install target from `/dev/vdX` numbering alone.
5. Generate private machine configuration using the **observed** system
   disk path (`SYSTEM_DISK`), not an unverified example:

   ```sh
   nix develop .#meawhite-talos
   umask 077
   mkdir -p ~/.local/state/meawhite-talos
   bash meawhite/talos/render-cilium.sh \
     "$HOME/.local/state/meawhite-talos/cilium-bootstrap.patch.yaml"

   talosctl gen config meawhite "https://${TALOS_IP}:6443" \
     --talos-version v1.14.5 \
     --install-disk "$SYSTEM_DISK" \
     --config-patch-control-plane @meawhite/talos/cilium.patch.yaml \
     --config-patch-control-plane @"$HOME/.local/state/meawhite-talos/cilium-bootstrap.patch.yaml" \
     --config-patch @meawhite/talos/installer.patch.yaml \
     --output-dir ~/.local/state/meawhite-talos
   talosctl validate --config ~/.local/state/meawhite-talos/controlplane.yaml --mode metal
   ```

   Confirm the generated **v1.14 typed** `UnattendedInstallConfig`
   points to the correct system disk, that Flannel/kube-proxy are off,
   that the control-plane taint is removed, and that the generated
   `KubeInlineManifestConfig` contains the reviewed Cilium resources. Keep Talos credentials,
   generated config and kubeconfig **outside Git and the Nix store**.
6. Apply the machine config only after reviewing it:

   ```sh
   talosctl apply-config --insecure --nodes "$TALOS_IP" \
     --file ~/.local/state/meawhite-talos/controlplane.yaml
   ```

   After Talos installs to its system disk, **detach the ISO** by
   setting `meawhite.talos.installerIso = null` and rebuild. Because
   `restart = false` preserves a running domain, stop the VM
   gracefully before this change and restart it after the new domain
   definition has been applied. Verify boot from disk before removing
   the ISO file.
7. Bootstrap etcd **once** with the retained Talos credentials.
   Talos applies the embedded Cilium manifests automatically when
   the Kubernetes API becomes available; **do not run `helm install`
   or `kubectl apply` against Cilium separately**. Inspect the Talos
   bootstrap manifests and Kubernetes status:

   ```sh
   talosctl --nodes "$TALOS_IP" get manifests
   kubectl -n kube-system rollout status daemonset/cilium --timeout=5m
   kubectl -n kube-system rollout status deployment/cilium-operator --timeout=5m
   kubectl get nodes -o wide
   cilium status --wait
   cilium connectivity test --single-node \
     --namespace-labels pod-security.kubernetes.io/enforce=privileged
   ```

   If the API is not reachable or Cilium fails to become ready, inspect
   Talos manifest resources, Cilium pods/events and the node before
   changing anything. On this one-node cluster, CoreDNS and Kubernetes
   node readiness may lag until Cilium starts. Keep the Pod Security
   exception limited to the temporary connectivity test namespaces.
   Argo CD Core and application GitOps are separate, subsequent steps.
8. For the second disk, create a Talos `UserVolumeConfig` only after
   inspecting **live guest disk identity and size**. A UserVolume can
   **format its selected disk**; never reuse the Digital Garden by-id
   selectors or format the Talos system disk. Mount and reboot-test it
   before configuring OpenEBS Local PV Hostpath to consume that mount.

The Talos version and Cilium bootstrapping conventions here are
inspired by [Digital Garden](https://github.com/mitschwimmer/digital-garden),
but none of that repository's host, disk, network, or GPU identifiers
are reused. A working cluster is not implied by a successful NixOS
build; the guest installation and Cilium connectivity still require
runtime acceptance.

## Recovery

Keep the Talos machine secrets, client credentials, etcd snapshot,
backup decryption keys and application data backups **off-host**.
The VM has a single control-plane failure domain. RAID1 and persistent
qcow2 files alone are not backups. Stop the guest gracefully before
host maintenance; never run `virsh destroy` as a routine shutdown.
