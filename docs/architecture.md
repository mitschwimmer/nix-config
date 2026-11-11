# Kubernetes on NixOS MicroVMs

## Implementation status

This is a staged NixOS MicroVM Kubernetes bootstrap. Both hosts retain their
existing OS, disk layouts and Secure Boot variants. There are five cluster
guest definitions and a smaller optional `k8s-test` guest. The configuration
enables only `k8s-cp-01` on meawhite as an initial K3s embedded-etcd server;
all other guests remain inactive. The K3s runtime has **not** been observed or
accepted on real hardware. Keepalived, Cilium and OpenEBS are not installed.

The former Talos/NixVirt integration is retired. Shut the old guest down
before activating this host configuration; see [bootstrap.md](bootstrap.md).

## Repository layout

Retain root-level host directories and explicit imports. Shared host behavior
lives in `profiles/`; the cluster spans two hosts, so its inventory and guest
configuration live together under `kubernetes/`.

| Path | Responsibility |
| --- | --- |
| `flake.nix`, `flake.lock` | Host/guest composition and pinned dependencies |
| `meablack/microvms.nix`, `meawhite/microvms.nix` | Local activation, guest selection, bridge and uplink settings |
| `profiles/microvm-host.nix` | Declarative guest lifecycle and TAP attachment |
| `kubernetes/nodes.nix` | Stable names/MACs/vsock CIDs, placement and resource allocation |
| `kubernetes/guest.nix`, `kubernetes/k3s.nix` | Shared guest OS and first-server K3s bootstrap |
| `tests/microvms.nix` | Evaluation of topology, identities, storage and enabled host paths |
| `docs/` | Cluster bootstrap, operation, recovery and acceptance records |

Add coherent server, agent, Keepalived and worker-storage modules under
`kubernetes/` as those phases are implemented. Component manifests belong in
`kubernetes/cilium/`, `kubernetes/gateway/` and `kubernetes/openebs/` once tested.
Do not create a second flake, move installed hosts into `hosts/`, or duplicate
five guest files merely to hold different names and resource values.

## Placement and resources

| Guest | Host | Intended role | vCPU | RAM | State image | New MAC |
| --- | --- | --- | ---: | ---: | ---: | --- |
| k8s-cp-01 | meawhite | K3s server/etcd | 2 | 4 GiB | 64 GiB | 02:6b:38:00:00:01 |
| k8s-cp-02 | meawhite | K3s server/etcd | 2 | 4 GiB | 64 GiB | 02:6b:38:00:00:02 |
| k8s-cp-03 | meablack | K3s server/etcd | 2 | 4 GiB | 64 GiB | 02:6b:38:00:00:03 |
| k8s-worker-01 | meablack | K3s agent | 4 | 8 GiB | 64 GiB | 02:6b:38:00:00:04 |
| k8s-worker-02 | meawhite | K3s agent | 4 | 8 GiB | 64 GiB | 02:6b:38:00:00:05 |
| k8s-test | meawhite | Foundation acceptance only | 1 | 1 GiB | 4 GiB | 02:6b:38:00:00:fe |

These MACs are newly allocated configuration values, not observed leases.
Check uniqueness and create DHCP reservations before deploying cluster nodes.
Each guest also has an explicit, unique vsock CID (1001-1005 for cluster nodes,
1099 for k8s-test). Values 0-2 are reserved. These enable Cloud Hypervisor's
systemd-notify readiness path and must not collide with other MicroVMs running
on the same physical host.
Review resource allocations against host capacity and meablack's inference
workload. Image sizes are sparse capacity limits, not reserved physical space.

The target has two of three etcd members on meawhite. Once K3s is installed,
loss of meablack must leave two members and a working API; loss of meawhite
will lose quorum. This layout supports rolling maintenance, not symmetric
physical-host HA.

## Network and storage boundaries

Known LAN: `192.168.1.0/24`. Hosts: `meablack.localdomain` at `192.168.1.28`
and `meawhite.localdomain` at `192.168.1.137`. meawhite already uses `br0`,
physical NIC `enp129s0`, and bridge MAC `9c:6b:00:96:f2:10`. meablack's
wired NIC and MAC still need observation. Host settings remain configurable.

Each guest has one VirtIO TAP NIC named `<guest>` on the host and `lan0`
inside the guest. networkd manages only the selected TAPs on the host. Host
bridge/DHCP ownership stays with the existing networking backend. Guests use
IPv4 DHCP with a MAC client identifier. No NAT or guest overlay is configured.

Cloud Hypervisor boots the normal pinned NixOS kernel and a reproducible
read-only Nix store image; `/` is temporary. There is no shared host store and
no virtiofs daemon. Each guest's raw ext4 `state.img` mounts at `/var` and
contains its journal, SSH host key and future K3s/containerd/kubelet data.
The upstream module gives each hostname a deterministic machine ID.

Images live in `/var/lib/microvms/<guest>/`, owned by the upstream `microvm`
user and `kvm` group. The VM service uses umask 0077 when creating state images.
Only an absent image is formatted. Rebuilds do not resize or reformat it.
Disk ordering is an immutable store disk followed by the state disk; `/var`
uses the `vm-state` filesystem label rather than relying on a drive letter.

Worker OpenEBS disks and guest LVM initialization are deferred to phase 4.
They must be separate raw, unformatted data images with no host thin pool.
The bootstrap K3s module redirects `/etc/rancher/node` (node password) to
`/var/lib/rancher/node` using tmpfiles before the service starts. Verify the
link and password persistence on the running guest. The first server generates
its own bootstrap token under persistent `/var/lib/rancher/k3s/server/token`;
keep an encrypted off-host copy. Do not provision secrets through files
embedded in the store image. sops-nix token delivery is still required before
adding other servers or agents. Before LVM, address its persistent configuration
and metadata backup paths.

## Remaining phases

1. Boot k8s-cp-01 and verify KVM, LAN/DNS/time, etcd, API, persistent node
   password and K3s token across restarts. The operator elected to skip k8s-test;
   runtime acceptance on the real guest is still mandatory. Test the meablack
   bridge separately with console/rollback access before enabling its guests.
2. Add K3s joining-server/agent configuration, secure runtime token delivery
   and a reserved API VIP/DNS name. Join cp-02/cp-03, then workers, one at a
   time. Add readiness-based Keepalived without depending on Cilium.
3. Pin and validate Cilium native routing, Kubernetes PodCIDR allocation,
   kube-proxy replacement, LB IPAM/L2 Announcements and Gateway API/Envoy.
4. Add worker LVM thin pools, OpenEBS Local PV LVM, snapshot CRDs/controller
   and local snapshot restoration tests. These volumes are local, not replicated.
5. Exercise single-node upgrades, API failover, meablack loss/recovery and
   etcd snapshots; expand the operations and recovery runbooks with observed
   commands/results. Off-node backups and automated upgrades remain excluded.

## Source interfaces checked

microvm.nix is pinned in `flake.lock`; its NixOS host module provides
`evaluatedConfig`, `restartIfChanged`, state directories and systemd units.
Its Cloud Hypervisor runner supports the selected VirtIO TAP and raw block
devices. See [host documentation](https://microvm-nix.github.io/microvm.nix/host.html)
and [options](https://microvm-nix.github.io/microvm.nix/options.html).

The pinned NixOS 26.05 K3s interface is in
`nixos/modules/services/cluster/rancher/k3s.nix` and the shared Rancher module,
not `services/cluster/k3s/default.nix`. It exposes `clusterInit`, `serverAddr`,
`tokenFile`, `disable`, `extraFlags` and `configPath`. Recheck the locked sources
when implementing K3s; interface inspection does not prove runtime success.
