{ lib, name, ... }:

let
  # Bootstrap only the first etcd member. Joining nodes need a separate
  # reviewed token-delivery and API endpoint configuration.
  bootstrapServer = name == "k8s-cp-01";
in
{
  services.k3s = lib.mkIf bootstrapServer {
    enable = true;
    role = "server";
    clusterInit = true;

    disable = [ "traefik" "servicelb" "local-storage" ];
    extraFlags = [
      # Cilium will provide networking and replace kube-proxy in a later step.
      "--flannel-backend=none"
      "--disable-network-policy"
      "--disable-kube-proxy"
      "--secrets-encryption"
    ];
    # No token or tokenFile on the first server: K3s creates a token in
    # persistent /var/lib/rancher/k3s/server/token. Back it up off-host.
  };

  networking.firewall.allowedTCPPorts = lib.optionals bootstrapServer [
    6443 # Kubernetes API
    9345 # K3s supervisor / future node registration
    2379 # etcd clients
    2380 # etcd peer traffic
    10250 # kubelet
  ];

  # The MicroVM root (including /etc) is temporary. K3s normally writes its
  # per-node password under /etc/rancher/node; keep it on persistent /var.
  systemd.tmpfiles.rules = lib.optionals bootstrapServer [
    "d /var/lib/rancher/node 0700 root root -"
    "d /etc/rancher 0755 root root -"
    "L+ /etc/rancher/node - - - - /var/lib/rancher/node"

    # The pinned K3s/containerd 2 config imports this v3 drop-in.
    # Without it containerd ignores Cilium's persistent K3s CNI paths.
    "d /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d 0755 root root -"
    "L+ /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/10-cni.toml - - - - ${./containerd-cni.toml}"
  ];
  systemd.services.k3s = lib.mkIf bootstrapServer {
    after = [ "systemd-tmpfiles-setup.service" ];
    requires = [ "systemd-tmpfiles-setup.service" ];
  };
}
