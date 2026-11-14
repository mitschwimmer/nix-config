{ flake }:
let
  inherit (flake.inputs.nixpkgs) lib;
  nodes = import ../kubernetes/nodes.nix;
  configs = flake.nixosConfigurations;
  guests = lib.mapAttrs (name: _: configs.${name}.config) nodes;
  enabledHost = name: (configs.${name}.extendModules {
    modules = [ {
      services.kubernetesMicrovms = {
        enable = lib.mkForce true;
        guests = lib.mkForce (builtins.attrNames (lib.filterAttrs (_: n: n.host == name) nodes));
      };
    } ];
  }).config;
  hosts = lib.genAttrs [ "meablack" "meawhite" ] enabledHost;
  check = label: condition: if condition then true else throw "MicroVM check failed: ${label}";
in
{
  topology = check "four nodes, three servers, sole worker on meawhite"
    (builtins.length (builtins.attrNames nodes) == 4
      && builtins.length (lib.filter (n: n.role == "server") (builtins.attrValues nodes)) == 3
      && builtins.length (lib.filter (n: n.role == "server" && n.host == "meawhite") (builtins.attrValues nodes)) == 2);
  identity = check "unique stable MACs, vsock CIDs and valid TAP names"
    (builtins.length (lib.unique (map (n: n.mac) (builtins.attrValues nodes))) == builtins.length (builtins.attrNames nodes)
      && builtins.length (lib.unique (map (n: n.vsockCid) (builtins.attrValues nodes))) == builtins.length (builtins.attrNames nodes)
      && lib.all (n: n.vsockCid >= 3) (builtins.attrValues nodes)
      && lib.all (name: guests.${name}.microvm.vsock.cid == nodes.${name}.vsockCid) (builtins.attrNames nodes)
      && lib.all (name: builtins.stringLength (builtins.head guests.${name}.microvm.interfaces).id <= 15) (builtins.attrNames nodes));
  # All four guests remain buildable; joining is gated by runtime credentials.
  guests = lib.mapAttrs (name: c: check "${name}: raw persistent state, full kernel and no NAT"
    (c.networking.hostName == name
      && c.networking.firewall.enable
      && !c.networking.firewall.checkReversePath
      && c.microvm.hypervisor == "cloud-hypervisor"
      && c.microvm.storeOnDisk
      && c.microvm.shares == [ ]
      && c.microvm.kernel == c.boot.kernelPackages.kernel
      && (builtins.head c.microvm.interfaces).type == "tap"
      && (builtins.head c.microvm.volumes).imageType == "raw"
      && c.fileSystems."/var".neededForBoot
      && (builtins.head c.services.openssh.hostKeys).path == "/var/lib/ssh/ssh_host_ed25519_key")) guests;
  k3sBootstrap = check "only cp-01 initializes embedded etcd without a token in Nix"
    (let c = guests."k8s-cp-01"; in
      c.services.k3s.enable
      && c.services.k3s.role == "server"
      && c.services.k3s.clusterInit
      && c.services.k3s.token == ""
      && c.services.k3s.tokenFile == null
      && c.services.k3s.serverAddr == ""
      && lib.all (flag: lib.elem flag c.services.k3s.extraFlags) [
        "--flannel-backend=none"
        "--disable-network-policy"
        "--disable-kube-proxy"
        "--secrets-encryption"
      ]
      && lib.all (port: lib.elem port c.networking.firewall.allowedTCPPorts) [
        6443 9345 2379 2380 10250
      ]
      && lib.elem "L+ /etc/rancher/node - - - - /var/lib/rancher/node" c.systemd.tmpfiles.rules
);
  k3sJoin = lib.genAttrs [ "k8s-cp-02" "k8s-cp-03" ] (name:
    check "${name}: joins existing etcd using only a protected runtime token file"
    (let
      first = guests."k8s-cp-01";
      c = guests.${name};
    in
      c.services.k3s.enable
      && c.services.k3s.role == "server"
      && !c.services.k3s.clusterInit
      && c.services.k3s.serverAddr == "https://192.168.1.103:6443"
      && c.services.k3s.token == ""
      && c.services.k3s.tokenFile == "/var/lib/rancher/k3s/join-token"
      && c.systemd.services.k3s.unitConfig.ConditionPathExists == c.services.k3s.tokenFile
      && lib.hasInfix "0:0:600" c.systemd.services.k3s.preStart
      && lib.filter (flag: !(lib.hasPrefix "--node-taint=" flag)) c.services.k3s.extraFlags
        == first.services.k3s.extraFlags
      && c.services.k3s.disable == first.services.k3s.disable
      && lib.elem "L+ /etc/rancher/node - - - - /var/lib/rancher/node" c.systemd.tmpfiles.rules
      && lib.elem "systemd-tmpfiles-setup.service" c.systemd.services.k3s.requires
      && lib.all (name:
        let c = guests.${name}; in
          lib.all (port: lib.elem port c.networking.firewall.allowedTCPPorts)
            [ 6443 9345 2379 2380 10250 4240 ]
          && c.networking.firewall.allowPing
          && !(lib.elem 8472 c.networking.firewall.allowedUDPPorts)
      ) [ "k8s-cp-01" "k8s-cp-02" "k8s-cp-03" ]));
  k3sWorker = check "sole worker joins as an agent without server ports or flags"
    (let c = guests."k8s-worker-02"; in
      c.services.k3s.enable
      && c.services.k3s.role == "agent"
      && !c.services.k3s.clusterInit
      && c.services.k3s.serverAddr == "https://192.168.1.103:6443"
      && c.services.k3s.token == ""
      && c.services.k3s.tokenFile == "/var/lib/rancher/k3s/join-token"
      && c.systemd.services.k3s.unitConfig.ConditionPathExists == c.services.k3s.tokenFile
      && lib.hasInfix "0:0:600" c.systemd.services.k3s.preStart
      && c.services.k3s.extraFlags == [ ]
      && c.services.k3s.disable == [ ]
      && lib.all (port: !(lib.elem port c.networking.firewall.allowedTCPPorts)) [ 6443 9345 2379 2380 ]
      && lib.all (port: lib.elem port c.networking.firewall.allowedTCPPorts) [ 10250 4240 ]
      && c.networking.firewall.allowPing
      && !(lib.elem 8472 c.networking.firewall.allowedUDPPorts)
      && lib.elem "L+ /etc/rancher/node - - - - /var/lib/rancher/node" c.systemd.tmpfiles.rules);
  workloadScheduling = check "cp-01/cp-03 run agents without registration taints; cp-02 is reserved"
    (lib.all (name:
      let c = guests.${name}; in
        !c.services.k3s.disableAgent
        && !(lib.any (lib.hasPrefix "--node-taint=") c.services.k3s.extraFlags)
    ) [ "k8s-cp-01" "k8s-cp-03" ]
      && lib.elem "--node-taint=node-role.kubernetes.io/control-plane=true:NoSchedule"
        guests."k8s-cp-02".services.k3s.extraFlags);
  containerdCni = check "containerd v3 imports persistent Cilium paths"
    (let
      dropin = builtins.readFile ../kubernetes/containerd-cni.toml;
    in
      lib.all (name:
        let rules = guests.${name}.systemd.tmpfiles.rules; in
          lib.elem "d /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d 0755 root root -" rules
          && lib.any (lib.hasPrefix
            "L+ /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/10-cni.toml - - - - "
          ) rules
      ) (builtins.attrNames nodes)
      && lib.all (fragment: lib.hasInfix fragment dropin) [
        "[plugins.'io.containerd.cri.v1.runtime'.cni]"
        "bin_dirs = [\"/var/lib/rancher/k3s/data/cni\"]"
        "conf_dir = \"/var/lib/rancher/k3s/agent/etc/cni/net.d\""
      ]);
  ciliumBootstrap = check "pinned Cilium on cp-01 and guest Bash without ble.sh"
    (let
      c = guests."k8s-cp-01";
      chart = c.services.k3s.manifests.cilium.content;
      values = chart.spec.valuesContent;
    in
      lib.all (name: !guests.${name}.programs.bash.blesh.enable)
        (builtins.attrNames nodes)
      && chart.kind == "HelmChart"
      && chart.metadata.namespace == "kube-system"
      && chart.spec.repo == "https://helm.cilium.io"
      && chart.spec.version == "1.20.4"
      && chart.spec.bootstrap
      && chart.spec.failurePolicy == "abort"
      && lib.all (text: lib.hasInfix text values) [
        "kubeProxyReplacement: true"
        "k8sServiceHost: 192.168.1.103"
        "routingMode: native"
        "autoDirectNodeRoutes: true"
        "ipv4NativeRoutingCIDR: 10.42.0.0/16"
        "mode: kubernetes"
        "binPath: /var/lib/rancher/k3s/data/cni"
        "confPath: /var/lib/rancher/k3s/agent/etc/cni/net.d"
      ]
      && lib.all (name: !(guests.${name}.services.k3s.manifests ? cilium))
        (lib.filter (name: name != "k8s-cp-01") (builtins.attrNames nodes)));
  argocdBootstrap = check "only cp-01 owns the pinned post-network Argo CD bootstrap"
    (let chart = guests."k8s-cp-01".services.k3s.manifests.argocd.content; in
      chart.kind == "HelmChart"
      && chart.metadata.namespace == "kube-system"
      && chart.spec.chart == "argo-cd"
      && chart.spec.repo == "https://argoproj.github.io/argo-helm"
      && chart.spec.version == "10.18.0"
      && chart.spec.targetNamespace == "argocd"
      && chart.spec.createNamespace
      && !chart.spec.bootstrap
      && chart.spec.failurePolicy == "abort"
      && lib.all (name: !(guests.${name}.services.k3s.manifests ? argocd))
        (lib.filter (name: name != "k8s-cp-01") (builtins.attrNames nodes)));
  hosts = lib.mapAttrs (name: c: check "${name}: opt-in guests without mass restarts"
    (builtins.length (builtins.attrNames c.microvm.vms) == (if name == "meawhite" then 3 else 1)
      && lib.all (vm: !vm.restartIfChanged) (builtins.attrValues c.microvm.vms)
      && configs.${name}.config.services.kubernetesMicrovms.enable
      && configs.${name}.config.services.kubernetesMicrovms.guests
        == (if name == "meawhite" then [ "k8s-cp-01" "k8s-cp-02" "k8s-worker-02" ] else [ "k8s-cp-03" ])
      && !(configs.${name}.config.virtualisation.libvirtd.enable)
      && lib.all (vm:
        let unit = c.systemd.services."microvm-tap-interfaces@${vm}";
        in
          lib.elem "br0-netdev.service" unit.after
          && lib.elem "br0-netdev.service" unit.requires
          && unit.overrideStrategy == "asDropin"
          && lib.hasSuffix " master br0" unit.serviceConfig.ExecStartPost
      ) (builtins.attrNames c.microvm.vms))) hosts;
  meablackBridge = check "meablack moves host DHCP to br0 while retaining the observed eno1 MAC"
    (let c = configs.meablack.config; in
      c.networking.bridges.br0.interfaces == [ "eno1" ]
      && !c.networking.interfaces.eno1.useDHCP
      && c.networking.interfaces.br0.useDHCP
      && c.networking.interfaces.br0.macAddress == "24:4b:fe:03:c4:69"
      && builtins.attrNames c.microvm.vms == [ "k8s-cp-03" ]
      && !c.microvm.vms."k8s-cp-03".restartIfChanged);
  resources = check "requested mixed control-plane and single-worker capacity"
    (guests."k8s-cp-01".microvm.mem == 4096 && guests."k8s-cp-01".microvm.vcpu == 4
      && guests."k8s-cp-02".microvm.mem == 2048 && guests."k8s-cp-02".microvm.vcpu == 2
      && guests."k8s-cp-03".microvm.mem == 4096 && guests."k8s-cp-03".microvm.vcpu == 4
      && guests."k8s-worker-02".microvm.mem == 16384
      && builtins.length (lib.filter (n: n.role == "agent") (builtins.attrValues nodes)) == 1);
  # Force full module evaluation, including assertion and service generation,
  # for both enabled physical hosts.
  enabledHostDerivations = lib.mapAttrs (_: c: c.system.build.toplevel.drvPath) hosts;
}
