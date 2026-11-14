{ lib, name, node, ... }:

let
  bootstrapServer = name == "k8s-cp-01";
  server = node.role == "server";
  joiningNode = !bootstrapServer;
  # Runtime file on persistent /var, never a Nix path literal or store secret.
  joinTokenFile = "/var/lib/rancher/k3s/join-token";
in
{
  services.k3s = {
    enable = true;
    role = node.role;
    clusterInit = bootstrapServer;
    # Staging endpoint shared with Cilium; no VIP or host-level HA yet.
    serverAddr = lib.mkIf joiningNode "https://192.168.1.103:6443";
    tokenFile = lib.mkIf joiningNode joinTokenFile;

    disable = lib.optionals server [ "traefik" "servicelb" "local-storage" ];
    # Agents obtain cluster networking settings from the server. Do not pass
    # server-only flags (including flannel-backend/secrets-encryption) to agents.
    extraFlags = lib.optionals server [
      "--flannel-backend=none"
      "--disable-network-policy"
      "--disable-kube-proxy"
      "--secrets-encryption"
    ] ++ lib.optional (name == "k8s-cp-02")
      "--node-taint=node-role.kubernetes.io/control-plane=true:NoSchedule";
    # cp-01 creates the persistent server token. Joiners receive a runtime
    # credential; registration taints need an explicit update on existing Nodes.
  };

  networking.firewall.allowedTCPPorts = [
    10250 # kubelet
    4240 # Cilium cluster health (native routing; no VXLAN port)
  ] ++ lib.optionals server [
    6443 # Kubernetes API
    9345 # Existing K3s supervisor allowance
    2379 # etcd clients
    2380 # etcd peer traffic
  ];

  # /etc is temporary. Persist K3s identity on /var on servers and agents.
  systemd.tmpfiles.rules = [
    "d /var/lib/rancher/node 0700 root root -"
    "d /etc/rancher 0755 root root -"
    "L+ /etc/rancher/node - - - - /var/lib/rancher/node"

    # The pinned K3s/containerd 2 config imports this v3 drop-in.
    "d /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d 0755 root root -"
    "L+ /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/10-cni.toml - - - - ${./containerd-cni.toml}"
  ];
  systemd.services.k3s = {
    after = [ "systemd-tmpfiles-setup.service" ];
    requires = [ "systemd-tmpfiles-setup.service" ];
    # A base VM can boot for SSH provisioning without attempting a join.
    unitConfig.ConditionPathExists = lib.mkIf joiningNode joinTokenFile;
    preStart = lib.mkIf joiningNode (lib.mkBefore ''
      if ! test -f ${joinTokenFile} || test -L ${joinTokenFile} \
        || ! test -s ${joinTokenFile} \
        || test "$(stat -c '%u:%g:%a' ${joinTokenFile})" != "0:0:600"; then
        echo "K3s join requires a nonempty root:root 0600 regular join-token file" >&2
        exit 1
      fi
    '');
  };
}
