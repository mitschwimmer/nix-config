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

## Kubernetes API VIP

The control-plane guests use Keepalived to serve `192.168.1.110:6443` on
`lan0` (VRRP ID 110). K3s joiners and Cilium use this address; cp-01's
`192.168.1.103:6443` remains available for direct recovery. Keepalived
depends on the **local** kube-apiserver readiness endpoint, not a client
certificate or the Cilium datapath.

On each control-plane guest, check `ip -4 addr show dev lan0` and
`systemctl status keepalived`. Exactly one guest must hold
`192.168.1.110/32`. Check local readiness with
`curl -fsSk https://127.0.0.1:6444/readyz` (expected: `ok`), then verify
an authenticated `k3s kubectl --server=https://192.168.1.110:6443 get nodes`.
To test failover, stop **only** Keepalived on the current VIP holder,
confirm another ready server takes ownership and the VIP API still works,
then start Keepalived again. Check etcd quorum throughout; do not take a
second voter down.

If the VIP disappears or multiple servers claim it, check local readiness,
Keepalived journals and multicast VRRP delivery (IP protocol 112) across
both host bridges before restarting any other control-plane nodes.
On duplicate ownership, stop Keepalived on all three until the conflict is
resolved, and use a server's direct API address for recovery. The VIP does
**not** compensate for the loss of two etcd voters when `meawhite` fails.

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
