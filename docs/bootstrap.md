# Bootstrap k8s-cp-01

Both physical hosts use Secure Boot. meawhite enables cp-01/cp-02 and
meablack enables cp-03. Only cp-01 initializes the cluster; fresh joiners
boot without K3s until their runtime token is provisioned. Obtain each first
DHCP lease before reserving its address and joining. For cp-03, first perform
the meablack bridge cutover below; do not apply cp-01's historical bootstrap
restart instructions to the running cluster.

## Prerequisites

- Shut down and disable autostart of the retired Talos/libvirt guest, if still
  present; retain its disk images and private recovery material.
- Reserve a DHCP address for `02:6b:38:00:00:01`; verify meawhite's `br0`,
  KVM, host rollback access and free space under `/var/lib/microvms`.
- Confirm Pod CIDR `10.42.0.0/16` and Service CIDR `10.43.0.0/16`
  do not collide with routed LAN/VPN networks before initializing etcd.

## Workstation

From the checked-out repository:

```sh
git diff --check
nix eval --no-update-lock-file --impure --json --expr '
  import ./tests/microvms.nix { flake = builtins.getFlake (toString ./.); }
'
nix build --no-update-lock-file --no-link .#nixosConfigurations.k8s-cp-01.config.microvm.declaredRunner
nix build --no-update-lock-file --no-link .#nixosConfigurations.meawhite-secure.config.system.build.toplevel
```

After successful checks, deploy with:

```sh
nixos-rebuild switch --flake .#meawhite-secure --target-host root@192.168.1.137
ssh root@192.168.1.137 'systemctl status microvm@k8s-cp-01 --no-pager'
ssh root@192.168.1.137 'bridge link show dev k8s-cp-01'
```

Use the guest's **observed** DHCP address:

```sh
CP01_IP=<guest-ip-from-dhcp>
ssh root@"$CP01_IP" 'findmnt /var; readlink -f /etc/rancher/node'
ssh root@"$CP01_IP" 'systemctl status k3s --no-pager; k3s kubectl get nodes'
ssh root@"$CP01_IP" 'test -s /var/lib/rancher/k3s/server/token && echo token-present'
```

Expect `NotReady` until Cilium is deployed. Before proceeding, verify guest
restart persistence. Encrypted off-host backup of the token and etcd recovery
material is deferred for this staging expansion by operator decision
(2026-11-14); recovery has not been verified. Do not print or commit tokens.

For meablack, use the verified uplink/MAC and timed bridge cutover below.

## Cilium bootstrap

Pin cp-01's DHCP address at `192.168.1.103` before enabling the Cilium
HelmChart: its kube-proxy-free API connection initially uses this address.
From the workstation, after evaluating and building the guest and
`meawhite-secure` host closures, deploy the updated host as above. Because
the MicroVM has `restartIfChanged = false`, restart only the guest on meawhite:

```sh
sudo systemctl restart microvm@k8s-cp-01
```

Then inspect the declarative installation from the workstation:

```sh
ssh root@192.168.1.103 'k3s kubectl -n kube-system get helmcharts,jobs,pods -o wide'
ssh root@192.168.1.103 'k3s kubectl -n kube-system rollout status ds/cilium --timeout=10m'
ssh root@192.168.1.103 'k3s kubectl get nodes; k3s kubectl get pods -A'
```

Cilium must become ready, followed by CoreDNS and metrics-server. If pod
readiness probes time out despite a Ready node, verify Cilium endpoint health;
the guest disables NixOS netfilter reverse-path checks while retaining the
ingress firewall, avoiding asymmetric eBPF traffic drops. If the
HelmChart fails, inspect `k3s kubectl -n kube-system logs job/helm-install-cilium`
and events. The chart is pinned to 1.20.4; `failurePolicy: abort` avoids
an automatic uninstall/reinstall loop. Do not install a second Helm release.

## Containerd CNI paths

The guest now installs a containerd v3 drop-in so its runtime loads the
Cilium CNI files from persistent K3s directories. After deploying the new
`meawhite-secure` closure and restarting only `microvm@k8s-cp-01`, check:

```sh
ssh root@192.168.1.103 "k3s crictl info | grep -E -A 5 'PluginConfDir|lastCNILoadStatus'"
ssh root@192.168.1.103 'k3s kubectl get nodes; k3s kubectl get pods -A'
```

## Stage cp-02 without joining

This is an activation procedure after PR review, successful evaluation/builds
and an explicit deployment decision. Merging does not deploy the host.
`meawhite/microvms.nix` lists cp-01 and cp-02; workers stay disabled.
A DHCP reservation is not required to boot a fresh cp-02 for its first lease.

1. Recheck cp-01's node/pod health and retain its observed address
   `192.168.1.103` (reserve its existing lease). Confirm CPU/RAM/disk capacity
   and direct L2 reachability on `br0`.
2. Confirm cp-02 has no preexisting state image under
   `/var/lib/microvms/k8s-cp-02/state.img` on meawhite. If it exists, stop here
   and inspect its history: an existing join token could allow an immediate
   join when booted. Do not delete state or clone cp-01's image.
3. Preserve cp-01's booted runner as a GC root using [operations.md](operations.md).
   Record its current/booted links. Do not restart cp-01.
4. Run the MicroVM evaluation above, evaluate both `meawhite` and
   `meawhite-secure` toplevel drvPaths, and build the cp-02 declared runner
   and `meawhite-secure` toplevel with `--no-update-lock-file`.
5. Deploy the physical host with the workstation command above. The new VM
   may start automatically; otherwise start only `microvm@k8s-cp-02` on
   meawhite. No join occurs without its token file. Existing cp-01 keeps its
   booted runner (`restartIfChanged = false`).
6. Find the newly issued lease in the router's DHCP lease table by MAC
   `02:6b:38:00:00:02` (hostname `k8s-cp-02`). Reserve that observed address.
   Do not assign an invented address. If the reservation changes the address,
   wait for the guest to obtain it and verify the effective lease again.
7. Verify cp-02's SSH host key via a trusted channel. Check `findmnt /var`,
   its distinct hostname and the node-password symlink. K3s should be inactive
   with `ConditionPathExists` unmet. Verify the token is absent before
   proceeding. Only after the lease is reserved, provision the token below.

```sh
CP02_IP="REPLACE_WITH_OBSERVED_CP02_IP"
ssh -o StrictHostKeyChecking=yes root@"$CP02_IP" '
  set -eu
  findmnt /var
  hostname
  readlink -f /etc/rancher/node
  test ! -e /var/lib/rancher/k3s/join-token
  systemctl show k3s -p ActiveState -p ConditionResult
'
```

Expect hostname `k8s-cp-02`, persistent ext4 `/var`, node identity under
`/var/lib/rancher/node`, `ActiveState=inactive` and `ConditionResult=no`.
If K3s is already active, stop the procedure and inspect the existing state
before supplying or changing credentials.

Before the join, both guests must allow TCP 6443, 2379–2380, 10250 and
Cilium health TCP 4240 plus ICMP. The existing TCP 9345 allowance is retained;
no VXLAN/8472 allowance is added. cp-01's running older runner does not pick
up the new 4240 rule through a host rebuild. Follow the live firewall step in
[operations.md](operations.md) before expecting two-node health.

## Provision a joiner's token and join

Use this for a fresh cp-02 or cp-03 only after its DHCP lease is reserved,
SSH host key is independently verified, persistent `/var` is checked, and
K3s is inactive because the token file is absent. For cp-03, finish and confirm
the bridge cutover first. Keep both existing etcd members running.

Run on a trusted workstation. Replace `JOIN_IP` with the observed reserved
joiner address. This explicit Bash block disables tracing and prevents SSH
from consuming the remaining script through standard input (`-n`); SCP also
gets a closed standard input. No plaintext workstation file is created.

```sh
bash <<'BASH'
set -euo pipefail
set +x
JOIN_IP="REPLACE_WITH_RESERVED_JOINER_IP"
trap 'echo "Abbruch bei Zeile $LINENO" >&2' ERR

# Fail rather than overwrite credentials or reuse an initialized etcd node.
ssh -n -o StrictHostKeyChecking=yes root@"$JOIN_IP" '
  set -eu
  test ! -e /var/lib/rancher/k3s/join-token
  test ! -e /var/lib/rancher/k3s/join-token.pending
  test ! -e /var/lib/rancher/k3s/server/db/etcd
  install -d -m 0700 -o root -g root /var/lib/rancher/k3s
'

# Both remote endpoints authenticate through the workstation, without agent forwarding.
scp -3 -o StrictHostKeyChecking=yes \
  root@192.168.1.103:/var/lib/rancher/k3s/server/token \
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
echo "K3s-Start abgeschlossen"
BASH
```

If transfer fails, do not publish `.pending` or start K3s. Inspect the failure
and remove only the incomplete pending file before retrying. The token stays
on persistent `/var`; no SOPS setup or second guest rebuild is required.
Keep it out of Git, the Nix store, command arguments, chat and logs. Copy the
full existing token including its CA hash; do not generate a new server token.

## Accept the second member

From cp-01, verify `k3s kubectl get nodes -o wide` and
`k3s kubectl get pods -A -o wide`: both nodes must be Ready with distinct IPs,
Cilium on each, and CoreDNS/metrics-server healthy. Check K3s/etcd logs on
both servers for successful membership and errors; node roles alone do not
prove a healthy etcd voter. Check the Cilium agents and `cilium-health status`
for 2/2 reachability. Test actual Pod traffic between nodes, service DNS and
`k3s kubectl top nodes` before accepting the expansion.

Do not stop/restart either voting member to test persistence while the cluster
has only two voters: quorum requires both. Check cp-02's mounts, host key and
node password now; defer a reboot/persistence acceptance test until a healthy
third voter exists (or an explicitly accepted maintenance outage).
Do not delete state to retry a partial join. Use [recovery.md](recovery.md).

References: [K3s joining servers](https://docs.k3s.io/datastore/ha-embedded),
[token security](https://docs.k3s.io/cli/token),
[Cilium ports](https://docs.cilium.io/en/stable/operations/system_requirements/).

## Stage cp-03 on meablack

Observed on 2026-11-14: host `192.168.1.28/24`, gateway `192.168.1.1`, physical
uplink `eno1`, MAC `24:4b:fe:03:c4:69`, 62 GiB RAM with 61 GiB available and
323 GiB free on `/var/lib`'s filesystem. cp-03 uses MAC `02:6b:38:00:00:03`,
vsock CID 1003, 2 vCPU, 2048 MiB RAM and a 64 GiB sparse persistent image.
Its IP is not allocated here.

1. Confirm cp-01/cp-02 remain Ready and reachable, including Cilium 2/2 and
   metrics. Do not deploy/restart meawhite or either existing guest for this step.
2. On meablack, confirm there is no preexisting
   `/var/lib/microvms/k8s-cp-03/state.img`; stop and inspect history if it exists.
   Do not delete or clone an etcd state image. Retain host recovery access.
3. Evaluate the MicroVM suite and the `meablack`/`meablack-secure` toplevel
   drvPaths; build the cp-03 runner and secure host toplevel before activation:

   ```sh
   nix build --no-update-lock-file --no-link \
     .#nixosConfigurations.k8s-cp-03.config.microvm.declaredRunner \
     .#nixosConfigurations.meablack-secure.config.system.build.toplevel
   ```

4. Follow [the timed meablack bridge cutover](operations.md#meablack-bridge-cutover).
   Build/copy before arming rollback. Test the configuration, confirm SSH,
   host addressing/default route on br0 and the TAP attachment, then commit
   it before provisioning any join token. Merging this change does not deploy.
5. Find cp-03's first DHCP lease by MAC `02:6b:38:00:00:03`, hostname
   `k8s-cp-03`, and reserve the observed address. Do not assume `.105` or any
   other free address. If it did not auto-start, start only
   `microvm@k8s-cp-03` on meablack.
6. Verify its SSH key, hostname, persistent ext4 `/var`, node-password symlink
   and inactive K3s with `ConditionResult=no`, as for cp-02. Verify TCP 6443,
   2379–2380, 10250 and Cilium TCP 4240/ICMP between all three guests. cp-01's
   live TCP 4240 allowance must still be present; do not reboot it to apply it.
7. Use the shared token provisioning procedure with cp-03's reserved IP.

## Accept the third member

Wait for cp-03 registration before using `kubectl wait` on its Node object:
`NotFound` means it has not registered yet, not necessarily a failed join.
Confirm all three Nodes are Ready with distinct IPs and server/etcd roles,
Cilium and Envoy are Running on each, and both Cilium status and health show
3/3 reachability from every agent. Check DNS/service routing, metrics on all
three, and bidirectional Pod-IP and Service-DNS HTTP traffic across the
physical-host boundary (cp-01/cp-02 to cp-03).

Inspect K3s/etcd member admission, learner promotion and health before treating
cp-03 as a healthy voter; node roles alone do not prove etcd quorum health.
Only after three healthy voters are confirmed may a single guest restart be
planned for persistence acceptance. Preserve its runner and state and recheck
all health after the restart; do not restart multiple members together.
Even with three voters, losing meawhite removes two: this is not host-level HA.
Encrypted off-host backup/restore verification remains explicitly deferred.
