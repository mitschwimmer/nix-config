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

## First test on meawhite

The default configuration runs no MicroVMs. In `meawhite/microvms.nix`, set
`enable = true` and `guests = [ "k8s-test" ];`. Leave the cluster guests off.
The test guest obtains a real DHCP lease; look it up by MAC
`02:6b:38:00:00:fe` and record its address. Do not guess an IP.

From this repository on an x86_64 Linux machine with Nix:

```sh
nix build --no-update-lock-file .#nixosConfigurations.k8s-test.config.microvm.declaredRunner
nix build --no-update-lock-file .#nixosConfigurations.meawhite.config.system.build.toplevel
nix build --no-update-lock-file .#nixosConfigurations.meawhite-secure.config.system.build.toplevel
```

On meawhite, use the already installed boot variant. If Secure Boot is active,
use `--flake .#meawhite-secure`; otherwise use `--flake .#meawhite`. Do not
switch Secure Boot variants just to deploy the guest. From the checkout:

```sh
sudo nixos-rebuild switch --flake .#meawhite
sudo systemctl status microvm@k8s-test
ip link show k8s-test
bridge link show dev k8s-test
sudo journalctl -u microvm@k8s-test -b --no-pager
```

Check that the TAP is attached to `br0`. The journal includes the serial
console. Set `TEST_IP` to the actual observed DHCP address in your shell.

```sh
ssh root@"$TEST_IP" 'hostname; ip -4 address show lan0; ip -4 route; resolvectl status lan0; timedatectl show -p NTPSynchronized'
ssh root@"$TEST_IP" 'findmnt /var; findmnt /nix/store; cat /etc/machine-id; cat /var/lib/ssh/ssh_host_ed25519_key.pub'
ssh root@"$TEST_IP" 'printf "microvm-persistence-test\n" > /var/lib/foundation-test; sync'
sudo systemctl restart microvm@k8s-test
ssh root@"$TEST_IP" 'cat /var/lib/foundation-test'
```

Wait for SSH to return after restarts. Test DNS resolution of an actual LAN
name with `resolvectl query meawhite.localdomain` in the guest; check LAN
reachability from another machine. Rebuild the test guest with a harmless
configuration change, follow [operations.md](operations.md) to restart only
it, and verify the marker, SSH host key, machine ID and DHCP lease remain.

Reboot meawhite during a maintenance window, reconnect, then repeat those
checks. Confirm the test guest starts automatically and `/var` is mounted
from the original raw image. Record observations in
[validation.md](validation.md). A successful evaluation is not this test.

## meablack bridge

Set its observed `uplink` and `bridgeMac` in `meablack/microvms.nix` before
enabling the profile. This moves DHCP from the physical NIC to the bridge.
Keep `guests = [ ];` while verifying the bridge. Arrange a console or a
tested timed rollback before remotely activating any network change. Verify
that new SSH sessions reach `192.168.1.28`, DHCP retains the expected host
address, and the default route works before making the change persistent.

Only after the foundation acceptance is recorded should K3s bootstrap be
implemented and the five cluster guests enabled. The existing guest outputs
are OS foundations, not initialized Kubernetes nodes.
