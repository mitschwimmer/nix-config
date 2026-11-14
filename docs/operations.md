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
sudo systemctl start install-microk8s-cp-01.service
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

cp-02's `/var/lib/rancher/k3s/join-token` stays root:root 0600 on persistent
`/var`. Keep it for subsequent starts; K3s must not start with a missing,
empty or improperly protected file. Provision it through the SSH procedure in
[bootstrap.md](bootstrap.md), never through a Nix derivation or token literal.
A future server-token rotation must also update this runtime file using a
controlled procedure before restarting cp-02. Do not rotate tokens implicitly
as part of expansion or remove a member's state to troubleshoot a join.
