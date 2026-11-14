# MicroVM operations

Commands run on the physical host unless otherwise noted. Use the
`-secure` NixOS flake variants for both hosts.

The host's scripted `br0` bridge is kept intact. MicroVM TAP attachment uses
systemd drop-ins ordered after `br0-netdev.service`. A host rebuild does not
restart already-running MicroVMs; restart them individually after this change.

## Inspect

```sh
sudo systemctl status microvm@k8s-cp-01
sudo journalctl -b -u microvm@k8s-cp-01 --no-pager
sudo readlink -f /var/lib/microvms/k8s-cp-01/{current,booted}
bridge link show dev k8s-cp-01
df -h /var/lib/microvms
```

## Update one guest

Host rebuilds install runner revisions but do not restart existing guests
(`restartIfChanged = false`). With exactly two etcd voters, do not restart
either member during normal operation: both are required for quorum.
Cordon/drain does not preserve etcd quorum. Wait for a healthy third voter or
plan an explicit maintenance outage before restarting. With three or more
members, cordon/drain workloads and check voting-member health/quorum first.
On meawhite, preserve the old runner as a GC root before updating:

```sh
sudo nix-store --realise "$(readlink -f /var/lib/microvms/k8s-cp-01/booted)" \
  --add-root /nix/var/nix/gcroots/k8s-cp-01-before-update
```

From the workstation, deploy `meawhite-secure` as in
[bootstrap.md](bootstrap.md). Then on meawhite:

```sh
sudo systemctl start install-microvm-k8s-cp-01.service
sudo systemctl restart microvm@k8s-cp-01
```

Verify K3s, etcd, networking and persistent `/var` before removing the GC
root. For an emergency runner rollback, stop the VM, point `current` to the
saved runner and start it again; then revert the change in Git. Never delete
`state.img` or change `booted` during shutdown.

NixOS rollback does not roll back K3s/etcd state. A K3s downgrade may need a
matching datastore restore; never assume reverting a Nix generation is enough.

## cp-01 Cilium health port during cp-02 staging

The cp-02 join change declares TCP 4240 for both servers. The existing cp-01
VM keeps its older runner during host deployment, so that rule needs a live
application during the approved activation, without restarting K3s or the VM.
On cp-01 (not on the physical host), inspect the rules and open TCP 4240 once:

```sh
sudo nixos-firewall-tool show
sudo nixos-firewall-tool open tcp 4240
```

This is a temporary runtime rule matching the declarative guest configuration.
It disappears when the old guest's firewall is reloaded or the guest reboots;
reapply until cp-01 eventually boots the updated runner. Do not reboot cp-01
for this rule while only two etcd voters exist. Verify ICMP and TCP health
from cp-02 after joining, along with cross-node Pod and service connectivity.
Do not open VXLAN/8472: the cluster uses Cilium native routing.

## Join credential lifecycle

Each joiner's `/var/lib/rancher/k3s/join-token` stays root:root 0600 on persistent
`/var`. Keep it for subsequent starts; K3s must not start with a missing,
empty or improperly protected file. Provision it through the SSH procedure in
[bootstrap.md](bootstrap.md), never through a Nix derivation or token literal.
A future server-token rotation must also update this runtime file using a
controlled procedure before restarting a joiner. Do not rotate tokens implicitly
as part of expansion or remove a member's state to troubleshoot a join.

## Meablack bridge cutover

First activation of `eno1` into `br0` can disconnect SSH. Use the following
staged procedure after review/builds, without changing meawhite. It tests
runtime networking before installing a boot configuration. The 15-minute
rollback timer runs on meablack independently of SSH; it is not persistent
across a host reboot. Do not reboot during this test. Console access remains
the fallback if reverting the old networking configuration cannot recover it.
Do not provision cp-03's token until the cutover is confirmed and committed.

On the workstation, from the clean reviewed checkout, build and copy the host
closure **before** arming rollback:

```sh
new_system=$(nix build --no-update-lock-file --no-link --print-out-paths \
  .#nixosConfigurations.meablack-secure.config.system.build.toplevel)
nix copy --to ssh://root@192.168.1.28 "$new_system"
```

On meablack, as root, preserve the currently running closure and arm rollback.
If units with these names already exist, inspect the previous attempt first;
do not reuse an active timer or overwrite the recovery root blindly.

```sh
old_system=$(readlink -f /run/current-system)
nix-store --realise "$old_system" \
  --add-root /nix/var/nix/gcroots/meablack-before-cp03
systemd-run --unit=meablack-network-rollback --on-active=15m \
  --timer-property=AccuracySec=1s --property=Type=oneshot \
  "$old_system/bin/switch-to-configuration" test
systemctl is-active meablack-network-rollback.timer
```

From the same workstation shell holding `new_system`, start the test in a
host-managed service so that activation survives the SSH connection dropping:

```sh
ssh -n root@192.168.1.28 \
  "systemd-run --no-block --unit=meablack-bridge-test \
   --property=Type=oneshot --property=RemainAfterExit=yes \
   $new_system/bin/switch-to-configuration test"
```

Reconnect to `192.168.1.28` and inspect. The test must finish successfully
(`active`, `exited`, `Result=success`), `br0` must have the retained MAC and
host address, the default route must use `br0`, and `eno1` plus the guest TAP
must be bridge members. The uplink must have no separate IPv4 lease.

```sh
systemctl show meablack-bridge-test.service -p ActiveState -p SubState -p Result
ip -br link
ip -br -4 address
ip -4 route
bridge link
systemctl status microvm@k8s-cp-03 --no-pager
systemctl list-timers meablack-network-rollback.timer --no-pager
```

If the test fails or SSH cannot reconnect, let rollback run and inspect its
journal from the recovered connection or console. It restores the old runtime
closure using `test`; the boot configuration was never committed. Do not join
cp-03, rerun the cutover blindly, or delete its newly created state image.
An existing image after a failed attempt must be inspected before retrying.

Only after successful network checks, **before the timer expires**, on meablack:

```sh
systemctl stop meablack-network-rollback.timer
```

If rollback has already fired, do not commit; inspect/reconcile the running
configuration first. Otherwise, from the unchanged workstation checkout,
commit the same successfully tested configuration:

```sh
nixos-rebuild switch --flake .#meablack-secure --target-host root@192.168.1.28
```

Recheck SSH/address/routes and guest status. Leave the old closure GC-rooted
until host/guest acceptance is complete. Do not reboot either existing etcd
member. Continue with cp-03's DHCP reservation and inactive-service checks in
[bootstrap.md](bootstrap.md#stage-cp-03-on-meablack), then provision its token.

References: [NixOS configuration changes](https://nixos.org/manual/nixos/stable/#sec-changing-config),
[systemd transient services/timers](https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html).

## Apply mixed capacity and add the worker

The declared layout is cp-01/cp-03: 4 GiB and 4 vCPUs; cp-02: 2 GiB and
2 vCPUs; worker-02 on meawhite: 16 GiB and 4 vCPUs. No worker is deployed
on meablack. Existing running VMs retain their old resources until their
updated host-side runner is installed and that VM is restarted. An internal
guest reboot does not replace the Cloud Hypervisor resource configuration.

1. From the clean reviewed checkout, evaluate the MicroVM suite, all four
   guest runners and both physical hosts including their secure variants.
   Build all four runners and both secure host toplevels before deployment.
2. Preserve each control-plane VM's booted runner as a distinct GC root
   (`<guest>-before-capacity-change`) on its physical host, using the existing
   update procedure. Keep their state images, tokens, identities and disk
   sizes intact. Confirm worker-02 has no preexisting state image on meawhite;
   if it does, inspect its history before booting it rather than deleting it.
3. Deploy `meawhite-secure` and `meablack-secure`. No bridge migration is
   required. Existing guests retain `restartIfChanged = false`; worker-02
   may auto-start for DHCP/SSH but cannot join without its token file. During
   this transition, meawhite's two existing 4 GiB servers plus the 16 GiB
   worker declare 24 GiB, falling to 22 GiB when cp-02 is reduced. Do not
   provision the worker's token or schedule new application loads yet.
4. Check all three servers remain Ready with Cilium 3/3 and metrics. Apply
   cp-02's scheduling taint from an existing server:

   ```sh
   k3s kubectl taint nodes k8s-cp-02 \
     node-role.kubernetes.io/control-plane=true:NoSchedule --overwrite
   ```

   The Nix registration flag covers a fresh Node only; it will not modify the
   existing Node automatically. NoSchedule does not evict existing pods.
5. Restart only cp-02 first, on meawhite, after preserving its old runner:

   ```sh
   sudo systemctl start install-microvm-k8s-cp-02.service
   sudo systemctl restart microvm@k8s-cp-02
   ```

   Verify roughly 2 GiB guest RAM minus kernel overhead, stable IP/SSH and
   node-password identity, persistent ext4 `/var`, K3s active, Node Ready,
   recovered Cilium 3/3 and metrics. Check memory availability/pressure, OOM
   events and pod restarts under normal activity. If unstable, restore its
   saved 4 GiB runner with the existing rollback procedure and halt rollout.
6. Only after complete recovery, update cp-03 on meablack and then cp-01 on
   meawhite, separately, to their new 4-vCPU runners. They retain 4 GiB RAM.
   Use each install/VM unit as above and fully recover health between nodes.
   cp-01 remains Cilium's fixed API endpoint, so its restart can interrupt
   Cilium API access; observe the cluster using cp-02's local API if needed.
   Separate etcdctl inspection and backup verification remain deferred by
   operator choice; do not restart more than one voting member at a time.
7. Inspect scheduling from an existing server:

   ```sh
   k3s kubectl get nodes -o custom-columns='NAME:.metadata.name,UNSCHEDULABLE:.spec.unschedulable,TAINTS:.spec.taints'
   ```

   cp-01/cp-03 should be uncordoned and have no control-plane/master NoSchedule
   taints. If a role taint is present, remove that specific role taint with
   `kubectl taint`; do not remove memory-pressure/not-ready taints. The declared
   K3s configurations do not set workload-blocking taints on these two nodes.
   If intentionally cordoned for this maintenance, uncordon after recovery.
8. Find worker-02's first DHCP lease by MAC `02:6b:38:00:00:05`, hostname
   `k8s-worker-02`, and reserve the observed IP. Verify its SSH host key,
   identity, persistent `/var` and inactive K3s with absent join token.
9. Follow [bootstrap.md](bootstrap.md#stage-the-single-worker) to provision
   its existing agent token and start K3s. Accept four Ready Nodes, only
   three etcd members/roles, Cilium 4/4, metrics and workload scheduling on
   the worker and both mixed servers. Test Pod-IP/Service-DNS traffic across
   hosts and between the worker and servers. Cilium's existing DaemonSet
   extends automatically; no second HelmChart/release is installed.

No worker is added to meablack. Strata's 60 GB system-RAM demand still needs
measurement/clarification before using cp-03's application capacity heavily.
Do not treat the mixed server's entire 4 GiB as available to applications.
Keep old runners GC-rooted until resource/persistence acceptance is complete.
