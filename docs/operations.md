# Kubernetes MicroVM operations

The running deployment is described by [architecture.md](architecture.md).
For **rebuilding from scratch** use [restore.md](restore.md); do not run
fresh-join or installer steps against an existing guest. Work on a reviewed
Git branch and use the signed `meawhite-secure` / `meablack-secure` host
profiles. The physical hosts and K3s membership are separate failure domains.

## Inspect before changing anything

On the physical host:

```sh
sudo systemctl status microvm@k8s-cp-01
sudo journalctl -b -u microvm@k8s-cp-01 --no-pager
sudo readlink -f /var/lib/microvms/k8s-cp-01/{current,booted}
bridge link show dev k8s-cp-01
df -h /var/lib/microvms
```

Replace the name for other guests and use the host in
`kubernetes/nodes.nix`. On cp-01 inspect K3s nodes, pods and Cilium.
Check etcd membership/quorum from the servers before changes.
With three voters, take at most **one** server down and wait for full
recovery before touching another. Losing `meawhite` loses two voters.

## Update a guest safely

1. Evaluate and build the affected runner and host closure from the current
   flake/lock file. Check tests and the host/guest diff.
2. Save the *booted* runner as a GC root on that host. For example, on
   `meawhite` before a cp-01 update:

   ```sh
   sudo nix-store --realise "$(readlink -f /var/lib/microvms/k8s-cp-01/booted)" \
     --add-root /nix/var/nix/gcroots/k8s-cp-01-before-update
   ```

3. Review capacity, workload availability and etcd quorum. Drain a node
   if appropriate for its workloads, but remember that draining does not
   preserve etcd quorum. Deploy the corresponding signed physical-host
   closure. Existing guests use `restartIfChanged = false` and do not
   automatically restart with a host rebuild.
4. Install and restart **only** the reviewed guest's new runner:

   ```sh
   sudo systemctl start install-microvm-k8s-cp-01.service
   sudo systemctl restart microvm@k8s-cp-01
   ```

5. Verify K3s/etcd membership, Node readiness, Cilium, metrics, guest
   `/var` persistence and affected workloads. Only then remove the GC root.
   Revert to the saved runner if the new one fails, but remember that a
   NixOS rollback **does not roll back** K3s/etcd data.

For a host networking change, especially a first `br0` activation, arrange
console access and a **host-side timed rollback** before testing the
configuration. Verify effective LAN address, default route, bridge ports,
new SSH session and guest connectivity before committing. See the host
READMEs for physical NIC and recovery constraints. Do not blindly activate
a remote bridge change.

## Join credentials and node replacement

The cp-01 server issues new K3s tokens; each joiner's
`/var/lib/rancher/k3s/join-token` is a root-owned mode-0600 **runtime** file
on its persistent `/var`. Never embed the token in Nix, command logs or Git.
Do not delete an existing server's `state.img` or its etcd member identity
to retry a failed join. Inspect service logs and member health first.

For a deliberate fresh node replacement, review the effect on etcd
membership, remove only the retired identity through the documented K3s
procedure, then use the provisioning checks in [restore.md](restore.md)
with that node's fixed declared MAC/name and new state. Do not attempt an
automatic `cluster-reset`. A server-token rotation requires coordinating
the runtime join-token files on all surviving nodes.

For fresh cp-02, the NixOS K3s registration flag supplies its
`node-role.kubernetes.io/control-plane=true:NoSchedule` taint. Existing
Nodes do not update registration taints automatically. After inspecting
current taints, apply the missing taint deliberately if required:

```sh
k3s kubectl taint nodes k8s-cp-02 \
  node-role.kubernetes.io/control-plane=true:NoSchedule --overwrite
```

Check cp-01/cp-03 are uncordoned and free of workload-blocking role taints;
never indiscriminately remove pressure or NotReady taints.

## Workload and infrastructure boundaries

- Change Cilium and Argo CD HelmCharts through their `nix-config` owners.
  Never uninstall Cilium or manage the same release from Argo CD.
- Change the GitOps root and workload manifests in
  [mitschwimmer/argo](https://github.com/mitschwimmer/argo), following
  [gitops.md](gitops.md). Green sync alone is not application acceptance.
- Keep any payload backup/restore separate from cluster recreation.
- Review an explicit resource/data inventory before `nixos-install`,
  Disko, formatting, state-image removal, Helm release deletion or Argo
  pruning. Rebuilding a new cluster must not silently destroy the old one.

## Stage Keepalived API VIP before changing clients

The reserved API VIP is `192.168.1.110/32` on guest `lan0`. The three
server guests declare multicast VRRP (ID 110), BACKUP/no-preemption,
and a local HTTPS `/readyz` check. After two failed checks, weight 0
forces VRRP FAULT; `init_fail` prevents claiming the VIP before it has
twice passed the probe. The worker does not run Keepalived. VRRP runs in
NixOS, not in Kubernetes or Cilium.

**Keep K3s joiners and Cilium on `192.168.1.103:6443` in this stage.**
There is no approved automated host deployment here.

1. Confirm `192.168.1.110` has no other owner, VRRP ID 110 is unused on
   the LAN, and multicast VRRP (IP protocol 112 to 224.0.0.18) traverses
   both physical host bridges and the switch. If multicast is filtered,
   stop and plan unicast VRRP with *observed* peer addresses; do not guess
   cp-02/cp-03's DHCP IPs.
2. Check all three etcd members have quorum, the four Nodes and all Cilium
   agents are healthy, cp-01's direct API works, and recovery access is
   available. Build/evaluate the new guest runners and signed host closures,
   review the diff, and retain each previously booted runner as a GC root.
3. Using [the one-guest procedure](#update-a-guest-safely), update/restart
   **cp-02, then cp-03, then cp-01**, with full etcd/Node/Cilium recovery
   between voters. On each guest inspect:

   ```sh
   systemctl status keepalived --no-pager
   journalctl -u keepalived -b --no-pager
   ip -4 address show dev lan0
   curl -fsSk https://127.0.0.1:6443/readyz
   ```

   The insecure curl checks **local readiness only**. It is not an
   authenticated, TLS-verified client acceptance check.
4. When all three guests are running the new closure, verify **exactly one**
   holds the VIP. From a trusted LAN client inspect the certificate SAN for
   `192.168.1.110`, then exercise a kubeconfig that trusts the cluster CA
   and points at `https://192.168.1.110:6443`. Verify that the two physical
   bridges exchange VRRP adverts; a green local Keepalived unit alone does
   not prove that each peer hears the others.
5. Stop **only Keepalived** on the current VIP holder, without touching
   K3s. Confirm a surviving, ready control plane claims the VIP and the
   authenticated kubeconfig keeps working. Restart Keepalived and check
   that `noPreempt` avoids needless failback. Repeat over the host boundary
   while etcd quorum remains healthy.
6. On split brain, duplicate VIP ownership, unready control planes or
   failed connectivity, **stop Keepalived on all three guests**, keep
   accessing `192.168.1.103:6443` directly and roll back affected guest
   runners if needed. Do not migrate Cilium or K3s joiners yet.

Only after these gates pass, review the separate client-cutover change:
switch joining K3s nodes' `serverAddr` and the existing cp-01-owned Cilium
HelmChart's `k8sServiceHost` to `192.168.1.110`. Never uninstall that
HelmChart. Restart one node at a time and test both Cilium reconnecting
during a cp-01 API outage and access via individual control-plane IPs.
The VIP does **not** fix etcd quorum loss if meawhite fails.
