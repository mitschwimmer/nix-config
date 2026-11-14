# Recreate the Kubernetes homelab

This is the **canonical fresh-rebuild procedure** for the Kubernetes cluster
declared in [nix-config](https://github.com/mitschwimmer/nix-config) and
[argo](https://github.com/mitschwimmer/argo). Use the current, reviewed Git
configuration and `flake.lock` to construct an equivalent working cluster.
This is **not** point-in-time recovery: Kubernetes object UIDs, etcd membership,
node/SSH identities, generated passwords and K3s tokens may all change.

**Scope:** physical NixOS hosts, Cloud Hypervisor MicroVMs, K3s, Cilium, Argo CD
and all workloads subsequently declared in `argo`. Payload/user-data backup and
restore are a **separate procedure**. Do not assume that reinstalling workloads
restores their data. Record any external credentials needed by future workloads
in [backup-backlog.md](backup-backlog.md).

This document describes a *new deployment on prepared or replaced hardware*.
It is **not safe to run verbatim against the active cluster**. Inspect existing
data and obtain authorization before formatting a disk, removing a state image
or replacing cluster membership. For routine changes and non-destructive repair
see [operations.md](operations.md).

## Target from Git

`kubernetes/nodes.nix` and the two physical-host modules define the complete
guest inventory. Each guest has a separate sparse 64 GiB ext4 `/var` state image.

| Guest | Physical host | K3s role | vCPU | RAM | MAC | vsock CID |
| --- | --- | --- | ---: | ---: | --- | ---: |
| `k8s-cp-01` | `meawhite` | server, cluster initiator | 4 | 4 GiB | `02:6b:38:00:00:01` | 1001 |
| `k8s-cp-02` | `meawhite` | server, tainted `NoSchedule` | 2 | 2 GiB | `02:6b:38:00:00:02` | 1002 |
| `k8s-cp-03` | `meablack` | server | 4 | 4 GiB | `02:6b:38:00:00:03` | 1003 |
| `k8s-worker-02` | `meawhite` | agent | 4 | 16 GiB | `02:6b:38:00:00:05` | 1005 |

- Physical-host LAN addresses: `meawhite` `192.168.1.137` and `meablack`
  `192.168.1.28`. The guests use bridged DHCP.
- **Reserve `192.168.1.103` for cp-01** (MAC above) before its first boot,
  for direct recovery access. Keepalived declares the reserved API VIP
  `192.168.1.110/32` on all three server guests, and K3s joiners/Cilium
  now use this address. Verify VRRP ID 110 is unused and multicast crosses
  both host bridges before activation. On a fresh install, cp-01's local
  K3s `/readyz` must pass so Keepalived can hold the VIP **before** the
  cp-01-owned Cilium bootstrap contacts it. If this fails, use
  [operations.md](operations.md) and local cp-01 recovery; do not silently
  change the installation sequence or add a second Cilium owner.
- K3s uses three embedded-etcd servers; losing `meawhite` loses two voters.
  Cilium 1.20.4 and Argo CD chart 10.18.0 are bootstrapped by *cp-01's
  K3s Helm Controller*, not by GitOps.
- Argo CD is scheduled onto `k8s-worker-02`. It has no PVC and may remain
  Pending until the worker joins. The root `homelab` Application is in `argo`
  and must be applied once after Argo CD is ready.
- The current GitOps repository has an initially empty workload set. Future
  committed Applications and their dependencies are restored from that repo.

For design/ownership rather than commands see [architecture.md](architecture.md)
and [gitops.md](gitops.md). The declared files are authoritative if a summary
and the code disagree.

## 0. Prepare a clean rebuild

1. Obtain access to both physical machines through a **physical console** and
   a trusted workstation with Nix, Git, SSH and the relevant private SSH key.
   Confirm the off-host Secure Boot/recovery material in
   [backup-backlog.md](backup-backlog.md); do not place secrets in Git, the
   Nix store or command logs.
2. Check out the intended current `main` of **both repositories**, including
   `nix-config/flake.lock`. This runbook intentionally does not pin an
   historical Git commit or require restoring the old cluster's token.
3. Reestablish LAN routing, the physical-host DHCP reservations, cp-01's
   `192.168.1.103` reservation and the **non-DHCP** `192.168.1.110` VIP
   reservation. Record *observed* DHCP leases for cp-02, cp-03 and worker-02
   by MAC. Verify VRRP multicast across both host bridges, VRID 110
   uniqueness, interface names and hardware IDs before deploying K3s.
4. Decide explicitly whether the original disks or MicroVM `state.img` files
   contain anything to salvage. **Stop here** if they do. A clean deployment
   uses fresh state images; it must never accidentally boot an old guest that
   can rejoin the previous cluster.
5. Verify enough free space under `/var/lib/microvms` on both hosts. The
   guest images are sparse but still require real space as they fill.

The unattended installers described by
[meawhite/README.md](../meawhite/README.md) and
[meablack/README.md](../meablack/README.md) **erase target disks**.
They are for an explicitly approved blank-machine installation, not rescue.
Their generated installer images also contain LUKS passphrases; keep the build
machine, images and USB media private. For a repair that must preserve disks,
use a normal rescue environment and the host-specific recovery instructions.

## 1. Establish the physical hosts

Rebuild/reinstall `meawhite` and `meablack` following their own READMEs.
The installed, signed NixOS configurations are `meawhite-secure` and
`meablack-secure`, not their unsigned installer profiles. Recover the existing
`/var/lib/sbctl` signing keys when retaining the enrolled firmware trust;
otherwise set up and enroll new keys at the console. Verify signed boot,
LUKS unlock and TPM PCR-7 binding after the final Secure Boot policy is active.

- On `meawhite`, verify `br0`, `enp129s0`, its retained LAN identity,
  `/`, `/data` and a healthy mdadm RAID1 where applicable.
- On `meablack`, verify `br0`, its physical uplink `eno1`, host address and
  default route. A first bridge activation can cut SSH: use console access or
  a timed rollback; **never blindly switch networking remotely**.
- On both hosts, confirm SSH login, the effective NixOS generation, KVM,
  available disk space and stable DHCP/router settings before creating guests.

From a clean checkout of `nix-config` on the workstation:

```sh
git diff --check
nix eval --no-update-lock-file --impure --json --expr '
  import ./tests/microvms.nix { flake = builtins.getFlake (toString ./.); }
'
nix build --no-update-lock-file --no-link \
  .#nixosConfigurations.k8s-cp-01.config.microvm.declaredRunner \
  .#nixosConfigurations.k8s-cp-02.config.microvm.declaredRunner \
  .#nixosConfigurations.k8s-cp-03.config.microvm.declaredRunner \
  .#nixosConfigurations.k8s-worker-02.config.microvm.declaredRunner
nix build --no-update-lock-file --no-link \
  .#nixosConfigurations.meawhite-secure.config.system.build.toplevel \
  .#nixosConfigurations.meablack-secure.config.system.build.toplevel
```

Once host networking and local recovery are safe, activate the reviewed
closures, for example from the workstation:

```sh
nixos-rebuild switch --flake .#meawhite-secure --target-host root@192.168.1.137
nixos-rebuild switch --flake .#meablack-secure --target-host root@192.168.1.28
```

If host installation has already enabled the guests, do **not** attempt to
create them again. `services.kubernetesMicrovms.guests` starts the declared
guests and `restartIfChanged = false` avoids mass restarts on later host
rebuilds.

## 2. Initialize cp-01 and Cilium

For a **fresh** deployment, cp-01 boots with an empty `/var`, generates a
new K3s server token, initializes embedded etcd and installs its two K3s
HelmCharts. The other guests may boot for DHCP/SSH but K3s is intentionally
inactive until each receives its new join token.

Verify cp-01 receives `192.168.1.103`, has a persistent `/var`, and that
Keepalived takes `192.168.1.110/32` after the local K3s API passes `/readyz`.
Confirm the VIP is reachable from a trusted LAN machine before the Cilium
HelmChart relies on it. If the API never becomes ready or the VIP is absent,
do **not** switch Cilium ownership: diagnose Keepalived/K3s from the direct
cp-01 IP and console. Verify the new SSH host fingerprint via a trusted
channel before accepting it; regenerated host keys are expected. Then check:

```sh
ssh root@192.168.1.103 'findmnt /var; systemctl status k3s --no-pager'
ssh root@192.168.1.103 'k3s kubectl get nodes -o wide'
ssh root@192.168.1.103 'k3s kubectl -n kube-system get helmcharts,jobs,pods'
ssh root@192.168.1.103 'k3s kubectl -n kube-system rollout status ds/cilium --timeout=10m'
```

Wait for cp-01, Cilium, CoreDNS and metrics-server to settle. A freshly
started node can initially be `NotReady` until its CNI becomes operational.
Do not reinstall or create a second Cilium Helm release. **Do not wait for
Argo CD workloads at this stage**: the chart selects the not-yet-joined worker.

## 3. Join cp-02, cp-03, then worker-02

For each joiner, use the router to obtain and reserve its **observed** IP.
On that guest, confirm the hostname/MAC, empty persistent `/var`, verified
SSH host key and inactive K3s (`ConditionPathExists` is unmet because
`/var/lib/rancher/k3s/join-token` does not exist). Do not overwrite a token
or etcd data on a guest that was already joined.

From the trusted workstation, using Bash and actual reserved guest addresses,
run the following once per fresh joiner. The full token is transferred between
authenticated hosts via the workstation; no plaintext workstation file is
created. Keep shell tracing off.

```bash
set -euo pipefail
set +x

join_guest() {
  local JOIN_IP="$1" TOKEN_SOURCE="$2"

  ssh -n -o StrictHostKeyChecking=yes root@"$JOIN_IP" '
    set -eu
    test ! -e /var/lib/rancher/k3s/join-token
    test ! -e /var/lib/rancher/k3s/join-token.pending
    test ! -e /var/lib/rancher/k3s/server/db/etcd
    install -d -m 0700 -o root -g root /var/lib/rancher/k3s
  '

  scp -3 -o StrictHostKeyChecking=yes \
    root@192.168.1.103:"$TOKEN_SOURCE" \
    root@"$JOIN_IP":/var/lib/rancher/k3s/join-token.pending </dev/null

  ssh -n -o StrictHostKeyChecking=yes root@"$JOIN_IP" '
    set -eu
    test -s /var/lib/rancher/k3s/join-token.pending
    chown root:root /var/lib/rancher/k3s/join-token.pending
    chmod 0600 /var/lib/rancher/k3s/join-token.pending
    mv -T /var/lib/rancher/k3s/join-token.pending /var/lib/rancher/k3s/join-token
    systemctl reset-failed k3s
    systemctl start k3s
  '
}

# This block only defines join_guest; it performs no join.
```

In the **same trusted shell** where `join_guest` was defined, invoke
the following **one command at a time**, replacing each IP with its
observed reserved address. Stop between commands and verify the new
member's Node readiness, K3s/etcd logs, Cilium health and cross-node
connectivity before proceeding:

1. `join_guest "REPLACE_WITH_OBSERVED_CP02_IP" /var/lib/rancher/k3s/server/token`
2. **After cp-02 is a healthy etcd member:** `join_guest "REPLACE_WITH_OBSERVED_CP03_IP" /var/lib/rancher/k3s/server/token`
3. **After all three etcd members are healthy:** `join_guest "REPLACE_WITH_OBSERVED_WORKER_IP" /var/lib/rancher/k3s/server/agent-token`

In particular, with only two etcd voters **both** are needed for quorum.
Do not restart either one between steps 1 and 2.

The worker runs K3s `agent` only. It must not initialize etcd. Verify all
four nodes and Cilium agents are Ready after it joins. The fresh cp-02
registration should apply the declared
`node-role.kubernetes.io/control-plane=true:NoSchedule` taint; if missing,
investigate and then apply it explicitly as described in
[operations.md](operations.md).

## 4. Bring Argo CD and GitOps into service

Cilium and Argo CD are **already** specified as K3s HelmCharts on cp-01.
Once worker-02 is Ready, Argo CD's controller, repo-server, API server and
Redis can schedule there. From cp-01:

```sh
k3s kubectl -n argocd get deploy,statefulset,pods,svc
k3s kubectl wait --for=condition=Established --timeout=300s \
  crd/applications.argoproj.io crd/appprojects.argoproj.io
k3s kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
k3s kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s
k3s kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
```

In a checkout of the **current** `mitschwimmer/argo` repository on the
workstation, install its root exactly once into this new cluster:

```sh
ssh root@192.168.1.103 'k3s kubectl apply -f -' \
  < clusters/homelab/bootstrap.yaml
```

This apply creates the `bootstrap` AppProject and `homelab` root
Application. The root tracks `main`, self-heals, and does **not**
automatically prune. Do not use `kubectl apply` or a separate Helm
workflow to manage resources subsequently owned by Argo. Follow
[gitops.md](gitops.md) and the `argo` README for ownership details.

A freshly generated Argo administrator password may differ from the old
one. Regenerate or reconfigure it securely; preserving the old password
is not an objective of this runbook.

## 5. Acceptance: the repositories are running

The rebuild is complete **only if** the code is applied and the following
checks pass. Reconcile observed differences in Git, not by silently adding
new one-time installation instructions.

- All four expected Kubernetes Nodes are `Ready` with correct names/roles;
  three servers are healthy etcd members, and worker-02 is an agent.
- cp-02 is `NoSchedule`; cp-01 and cp-03 are schedulable for ordinary
  workloads. Verify the actual Node taints, not merely the Nix flags.
- Cilium runs on all four nodes; check agent health and connectivity,
  including across the `meawhite`/`meablack` boundary. Verify Pod-IP HTTP
  and Service-DNS traffic in both directions using temporary test Pods.
- CoreDNS, metrics-server and `kubectl top nodes` work.
- The K3s-owned Cilium and Argo CD HelmCharts are healthy and remain
  independent of the Argo Application tree.
- `argocd/homelab` is `Synced` and `Healthy`. Any applications currently
  committed in `argo` must reach their expected states too. Verify a real
  workload's behavior, not just an Argo sync badge.
- Persistent workload data, if any, is restored and tested by the **separate
  payload recovery process** before it is considered usable.

Useful observations from cp-01:

```sh
k3s kubectl get nodes -o wide
k3s kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints,UNSCHEDULABLE:.spec.unschedulable'
k3s kubectl -n kube-system get daemonset cilium
k3s kubectl get pods -A -o wide
k3s kubectl top nodes
k3s kubectl -n argocd get applications,appprojects
k3s kubectl -n argocd get application homelab \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'
```

Do not describe the cluster as host-HA: both cp-01 and cp-02 live on
`meawhite`. Keepalived may provide an API VIP but cannot recover etcd quorum
after that physical host is lost. Validate VIP ownership and failover separately
using [operations.md](operations.md); do not presume it works from Nix alone.

## What is deliberately *not* restored

This procedure creates new guest state images, cluster certificates, etcd
membership, server/join tokens, Kubernetes UIDs and generated Argo credentials.
**No K3s/etcd snapshot, original K3s token, old MicroVM `state.img` or
old SSH host private key is required** to reproduce the declarative cluster.
Likewise, this runbook never calls `k3s cluster-reset`: it creates a new
cluster rather than repairing an old datastore.

Do not confuse those intentionally disposable identities with off-host
**host access and firmware recovery assets**: Secure Boot signing keys, disk
unlock/recovery material, administrator SSH access and external DHCP/router
settings are tracked in [backup-backlog.md](backup-backlog.md).
