# Argo CD and GitOps

## Ownership

`nix-config` owns the physical hosts, MicroVMs, K3s and two bootstrap
HelmCharts: Cilium and Argo CD. Only cp-01 writes their K3s manifests.
K3s's Helm Controller installs and reconciles Argo CD chart 10.18.0
(Argo CD v3.6.1) from the official Argo Helm repository.

[mitschwimmer/argo](https://github.com/mitschwimmer/argo) owns the `homelab`
root Application, its bootstrap project and subsequent workload Applications,
projects and manifests. This public repository needs no read credential.
Never commit plaintext secrets. Secrets provisioning needs an explicit
runtime/encryption mechanism before adding a workload that requires one.

Do not let an Argo CD Application also manage the existing Argo CD or Cilium
Helm release/resources. A later ownership handover must be reviewed separately;
simply deleting a K3s HelmChart may uninstall its release. Future in-cluster
application/configuration changes belong in `argo`; host/guest/K3s changes
continue through Nix. Bootstrap resources remain the deliberate exception.

## Initial footprint and access

The four core components (application controller, repo server, API/UI server
and standalone Redis) each have one replica, scheduled on worker-02 through
a global hostname node selector. Their combined requests are 300m CPU and
704 MiB RAM. The controller/repo server each have a 1 GiB memory limit;
server/Redis each have 256 MiB. These are initial budgets to observe, not
measured peak requirements. No CPU limits are set.

Dex, notifications and Redis HA are disabled. The chart keeps the
ApplicationSet Deployment at zero replicas for the initial app-of-apps setup.
A temporary Redis-secret initialization hook also requests 50m CPU/64 MiB
with a 256 MiB memory limit. Its completed pod may remain for diagnostics. No PVC, ingress, LoadBalancer or NodePort is
required. The API/UI service is ClusterIP and retains TLS; access starts
through an SSH portforward. The configured UI URL is https://localhost:8080.
There is no invented LAN address, public domain, VIP, SSO or storage backend.
This is a single-worker Argo CD installation, not an HA service. If the worker
is down, Git reconciliation/UI pause while existing Kubernetes workloads
continue independently.

## Install the bootstrap

1. Merge the GitOps repository's initial structure first. It contains a root
   Application/AppProject and a Kustomization with no deployed workloads.
2. Evaluate `tests/microvms.nix`, cp-01's declared runner and the meawhite
   host/secure variant. Build the cp-01 runner and meawhite-secure closure.
   See [bootstrap.md](bootstrap.md) and [operations.md](operations.md).
3. Confirm all four Nodes and Cilium are healthy and worker-02 is Ready.
   Preserve cp-01's booted runner as a GC root before host deployment:

   ```sh
   # On meawhite, before deploying the new host closure:
   sudo nix-store --realise "$(readlink -f /var/lib/microvms/k8s-cp-01/booted)" \
     --add-root /nix/var/nix/gcroots/k8s-cp-01-before-argocd
   ```

4. Deploy meawhite-secure from the reviewed checkout. Existing VMs keep
   `restartIfChanged = false`; restart only cp-01 after installing its runner:

   ```sh
   # On meawhite, after deploying the host:
   sudo systemctl start install-microvm-k8s-cp-01.service
   sudo systemctl restart microvm@k8s-cp-01
   ```

   Preserve quorum and wait for all server/Cilium checks to recover. cp-01
   remains Cilium's fixed API endpoint; this restart may interrupt API access.
   Do not restart another server during the operation.
5. On cp-01, inspect the Helm installation and wait until its resources exist:

   ```sh
   k3s kubectl -n kube-system get helmcharts,jobs,pods
   k3s kubectl -n argocd get deploy,statefulset,pods,svc
   ```

   Then wait for the CRDs and Argo pods:

   ```sh
   k3s kubectl wait --for=condition=Established --timeout=300s \
     crd/applications.argoproj.io crd/appprojects.argoproj.io
   k3s kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
   k3s kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s
   k3s kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
   k3s kubectl -n argocd rollout status deployment/argocd-redis --timeout=300s
   ```

   Expect four running Argo pods on the worker and a ClusterIP server service.
   The completed Redis-secret hook is not a readiness failure; do not wait for
   all pods indiscriminately, because completed Job pods are not Ready. A failed
   Helm install has `failurePolicy: abort`; inspect its job/events rather than
   installing another Helm release. Do not copy generated admin secrets into
   logs or Git. Cilium must retain its original HelmChart owner.

## Connect the root repository

Only after Argo CD and its CRDs are ready, clone the `argo` repository and
apply `clusters/homelab/bootstrap.yaml` once, as its README describes. This
explicit initial apply avoids racing Application CRDs during the Helm install.
It creates the root AppProject/Application, not workloads. Argo CD then owns
and reconciles those objects from Git, including the root's own definition.
There is no Helm/K3s ownership of this root Application.

The bootstrap project permits only Application and AppProject objects in the
Argo namespace from the exact GitOps repo. It permits no cluster-scoped
resources. Writers of that repo are nevertheless trusted cluster admins:
root Application/project definitions can grant child applications privileges.
Future workloads receive their own narrowly scoped projects.

The root automatically syncs and self-heals from `main`, with automated
pruning disabled and no cascading-delete finalizer. Deletions therefore
require an explicit decision; child Applications choose their own pruning
policy. Do not routinely use kubectl to edit Git-managed resources afterward.

On cp-01, verify:

```sh
k3s kubectl -n argocd get applications,appprojects
k3s kubectl -n argocd get application homelab \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'
```

Expect `Synced Healthy`. No example workloads are installed by the initial
GitOps structure. A later reviewed workload addition tests automatic sync.

## Local UI

On the workstation, set `CP01_IP` to the actual server address and keep this
SSH session running:

```sh
ssh -L 8080:127.0.0.1:8080 root@"$CP01_IP" \
  'k3s kubectl -n argocd port-forward --address 127.0.0.1 svc/argocd-server 8080:443'
```

Open https://localhost:8080. Argo CD initially uses a self-signed certificate.
Read the generated initial admin password only in your own trusted terminal,
not in shared command output:

```sh
# On cp-01; do not paste the resulting password into chat or Git.
k3s kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Log in as `admin` and change the initial password through the UI. Ingress,
public URL, SSO and backup/recovery remain separate configuration work.

References: [K3s Helm Controller](https://docs.k3s.io/add-ons/helm),
[Argo CD declarative setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/),
[Argo Helm chart](https://github.com/argoproj/argo-helm/tree/argo-cd-10.18.0/charts/argo-cd).
