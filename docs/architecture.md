# Kubernetes MicroVM architecture

This is the **declared steady-state topology**, not a rollout history.
To rebuild it, follow [restore.md](restore.md). Source of truth:
`kubernetes/nodes.nix`, `kubernetes/guest.nix`, `kubernetes/k3s.nix`,
`kubernetes/cilium.nix`, `kubernetes/argocd.nix` and the host MicroVM modules.

## Physical hosts and guests

| Host | Guest | Role | vCPU | RAM |
| --- | --- | --- | ---: | ---: |
| `meawhite` | `k8s-cp-01` | K3s server, embedded-etcd initiator | 4 | 4 GiB |
| `meawhite` | `k8s-cp-02` | K3s server, `NoSchedule` | 2 | 2 GiB |
| `meawhite` | `k8s-worker-02` | K3s agent | 4 | 16 GiB |
| `meablack` | `k8s-cp-03` | K3s server | 4 | 4 GiB |

Cloud Hypervisor guests have stable identities in `kubernetes/nodes.nix`:
MACs, vsock CIDs, names and 64 GiB sparse ext4 `/var` volumes under
`/var/lib/microvms/<guest>/state.img`. Their read-only Nix store/root is
rebuilt from the flake. For a **fresh** rebuild these state images are
recreated; for ordinary operations never delete them.

The hosts bridge guest TAP interfaces to `br0`. `meawhite` retains
`192.168.1.137` and `meablack` `192.168.1.28`; guests use DHCP. cp-01's
MAC `02:6b:38:00:00:01` must be reserved at `192.168.1.103` because K3s
and Cilium use this API endpoint directly. There is **no VIP**. The
retired candidate worker identity with MAC suffix 04/CID 1004 is not reused.

## Ownership and availability

- NixOS owns both physical hosts, MicroVM declarations, K3s and cp-01's
  Cilium/Argo CD K3s HelmCharts.
- K3s creates a **new** embedded-etcd cluster on cp-01; cp-02 and cp-03 join
  as servers, worker-02 as agent. With three voters, one member can fail,
  but loss of `meawhite` removes **two**, so this is **not** host-level HA.
- K3s disables Flannel, kube-proxy, Traefik, ServiceLB and local-storage
  where appropriate. Cilium 1.20.4 provides native routing and kube-proxy
  replacement with Pod CIDR `10.42.0.0/16`. The K3s service CIDR is
  `10.43.0.0/16`.
- cp-02 is reserved for cluster services by a registration taint. cp-01 and
  cp-03 can also run ordinary workloads, subject to host memory headroom
  (in particular Strata's separate host budget on `meablack`).
- Argo CD chart 10.18.0 (Argo CD v3.6.1) is K3s-owned and scheduled on
  worker-02; it has a private ClusterIP UI, no PVC and no high availability.
  `mitschwimmer/argo` owns the root Application and workload configuration.
  See [gitops.md](gitops.md).

New K3s certificates, server tokens, etcd membership and guest SSH identities
are disposable under the [fresh-rebuild contract](restore.md). External
Secure Boot keys, disk unlock/recovery material and router settings are
tracked in [backup-backlog.md](backup-backlog.md). Application data backup
is a separate responsibility.
