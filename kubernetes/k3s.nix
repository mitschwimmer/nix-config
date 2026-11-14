{ lib, name, ... }:

let
  bootstrapServer = name == "k8s-cp-01";
  joiningServer = lib.elem name [ "k8s-cp-02" "k8s-cp-03" ];
  enabledServer = bootstrapServer || joiningServer;
  # Runtime file on persistent /var, never a Nix path literal or store secret.
  joinTokenFile = "/var/lib/rancher/k3s/join-token";
in
{
  services.k3s = lib.mkIf enabledServer {
    enable = true;
    role = "server";
    clusterInit = bootstrapServer;
    # Staging endpoint shared with Cilium; no VIP or host-level HA yet.
    serverAddr = lib.mkIf joiningServer "https://192.168.1.103:6443";
    tokenFile = lib.mkIf joiningServer joinTokenFile;

    disable = [ "traefik" "servicelb" "local-storage" ];
    extraFlags = [
      # Keep critical settings identical on both servers; Cilium owns networking.
      "--flannel-backend=none"
      "--disable-network-policy"
      "--disable-kube-proxy"
      "--secrets-encryption"
    ];
    # No token or tokenFile on the first server: K3s creates a token in
    # persistent /var/lib/rancher/k3s/server/token. Back it up off-host.
  };

  networking.firewall.allowedTCPPorts = lib.optionals enabledServer [
    6443 # Kubernetes API
    9345 # K3s supervisor / future node registration
    2379 # etcd clients
    2380 # etcd peer traffic
    10250 # kubelet
    4240 # Cilium cluster health (native routing; no VXLAN port)
  ];

  # The MicroVM root (including /etc) is temporary. K3s normally writes its
  # per-node password under /etc/rancher/node; keep it on persistent /var.
  systemd.tmpfiles.rules = lib.optionals enabledServer [
    "d /var/lib/rancher/node 0700 root root -"
    "d /etc/rancher 0755 root root -"
    "L+ /etc/rancher/node - - - - /var/lib/rancher/node"

    # The pinned K3s/containerd 2 config imports this v3 drop-in.
    # Without it containerd ignores Cilium's persistent K3s CNI paths.
    "d /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d 0755 root root -"
    "L+ /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/10-cni.toml - - - - ${./containerd-cni.toml}"
  ];
  systemd.services.k3s = lib.mkIf enabledServer {
    after = [ "systemd-tmpfiles-setup.service" ];
    requires = [ "systemd-tmpfiles-setup.service" ];
    # A base VM can boot for SSH provisioning without attempting a join.
    unitConfig.ConditionPathExists = lib.mkIf joiningServer joinTokenFile;
    preStart = lib.mkIf joiningServer (lib.mkBefore ''
      if ! test -f ${joinTokenFile} || test -L ${joinTokenFile} \
        || ! test -s ${joinTokenFile} \
        || test "$(stat -c '%u:%g:%a' ${joinTokenFile})" != "0:0:600"; then
        echo "K3s join requires a nonempty root:root 0600 regular join-token file" >&2
        exit 1
      fi
    '');
  };
}
