# Kubernetes MicroVMs

Five NixOS 26.05 guests run under Cloud Hypervisor on the two Secure Boot hosts.
Only `k8s-cp-01` is enabled, on meawhite; it initializes K3s embedded etcd.
cp-02 has a join configuration but is not enabled on the host.
The other four guests, Keepalived and OpenEBS are not deployed.
Cilium 1.20.4 is declared via the K3s HelmChart bootstrap resource; runtime
acceptance on cp-01 was reported on 2026-11-13; two-node acceptance is pending.
Pin the DHCP address 192.168.1.103 until an API VIP
replaces it in the Cilium configuration.

| Guest | Host | Role | vCPU / GiB RAM | MAC suffix | vsock CID |
| --- | --- | --- | --- | --- | --- |
| k8s-cp-01 | meawhite | server | 2 / 4 | 01 | 1001 |
| k8s-cp-02 | meawhite | server | 2 / 4 | 02 | 1002 |
| k8s-cp-03 | meablack | server | 2 / 4 | 03 | 1003 |
| k8s-worker-01 | meablack | agent | 4 / 8 | 04 | 1004 |
| k8s-worker-02 | meawhite | agent | 4 / 8 | 05 | 1005 |

MAC prefix: `02:6b:38:00:00:`. Each guest has a 64 GiB sparse raw ext4
`/var` image under `/var/lib/microvms/<guest>/`; its root and Nix store
are rebuilt from Nix. Preserve the state image, hostname, MAC and vsock CID.
All guests use DHCP on a bridged TAP; reserve their leases before activation.

meawhite already bridges `enp129s0` through `br0` (host `192.168.1.137`).
Before enabling MicroVMs on meablack (`192.168.1.28`), discover its wired
interface/MAC and migrate DHCP to `br0` with console or timed rollback.

The first server generates a K3s token under
`/var/lib/rancher/k3s/server/token`. Its `/etc/rancher/node` is linked to
persistent `/var/lib/rancher/node`. Keep the token encrypted off-host.
cp-02 reads the full server token from `/var/lib/rancher/k3s/join-token`
(root:root, 0600), provisioned over SSH outside Nix. With no file its K3s
unit is skipped; empty, symlinked or incorrectly permissioned files fail startup.
The join endpoint is `https://192.168.1.103:6443`, also used by Cilium.
There is no VIP or additional certificate name in this staging step.
Only cp-01 declares the Cilium HelmChart; its DaemonSet extends to cp-02.
Other guests still have K3s disabled.

At two voting members, quorum is two: neither member may fail. This is a
transitional expansion stage, not HA. Plan cp-03 promptly.
Two of three etcd servers are planned for meawhite: loss of meawhite
will lose quorum. The cluster is not symmetric host-HA. The Cilium bootstrap
must converge before expecting Kubernetes nodes to become Ready.

Deployment: [bootstrap.md](bootstrap.md). Operations: [operations.md](operations.md).
Recovery: [recovery.md](recovery.md).
