# Talos on meawhite (declarative KVM)

The NixOS module [../talos-vm.nix](../talos-vm.nix) declares **one** KVM
VM, its private libvirt NAT network and two persistent qcow2 volumes via
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
- Libvirt private NAT network `talos`: gateway `192.168.127.1`,
  reserved guest address `192.168.127.10`. It does not alter the host's
  DHCP/uplink or expose the Talos API to the physical LAN. Initial
  management runs on meawhite; a LAN bridge or reviewed forwarding is
  a separate network change.
- Legacy BIOS (q35), not Secure Boot. No GPU passthrough, extra Talos
  extensions, or VM memory hotplug.
- The NixVirt-managed `qemu:///system` domain/network/pool lists are
  **authoritative**: NixVirt can undefine libvirt objects omitted from
  these lists. Do not use this connection for unrelated VMs.
- VM starts **disabled**: `meawhite.talos.start = false`. Only enable
  startup after the installer ISO and disk state have been checked.
  NixVirt is configured not to restart a running domain on NixOS
  rebuild, even if the persistent domain XML changes. Schedule a
  controlled guest reboot to apply those changes.
- The qcow2 volumes are created only if absent; ordinary NixOS
  rebuilds do not reformat or replace them. Removing a managed storage
  pool definition does *not* delete its backing files, but manually
  deleting a volume is destructive. Keep tested off-host backups.

## First installation

**Do not run the old meawhite unattended host installer to create or
repair a VM.** That USB installer erases the physical host disks.

1. Install and unlock the NixOS host, confirm `findmnt /data`, RAID
   health and sufficient space on both filesystems, then apply the
   meawhite NixOS configuration. The libvirt VM is defined but stopped.
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
4. From meawhite or a machine with a route into the libvirt network,
   use a `talosctl` client matching **v1.14.5** to inspect the guest
   disks **before generating configuration**:

   ```sh
   talosctl get disks --insecure --nodes 192.168.127.10 -o yaml
   ```

   Verify which disk is the 64 GiB system disk and which is the 256 GiB
   data disk; the `talos-system`/`talos-data` libvirt serials help,
   but never infer the install target from `/dev/vdX` numbering alone.
5. Generate private machine configuration using the **observed** system
   disk path (`SYSTEM_DISK`), not an unverified example:

   ```sh
   umask 077
   mkdir -p ~/.local/state/meawhite-talos
   talosctl gen config meawhite https://192.168.127.10:6443 \
     --talos-version v1.14.5 \
     --install-disk "$SYSTEM_DISK" \
     --config-patch-control-plane @meawhite/talos/cilium.patch.yaml \
     --output-dir ~/.local/state/meawhite-talos
   talosctl validate --config ~/.local/state/meawhite-talos/controlplane.yaml --mode metal
   ```

   Confirm the generated **v1.14 typed** `UnattendedInstallConfig`
   points to the correct system disk, that Flannel/kube-proxy are off
   and the control-plane taint is removed. Keep Talos credentials,
   generated config and kubeconfig **outside Git and the Nix store**.
6. Apply the machine config only after reviewing it:

   ```sh
   talosctl apply-config --insecure --nodes 192.168.127.10 \
     --file ~/.local/state/meawhite-talos/controlplane.yaml
   ```

   After Talos installs to its system disk, **detach the ISO** by
   setting `meawhite.talos.installerIso = null` and rebuild. Because
   `restart = false` preserves a running domain, stop the VM
   gracefully before this change and restart it after the new domain
   definition has been applied. Verify boot from disk before removing
   the ISO file.
7. Bootstrap etcd **once** with the retained Talos credentials.
   Check `talosctl health`, `kubectl get nodes` and the node IP.
   Install pinned Cilium using the single-node Talos-compatible values
   documented in the reference `digital-garden/cluster/bootstrap/cilium`
   (without allowing another controller to own its initial Helm release).
   The Kubernetes API will not be fully usable until the CNI is ready.
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
