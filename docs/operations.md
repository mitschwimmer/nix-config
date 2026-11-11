# MicroVM operations

Commands run on the physical host unless otherwise noted. Use the
`-secure` NixOS flake variants for both hosts.

## Inspect

```sh
sudo systemctl status microvm@k8s-cp-01
sudo journalctl -b -u microvm@k8s-cp-01 --no-pager
sudo readlink -f /var/lib/microvms/k8s-cp-01/{current,booted}
bridge link show dev k8s-cp-01
df -h /var/lib/microvms
```

## Update one guest

Host rebuilds install runner revisions but do not restart existing guests
(`restartIfChanged = false`). Once multiple etcd members run, cordon/drain
and preserve quorum before restarting a node. On meawhite, preserve the old
runner as a GC root before updating:

```sh
sudo nix-store --realise "$(readlink -f /var/lib/microvms/k8s-cp-01/booted)" \
  --add-root /nix/var/nix/gcroots/k8s-cp-01-before-update
```

From the workstation, deploy `meawhite-secure` as in
[bootstrap.md](bootstrap.md). Then on meawhite:

```sh
sudo systemctl start install-microk8s-cp-01.service
sudo systemctl restart microvm@k8s-cp-01
```

Verify K3s, etcd, networking and persistent `/var` before removing the GC
root. For an emergency runner rollback, stop the VM, point `current` to the
saved runner and start it again; then revert the change in Git. Never delete
`state.img` or change `booted` during shutdown.

NixOS rollback does not roll back K3s/etcd state. A K3s downgrade may need a
matching datastore restore; never assume reverting a Nix generation is enough.
