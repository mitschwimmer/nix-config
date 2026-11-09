# MicroVM operations

## Scope

These procedures cover the phase-1 implementation. Kubernetes health, etcd,
cordon/drain, Keepalived failover, Cilium, OpenEBS and CSI snapshot procedures
must be added with those components and verified on the running cluster.
There is no Kubernetes API or etcd database to operate in this revision.

Commands below run from this repository unless marked as host-local. Select
the installed secure/non-secure host variant as explained in bootstrap.md.

## Evaluate and build

```sh
git diff --check
# Add newly created Nix files to Git before evaluating a Git-backed flake.
nix eval --no-update-lock-file --impure --json --expr '
  import ./tests/microvms.nix { flake = builtins.getFlake (toString ./.); }
'
for host in meablack meablack-secure meawhite meawhite-secure; do
  nix eval --no-update-lock-file --raw ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath"
done
for guest in k8s-test k8s-cp-01 k8s-cp-02 k8s-cp-03 k8s-worker-01 k8s-worker-02; do
  nix eval --no-update-lock-file --raw ".#nixosConfigurations.$guest.config.microvm.declaredRunner.drvPath"
done
nix build --no-update-lock-file .#nixosConfigurations.k8s-test.config.microvm.declaredRunner
```

## Inspect or restart a guest

On the guest's physical host, using k8s-test as the initial example:

```sh
sudo systemctl status microvm@k8s-test
sudo journalctl -u microvm@k8s-test -b --no-pager
sudo readlink -f /var/lib/microvms/k8s-test/current
sudo readlink -f /var/lib/microvms/k8s-test/booted
ip link show k8s-test
bridge link show dev k8s-test
sudo systemctl restart microvm@k8s-test
```

`current` is the installed runner; `booted` is the runner used by the running
guest and its shutdown/TAP teardown helpers. Their targets can differ after
a host rebuild. Do not delete runner paths, disk images or booted links.

## Update one guest

Host rebuilds install new declarative runners with `restartIfChanged = false`;
they do not deliberately restart every VM. Host reboot does restart guests.
For the test guest, first create an explicit GC root for the old runner:

```sh
# On meawhite, before rebuilding:
sudo nix-store --realise "$(readlink -f /var/lib/microvms/k8s-test/booted)" \
  --add-root /nix/var/nix/gcroots/k8s-test-before-update
sudo nixos-rebuild switch --flake .#meawhite
sudo systemctl start install-microk8s-test.service
sudo readlink -f /var/lib/microvms/k8s-test/current
sudo systemctl restart microvm@k8s-test
```

Verify its LAN access, persistent marker, machine ID and SSH fingerprint
before removing the GC root. The explicit install unit ensures the current
link matches the rebuilt host even when an automatic installation was not
scheduled. Building a runner alone does not install it into a running host.

Once K3s is introduced, add node-specific cordon/drain and health gates
before using this procedure on cluster guests. Upgrade control planes one
at a time, preserving etcd quorum and Kubernetes version-skew constraints.
NixOS rollback never rolls back Kubernetes, containerd or etcd data in `/var`.
K3s downgrades need the matching datastore restore procedure, not just an old
Nix generation.

## Roll back a test guest runner

On meawhite, with the GC root above still present:

```sh
sudo systemctl stop microvm@k8s-test
sudo ln -sTf "$(readlink -f /nix/var/nix/gcroots/k8s-test-before-update)" \
  /var/lib/microvms/k8s-test/current
sudo systemctl start microvm@k8s-test
```

Stop and start separately so the old runner's shutdown and TAP helpers finish
before changing the link. A subsequent declarative install/host rebuild may
replace this emergency link. Revert the guest change in Git and rebuild the
host to make rollback durable. Keep the old runner root until recovery is
complete. Persistent files remain at their current contents throughout.

## Reboot a physical host

For the foundation test, ensure Talos was already stopped, record the marker
and identities, then run `sudo systemctl reboot` on meawhite. After reconnecting,
check `systemctl status microvm@k8s-test`, bridge attachment and guest state.
Do not generalize this into a Kubernetes maintenance procedure until the
control-plane quorum, drain and VIP failover checks have been implemented.

## Host storage checks

```sh
df -h /var/lib/microvms
sudo du -h /var/lib/microvms/*/state.img
sudo ls -lh /var/lib/microvms/*/state.img
```

Compare allocated space (`du`) with sparse capacity (`ls`). State images are
not auto-grown by increasing `stateMiB` in Nix. Stop a guest before offline
filesystem repair, copying a consistent disk image, or resizing its backing
file. Never mount a running guest's filesystem read-write on the host.
