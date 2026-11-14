# Bootstrap k8s-cp-01

Only `k8s-cp-01` is enabled on meawhite; both physical hosts use Secure Boot.
cp-02 is prepared for a token-file join; activate it only through the staged
procedure below after assigning its DHCP reservation.

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

For meablack, first discover the real uplink/MAC in `meablack/microvms.nix`.
Moving DHCP to the bridge can disconnect SSH: use console/timed rollback.

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
and an explicit deployment decision. Preparing or merging the PR does not
start cp-02: `meawhite/microvms.nix` still lists only cp-01.

1. Recheck cp-01's node/pod health. Reserve `192.168.1.103` for cp-01
   and a distinct, observed LAN address for cp-02 MAC `02:6b:38:00:00:02`.
   Confirm CPU/RAM/disk capacity and direct L2 reachability on `br0`.
2. Preserve cp-01's booted runner as a GC root using [operations.md](operations.md).
   Record its current/booted links. Do not restart cp-01.
3. In a reviewed activation change, set the host guest list to
   `[ "k8s-cp-01" "k8s-cp-02" ]`. Update the corresponding live-host
   expectation in `tests/microvms.nix` to match; leave all other guests disabled.
4. Run the MicroVM evaluation above, evaluate both `meawhite` and
   `meawhite-secure` toplevel drvPaths, and build the cp-02 declared runner
   and `meawhite-secure` toplevel with `--no-update-lock-file`.
5. Deploy the physical host with the workstation command above. The new VM
   may start automatically; otherwise start only `microvm@k8s-cp-02` on
   meawhite. No join occurs without its token file. Existing cp-01 keeps its
   booted runner (`restartIfChanged = false`).
6. Verify cp-02's DHCP address and SSH host key via a trusted channel.
   Check `findmnt /var`, its distinct hostname and the node-password symlink.
   K3s should be inactive with `ConditionPathExists` unmet. Never clone cp-01's
   state image or provision an existing, unrelated etcd data directory.

Before the join, both guests must allow TCP 6443, 2379–2380, 10250 and
Cilium health TCP 4240 plus ICMP. The existing TCP 9345 allowance is retained;
no VXLAN/8472 allowance is added. cp-01's running older runner does not pick
up the new 4240 rule through a host rebuild. Follow the live firewall step in
[operations.md](operations.md) before expecting two-node health.

## Provision cp-02's token and join

Run on a trusted workstation in **Bash**, with shell tracing disabled.
Use the observed/reserved cp-02 IP. Verify both SSH host keys first; the
commands require existing known-host entries and never bypass verification.
Do not run under a terminal recorder that captures pipeline data.

```sh
set +x
set -euo pipefail
CP02_IP="REPLACE_WITH_OBSERVED_CP02_IP"

# Refuse to overwrite a token or provision an already initialized server.
ssh -o StrictHostKeyChecking=yes root@"$CP02_IP" \
  'test ! -e /var/lib/rancher/k3s/join-token && test ! -e /var/lib/rancher/k3s/server/db/etcd'

# Stream the existing full token through SSH; no plaintext workstation file.
# Publish atomically only after the source SSH command succeeds.
ssh -o StrictHostKeyChecking=yes root@192.168.1.103 \
  'test -s /var/lib/rancher/k3s/server/token && cat /var/lib/rancher/k3s/server/token' \
  | ssh -o StrictHostKeyChecking=yes root@"$CP02_IP" \
    'set -eu; umask 077
     install -d -m 0700 -o root -g root /var/lib/rancher/k3s
     test ! -e /var/lib/rancher/k3s/join-token
     tmp=$(mktemp /var/lib/rancher/k3s/.join-token.XXXXXX)
     trap "rm -f \"\$tmp\"" EXIT
     cat > "$tmp"
     test -s "$tmp"
     chown root:root "$tmp"
     chmod 0600 "$tmp"
     mv -T "$tmp" /var/lib/rancher/k3s/join-token.pending'

# Reached only when BOTH SSH commands succeeded (pipefail).
ssh -o StrictHostKeyChecking=yes root@"$CP02_IP" \
  'set -eu
   test ! -e /var/lib/rancher/k3s/join-token
   mv -T /var/lib/rancher/k3s/join-token.pending /var/lib/rancher/k3s/join-token
   systemctl reset-failed k3s
   systemctl start k3s'
```

If transfer fails, do not publish `.pending` or start K3s. Remove the pending
file on cp-02 and retry after investigating. The token persists on `/var`;
no SOPS setup or second guest rebuild is required. Keep it out of Git, the
Nix store, command arguments, chat and logs. Use the full token including its
CA hash so the joiner authenticates the existing cluster before sending credentials.

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
