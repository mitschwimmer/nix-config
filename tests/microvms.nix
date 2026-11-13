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
      } // lib.optionalAttrs (name == "meablack") {
        # Evaluation fixture only: not deployment values or a real NIC.
        uplink = lib.mkForce "fixture0";
        bridgeMac = lib.mkForce "02:00:00:00:ff:01";
      };
    } ];
  }).config;
  hosts = lib.genAttrs [ "meablack" "meawhite" ] enabledHost;
  check = label: condition: if condition then true else throw "MicroVM check failed: ${label}";
in
{
  topology = check "five nodes, three servers, two servers on meawhite"
    (builtins.length (builtins.attrNames nodes) == 5
      && builtins.length (lib.filter (n: n.role == "server") (builtins.attrValues nodes)) == 3
      && builtins.length (lib.filter (n: n.role == "server" && n.host == "meawhite") (builtins.attrValues nodes)) == 2);
  identity = check "unique stable MACs, vsock CIDs and valid TAP names"
    (builtins.length (lib.unique (map (n: n.mac) (builtins.attrValues nodes))) == builtins.length (builtins.attrNames nodes)
      && builtins.length (lib.unique (map (n: n.vsockCid) (builtins.attrValues nodes))) == builtins.length (builtins.attrNames nodes)
      && lib.all (n: n.vsockCid >= 3) (builtins.attrValues nodes)
      && lib.all (name: guests.${name}.microvm.vsock.cid == nodes.${name}.vsockCid) (builtins.attrNames nodes)
      && lib.all (name: builtins.stringLength (builtins.head guests.${name}.microvm.interfaces).id <= 15) (builtins.attrNames nodes));
  # K3s activation is staged separately; this suite checks guest foundations only.
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
      && lib.all (name: !guests.${name}.services.k3s.enable)
        (lib.filter (name: name != "k8s-cp-01") (builtins.attrNames nodes)));
  containerdCni = check "containerd v3 imports persistent Cilium paths"
    (let
      rules = guests."k8s-cp-01".systemd.tmpfiles.rules;
      dropin = builtins.readFile ../kubernetes/containerd-cni.toml;
    in
      lib.elem "d /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d 0755 root root -" rules
      && lib.any (lib.hasPrefix
        "L+ /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/10-cni.toml - - - - "
      ) rules
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
  hosts = lib.mapAttrs (name: c: check "${name}: opt-in guests without mass restarts"
    (builtins.length (builtins.attrNames c.microvm.vms) == (if name == "meawhite" then 3 else 2)
      && lib.all (vm: !vm.restartIfChanged) (builtins.attrValues c.microvm.vms)
      && configs.${name}.config.services.kubernetesMicrovms.enable == (name == "meawhite")
      && configs.${name}.config.services.kubernetesMicrovms.guests
        == lib.optional (name == "meawhite") "k8s-cp-01"
      && !(configs.${name}.config.virtualisation.libvirtd.enable)
      && lib.all (vm:
        let unit = c.systemd.services."microvm-tap-interfaces@${vm}";
        in
          lib.elem "br0-netdev.service" unit.after
          && lib.elem "br0-netdev.service" unit.requires
          && unit.overrideStrategy == "asDropin"
          && lib.hasSuffix " master br0" unit.serviceConfig.ExecStartPost
      ) (builtins.attrNames c.microvm.vms))) hosts;
  # Force full module evaluation, including assertion and service generation,
  # for both enabled host paths as well as the disabled default configurations.
  enabledHostDerivations = lib.mapAttrs (_: c: c.system.build.toplevel.drvPath) hosts;
}
