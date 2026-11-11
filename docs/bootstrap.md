# Bootstrap k8s-cp-01

Only `k8s-cp-01` is enabled on meawhite; both physical hosts use Secure Boot.
Do not enable additional guests until K3s join credentials and API addressing exist.

## Prerequisites

- Shut down and disable autostart of the retired Talos/libvirt guest, if still
  present; retain its disk images and private recovery material.
- Reserve a DHCP address for `02:6b:38:00:00:01`; verify meawhite's `br0`,
  KVM, host rollback access and free space under `/var/lib/microvms`.
- Confirm Pod CIDR `10.42.0.0/16` and Service CIDR `10.43.0.0/16`
  do not collide with routed LAN/VPN networks before initializing etcd.

## Workstation

From the checked-out repository:

```sh
git diff --check
nix eval --no-update-lock-file --impure --json --expr '
  import ./tests/microvms.nix { flake = builtins.getFlake (toString ./.); }
'
nix build --no-update-lock-file --no-link .#nixosConfigurations.k8s-cp-01.config.microvm.declaredRunner
nix build --no-update-lock-file --no-link .#nixosConfigurations.meawhite-secure.config.system.build.toplevel
```

After successful checks, deploy with:

```sh
nixos-rebuild switch --flake .#meawhite-secure --target-host root@192.168.1.137
ssh root@192.168.1.137 'systemctl status microvm@k8s-cp-01 --no-pager'
ssh root@192.168.1.137 'bridge link show dev k8s-cp-01'
```

Use the guest's **observed** DHCP address:

```sh
CP01_IP=<guest-ip-from-dhcp>
ssh root@"$CP01_IP" 'findmnt /var; readlink -f /etc/rancher/node'
ssh root@"$CP01_IP" 'systemctl status k3s --no-pager; k3s kubectl get nodes'
ssh root@"$CP01_IP" 'test -s /var/lib/rancher/k3s/server/token && echo token-present'
```

Expect `NotReady` until Cilium is deployed. Before proceeding, verify guest
restart persistence and preserve an **encrypted off-host** server token and
etcd recovery material. Do not print or commit tokens.

For meablack, first discover the real uplink/MAC in `meablack/microvms.nix`.
Moving DHCP to the bridge can disconnect SSH: use console/timed rollback.
