# Kubernetes MicroVMs

Four NixOS 26.05 guests are defined for Cloud Hypervisor on the two Secure Boot hosts.
All three control-plane guests are enabled in the host configurations:
cp-01/cp-02 on meawhite and cp-03 on meablack. Only cp-01 initializes embedded
etcd. Fresh joiners boot for DHCP/SSH; K3s waits for their runtime token file.
The sole worker, `k8s-worker-02`, is enabled on meawhite for DHCP/SSH and
waits for its runtime token before joining. Keepalived and OpenEBS remain disabled.

On 2026-11-14 the operator confirmed all three control-plane nodes Ready
with reserved addresses cp-01 `192.168.1.103`, cp-02 `192.168.1.104` and
cp-03 `192.168.1.105`. Cilium converged to fully green 3/3 node/endpoint
health from every agent, metrics worked on all nodes, and bidirectional
Pod-IP/Service-DNS HTTP tests passed across the physical-host boundary.
Separate etcdctl inspection was deferred by operator choice. Guest restart
persistence and acceptance of the revised VM resources are still pending.
Cilium 1.20.4 remains owned by cp-01's HelmChart. Its API endpoint stays
`192.168.1.103:6443`; no VIP is implemented.

| Guest | Host | Role | vCPU / GiB RAM | MAC suffix | vsock CID |
| --- | --- | --- | --- | --- | --- |
| k8s-cp-01 | meawhite | server | 4 / 4 | 01 | 1001 |
| k8s-cp-02 | meawhite | server | 2 / 2 | 02 | 1002 |
| k8s-cp-03 | meablack | server | 4 / 4 | 03 | 1003 |
| k8s-worker-02 | meawhite | agent | 4 / 16 | 05 | 1005 |

## Capacity and scheduling

Only cp-02 is reduced from 4096 to 2048 MiB RAM and retains 2 vCPUs. cp-01
and cp-03 retain 4096 MiB and increase from 2 to 4 vCPUs; both keep the K3s
agent enabled and have no registration taint preventing ordinary workloads.
The worker has 16384 MiB and 4 vCPUs. The unused planned worker on meablack
has been removed; the remaining worker keeps MAC suffix 05 and vsock CID 1005.
Do not reassign the retired planned identity (MAC suffix 04, CID 1004).

cp-02 registers with `node-role.kubernetes.io/control-plane=true:NoSchedule`
to reserve its smaller budget for cluster services. K3s registration taints
do not update an existing Node: apply the one-time live taint in the rollout
procedure. cp-01/cp-03 must also be uncordoned and free of role-based scheduling
taints at runtime. Workload requests must leave room for K3s/Cilium and the
other system pods; 4 GiB on a mixed server is not 4 GiB of application capacity.

Before resizing, VM-wide used memory (MemTotal minus MemAvailable) was
1193/988/999 MiB on cp-01/cp-02/cp-03 at 4 GiB each. K3s cgroup anonymous
memory was about 516/383/384 MiB and file-backed memory 501/1685/1680 MiB.
Cgroup totals include cache and overlap with VM-wide measurements. Samples
do not bound startup, upgrade or future workload demand. Validate cp-02 at
2 GiB with normal activity and retain its previous runner for rollback.

| Host | Linux-usable RAM | Declared VM RAM | Remaining for host/overhead/reserve |
| --- | --- | --- | --- |
| meawhite | 30.810 GiB | 22 GiB (4 + 2 + 16) | 8.810 GiB |
| meablack | 62.711 GiB | 4 GiB | 58.711 GiB |

Strata remains outside Kubernetes on meablack. If it needs 60 GB decimal
(55.879 GiB) of system RAM, only about 2.832 GiB remains for the host and
reserve after cp-03. If it needs 60 GiB, the budget does not fit even before
host overhead. Measure/clarify its peak requirement before scheduling added
workloads on cp-03; keep their requests modest until that is resolved.

Apply the resources and worker join through
[operations.md](operations.md#apply-mixed-capacity-and-add-the-worker).

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
cp-02, cp-03 and the worker read a full join token from `/var/lib/rancher/k3s/join-token`
(root:root, 0600), provisioned over SSH outside Nix. With no file the K3s
unit is skipped; empty, symlinked or incorrectly permissioned files fail startup.
The join endpoint is `https://192.168.1.103:6443`, also used by Cilium.
There is no VIP or additional certificate name in this staging step.
Only cp-01 declares the Cilium HelmChart; its DaemonSet also covers the worker
after registration. The worker runs K3s `agent`, not an API/etcd server; it
receives the existing agent token through the same root-owned runtime file.
The default agent token can equal the server token; a separate agent-token
rotation is not part of this rollout.

With three healthy voters, quorum is two and one member may be unavailable
at a time. Check health before maintenance and fully recover each member
before touching another.
Two of three etcd servers are planned for meawhite: loss of meawhite
will lose quorum. The cluster is not symmetric host-HA. The Cilium bootstrap
must converge before expecting Kubernetes nodes to become Ready.

Deployment: [bootstrap.md](bootstrap.md). Operations: [operations.md](operations.md).
Recovery: [recovery.md](recovery.md).
