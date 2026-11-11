{ flake }:
let
  inherit (flake.inputs.nixpkgs) lib;
  nodes = import ../kubernetes/nodes.nix;
  cluster = lib.filterAttrs (_: n: n.role != "test") nodes;
  configs = flake.nixosConfigurations;
  guests = lib.mapAttrs (name: _: configs.${name}.config) nodes;
  enabledHost = name: (configs.${name}.extendModules {
    modules = [ {
      services.kubernetesMicrovms = {
        enable = lib.mkForce true;
        guests = lib.mkForce (builtins.attrNames (lib.filterAttrs (_: n: n.host == name) cluster));
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
    (builtins.length (builtins.attrNames cluster) == 5
      && builtins.length (lib.filter (n: n.role == "server") (builtins.attrValues cluster)) == 3
      && builtins.length (lib.filter (n: n.role == "server" && n.host == "meawhite") (builtins.attrValues cluster)) == 2);
  identity = check "unique stable MACs, vsock CIDs and valid TAP names"
    (builtins.length (lib.unique (map (n: n.mac) (builtins.attrValues nodes))) == builtins.length (builtins.attrNames nodes)
      && builtins.length (lib.unique (map (n: n.vsockCid) (builtins.attrValues nodes))) == builtins.length (builtins.attrNames nodes)
      && lib.all (n: n.vsockCid >= 3) (builtins.attrValues nodes)
      && lib.all (name: guests.${name}.microvm.vsock.cid == nodes.${name}.vsockCid) (builtins.attrNames nodes)
      && lib.all (name: builtins.stringLength (builtins.head guests.${name}.microvm.interfaces).id <= 15) (builtins.attrNames nodes));
  # K3s activation is staged separately; this suite checks guest foundations only.
  guests = lib.mapAttrs (name: c: check "${name}: raw persistent state, full kernel and no NAT"
    (c.networking.hostName == name
      && c.microvm.hypervisor == "cloud-hypervisor"
      && c.microvm.storeOnDisk
      && c.microvm.shares == [ ]
      && c.microvm.kernel == c.boot.kernelPackages.kernel
      && (builtins.head c.microvm.interfaces).type == "tap"
      && (builtins.head c.microvm.volumes).imageType == "raw"
      && c.fileSystems."/var".neededForBoot
      && (builtins.head c.services.openssh.hostKeys).path == "/var/lib/ssh/ssh_host_ed25519_key")) guests;
  hosts = lib.mapAttrs (name: c: check "${name}: opt-in guests without mass restarts"
    (builtins.length (builtins.attrNames c.microvm.vms) == (if name == "meawhite" then 3 else 2)
      && lib.all (vm: !vm.restartIfChanged) (builtins.attrValues c.microvm.vms)
      && !(configs.${name}.config.services.kubernetesMicrovms.enable)
      && !(configs.${name}.config.virtualisation.libvirtd.enable)
      && c.systemd.network.networks."30-kubernetes-taps".networkConfig.Bridge == "br0")) hosts;
  # Force full module evaluation, including assertion and service generation,
  # for both enabled host paths as well as the disabled default configurations.
  enabledHostDerivations = lib.mapAttrs (_: c: c.system.build.toplevel.drvPath) hosts;
}
