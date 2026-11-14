# Kubernetes MicroVMs

Five NixOS 26.05 guests are defined for Cloud Hypervisor on the two Secure Boot hosts.
All three control-plane guests are enabled in the host configurations:
cp-01/cp-02 on meawhite and cp-03 on meablack. Only cp-01 initializes embedded
etcd. Fresh joiners boot for DHCP/SSH; K3s waits for their runtime token file.
The two workers, Keepalived and OpenEBS remain disabled.

On 2026-11-14 the operator confirmed all three control-plane nodes Ready
with reserved addresses cp-01 `192.168.1.103`, cp-02 `192.168.1.104` and
cp-03 `192.168.1.105`. Cilium converged to fully green 3/3 node/endpoint
health from every agent, metrics worked on all nodes, and bidirectional
Pod-IP/Service-DNS HTTP tests passed across the physical-host boundary.
Separate etcdctl inspection was deferred by operator choice. Guest restart
persistence and acceptance of the reduced RAM allocation are still pending.
Cilium 1.20.4 remains owned by cp-01's HelmChart. Its API endpoint stays
`192.168.1.103:6443`; no VIP is implemented.

| Guest | Host | Role | vCPU / GiB RAM | MAC suffix | vsock CID |
| --- | --- | --- | --- | --- | --- |
| k8s-cp-01 | meawhite | server | 2 / 2 | 01 | 1001 |
| k8s-cp-02 | meawhite | server | 2 / 2 | 02 | 1002 |
| k8s-cp-03 | meablack | server | 2 / 2 | 03 | 1003 |
| k8s-worker-01 | meablack | agent | 4 / 8 | 04 | 1004 |
| k8s-worker-02 | meawhite | agent | 4 / 8 | 05 | 1005 |

## Memory budget

Each control-plane VM is declared with 2048 MiB RAM and 2 vCPUs, reduced from
4096 MiB. This is a trial target, not a measured peak requirement. It saves
4 GiB of configured VM RAM on meawhite and 2 GiB on meablack. Runtime takes
up the new limit only after installing the updated runner and restarting
one guest at a time; follow [operations.md](operations.md#reduce-control-plane-ram).

Before reduction, the operator measured VM-wide used memory (MemTotal minus
MemAvailable) of 1193/988/999 MiB for cp-01/cp-02/cp-03. K3s cgroup anonymous
memory was approximately 516/383/384 MiB and file-backed memory 501/1685/1680
MiB. Cgroup totals include cache and overlap with the VM-wide measurements;
do not add them. These are current samples, not bounds on startup, upgrade
or future workload demand. Retain 2 vCPUs and validate memory pressure under
normal activity before applying the reduction to the next server.

The physical hosts expose 30.810 GiB (meawhite) and 62.711 GiB (meablack) of
Linux-usable RAM. After the declared control-plane allocations, 26.810 GiB
and 60.711 GiB respectively remain for the host, hypervisor overhead,
workloads and reserve. Worker resources/placement are not changed here.
Strata's stated 60 GB system-RAM requirement on meablack must be clarified:
60 GB decimal is about 55.879 GiB, whereas 60 GiB leaves only 0.711 GiB for
the host after cp-03's 2 GiB allocation. No additional worker is activated.

MAC prefix: `02:6b:38:00:00:`. Each guest has a 64 GiB sparse raw ext4
`/var` image under `/var/lib/microvms/<guest>/`; its root and Nix store
are rebuilt from Nix. Preserve the state image, hostname, MAC and vsock CID.
All guests use DHCP on a bridged TAP. A new guest may boot without a
reservation to obtain its first lease. Reserve the observed address before
provisioning its K3s join credential; never guess a free LAN address.

meawhite already bridges `enp129s0` through `br0` (host `192.168.1.137`).
meablack's observed uplink is `eno1`, MAC `24:4b:fe:03:c4:69`, with host IP
`192.168.1.28/24` and gateway `192.168.1.1`. The declared bridge moves host
DHCP to `br0` and retains that MAC; the physical uplink no longer runs DHCP.
The first cutover used the timed rollback procedure before provisioning
cp-03's token; the operator confirmed host addressing/routes and both bridge
ports before committing the host configuration. The hosts and guests remain on the same L2 LAN.

The first server generates a K3s token under
`/var/lib/rancher/k3s/server/token`. Its `/etc/rancher/node` is linked to
persistent `/var/lib/rancher/node`. Keep the token encrypted off-host.
cp-02 and cp-03 read the full server token from `/var/lib/rancher/k3s/join-token`
(root:root, 0600), provisioned over SSH outside Nix. With no file the K3s
unit is skipped; empty, symlinked or incorrectly permissioned files fail startup.
The join endpoint is `https://192.168.1.103:6443`, also used by Cilium.
There is no VIP or additional certificate name in this staging step.
Only cp-01 declares the Cilium HelmChart; its DaemonSet extends to cp-02 and, after joining, cp-03.
The worker guests still have K3s disabled.

With three healthy voters, quorum is two and one member may be unavailable
at a time. Check health before maintenance and fully recover each member
before touching another.
Two of three etcd servers are planned for meawhite: loss of meawhite
will lose quorum. The cluster is not symmetric host-HA. The Cilium bootstrap
must converge before expecting Kubernetes nodes to become Ready.

Deployment: [bootstrap.md](bootstrap.md). Operations: [operations.md](operations.md).
Recovery: [recovery.md](recovery.md).
