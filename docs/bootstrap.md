# MicroVM foundation bootstrap

## Retire the existing Talos guest

This revision removes the Talos guest module, NixVirt input, tooling and CI.
It retains the host's LAN bridge. No disk deletion or conversion is performed.
Before activating it on meawhite:

1. Preserve the private Talos config, kubeconfig and any data you need.
2. Using the existing authenticated Talos client and endpoint, run
   `talosctl shutdown`. While the old configuration still provides libvirt,
   verify `virsh -c qemu:///system domstate talos` reports `shut off`, then
   run `virsh -c qemu:///system autostart --disable talos`.
3. Confirm the VM is stopped before activating this revision. Do not use
   `virsh destroy`, format a disk, or regenerate Talos PKI as a shutdown step.

Old files under `/var/lib/libvirt/talos` and `/data/talos` remain for recovery.
The new cluster starts with separate images under `/var/lib/microvms`.
Removing libvirt support from NixOS does not migrate any Kubernetes state.

## Review the site values

Obtain these on the LAN before proceeding beyond the test guest:

- meablack's physical wired interface and current MAC. Run `ip -br link`,
  `ip -4 route show default` and `ip -4 address` on that host; correlate the
  default-route device with its link MAC.
- Five fixed DHCP node addresses for the MACs in `kubernetes/nodes.nix`.
- One unused API VIP and its DNS name; these must remain outside DHCP and
  the application LoadBalancer pool.
- A reserved application LoadBalancer range and nonconflicting Pod/Service
  CIDRs. The known LAN alone is insufficient to exclude VPN/other route conflicts.
- A runtime secret provisioning approach for the K3s token, initially sops-nix.
  Do not send tokens or private keys in chat or commit plaintext to Git.

## Bootstrap k8s-cp-01 on meawhite

The operator has chosen to skip the disposable `k8s-test` guest. The committed
`meawhite/microvms.nix` enables **only** `k8s-cp-01`; meablack remains disabled.
Both physical hosts use Secure Boot, so always use the `-secure` flake outputs.
Do not enable the other nodes before their join endpoints and secret delivery exist.

Before deployment, shut down the retired Talos guest as described above and
preserve its disks and credentials. Reserve a DHCP lease for
`02:6b:38:00:00:01` and verify the lease is available. Check that K3s's
default Pod CIDR `10.42.0.0/16` and Service CIDR `10.43.0.0/16` do not
overlap the LAN, VPN or routed networks; change them before initializing etcd
if they conflict. Confirm the host has working `br0`, KVM and sufficient disk
space under `/var/lib/microvms`.

From the current repository checkout on the x86_64 workstation:

```sh
git diff --check
# New Nix files must be staged or committed for the flake to include them.
nix eval --no-update-lock-file --impure --json --expr '
  import ./tests/microvms.nix { flake = builtins.getFlake (toString ./.); }
'
nix build --no-update-lock-file --no-link .#nixosConfigurations.k8s-cp-01.config.microvm.declaredRunner
nix build --no-update-lock-file --no-link .#nixosConfigurations.meawhite-secure.config.system.build.toplevel
```

Only after successful evaluation/build and an available host recovery path,
activate on the secure-boot host over SSH:

```sh
ssh root@192.168.1.137 'hostname; ip -4 address show br0; ip -4 route'
nixos-rebuild switch --flake .#meawhite-secure --target-host root@192.168.1.137
ssh root@192.168.1.137 'systemctl status microvm@k8s-cp-01 --no-pager'
ssh root@192.168.1.137 'bridge link show dev k8s-cp-01'
ssh root@192.168.1.137 'journalctl -b -u microvm@k8s-cp-01 --no-pager'
```

Determine the guest's actual lease from the DHCP server; do not infer it from
the MAC. From the workstation, use `CP01_IP` for that address:

```sh
CP01_IP=<observed-guest-address>
ssh root@"$CP01_IP" 'hostname; findmnt /var; readlink -f /etc/rancher/node'
ssh root@"$CP01_IP" 'systemctl status k3s --no-pager'
ssh root@"$CP01_IP" 'k3s kubectl get nodes -o wide'
ssh root@"$CP01_IP" 'test -s /var/lib/rancher/k3s/server/token && echo "server token exists"'
```

The Kubernetes API and embedded etcd should start, but the node may be
`NotReady` until Cilium is installed. Do not weaken Pod Security or enable
Flannel to hide that condition. Check K3s logs for actual failures.

**Recovery gate:** K3s generates the initial server token under persistent
`/var/lib/rancher/k3s/server/token`. Secure an encrypted off-host copy without
printing it in logs or storing it in Git/the Nix store; record etcd snapshot
and restore procedures before treating the cluster as durable. Verify that
`/etc/rancher/node` resolves to `/var/lib/rancher/node` on the persistent disk,
then confirm the password and K3s datastore survive a single-guest restart
before proceeding. A future join phase must supply tokens with a runtime
secret mechanism such as sops-nix; the remaining guests intentionally have
K3s disabled.

## Optional foundation-only test guest

`k8s-test` remains defined in `kubernetes/nodes.nix` but is not activated.
If later needed, enable it in `meawhite/microvms.nix` for separate foundation
diagnostics. It must not be mistaken for a Kubernetes node.

## meablack bridge

Set its observed `uplink` and `bridgeMac` in `meablack/microvms.nix` before
enabling the profile. This moves DHCP from the physical NIC to the bridge.
Keep `guests = [ ];` while verifying the bridge. Arrange a console or a
tested timed rollback before remotely activating any network change. Verify
that new SSH sessions reach `192.168.1.28`, DHCP retains the expected host
address, and the default route works before making the change persistent.

After verifying the first real K3s server, configure K3s join credentials, a
reserved API VIP/DNS name and readiness-based Keepalived. Join cp-02 and cp-03
one at a time, then the workers. This revision does not activate those nodes,
install Cilium or provision persistent application volumes.
