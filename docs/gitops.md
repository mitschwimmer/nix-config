# Argo CD / GitOps ownership

`nix-config` owns NixOS hosts, MicroVMs, K3s and **both bootstrap HelmCharts**
on cp-01: Cilium 1.20.4 (`kubernetes/cilium.nix`) and Argo CD chart 10.18.0,
Argo CD v3.6.1 (`kubernetes/argocd.nix`). The K3s Helm Controller reconciles
these releases. Do **not** duplicate their ownership with Argo CD or a
second Helm install. Removing a K3s HelmChart can uninstall its release.

[mitschwimmer/argo](https://github.com/mitschwimmer/argo) owns the
`homelab` root Application/AppProject, future child Applications, projects
and workload manifests. It is currently a public GitOps repository with an
initially empty application set. New workloads belong there, not in ad hoc
`kubectl apply` commands in `nix-config`.

## Fresh-cluster sequence

Follow [restore.md](restore.md) for the complete sequence. In short:

1. cp-01 initializes K3s. Its K3s HelmCharts introduce Cilium and Argo CD.
2. Cilium enables the nodes. Argo CD's core pods are pinned to
   `k8s-worker-02`, so they can be Pending until that worker joins.
3. After worker-02 joins and Argo CD's CRDs/controller are ready, apply
   `argo/clusters/homelab/bootstrap.yaml` **once** to the new cluster.
4. Argo CD then self-manages its root objects and reconciles `main`. Only
   explicit reviews/commits to `argo` should change Argo-owned manifests.

The root is automated/self-healing but has `prune: false`. Deletions and
destructive changes need separate review. The root's bootstrap project is
narrowly scoped, but anyone able to modify root Apps/AppProjects can grant
further cluster privileges; treat that repository as administrative.

## Access and credentials

The Argo CD API/UI service is internal ClusterIP, with no ingress, public
hostname or SSO. Access through a trusted SSH tunnel via cp-01:

```sh
ssh -L 8080:127.0.0.1:8080 root@192.168.1.103 \
  'k3s kubectl -n argocd port-forward --address 127.0.0.1 svc/argocd-server 8080:443'
```

Use `https://localhost:8080` and the newly generated administrator credential
from `argocd-initial-admin-secret`, then change it. Do not paste the password
into shared logs or Git. A fresh rebuild deliberately does not restore the
old administrator password or Kubernetes Secret identity.

No plaintext secrets belong in either public repository. Before adopting
a SOPS/age or other GitOps secret workflow, implement off-host recovery of
its decryption key and update [backup-backlog.md](backup-backlog.md).
