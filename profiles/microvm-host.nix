{ config, lib, pkgs, self, ... }:
let
  cfg = config.services.kubernetesMicrovms;
  nodes = import ../kubernetes/nodes.nix;
  localNodes = lib.filterAttrs (_: node: node.host == config.networking.hostName) nodes;
in
{
  options.services.kubernetesMicrovms = {
    enable = lib.mkEnableOption "the Kubernetes MicroVM host foundation";
    guests = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (builtins.attrNames localNodes));
      default = [ ];
      description = "Guests installed and started on this host; bootstrap with k8s-cp-01 on meawhite.";
    };
    bridge = lib.mkOption {
      type = lib.types.strMatching "[a-zA-Z0-9_-]{1,15}";
      default = "br0";
      description = "Existing LAN bridge, or bridge to create when uplink is supplied.";
    };
    uplink = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[a-zA-Z0-9_.-]{1,15}");
      default = null;
      description = "Physical LAN NIC. Null reuses an existing bridge without changing its DHCP configuration.";
    };
    bridgeMac = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}");
      default = null;
      description = "Observed physical MAC to retain the host DHCP reservation when creating a bridge.";
    };
  };

  config = lib.mkMerge [ {
    microvm.host.enable = cfg.enable;
  } (lib.mkIf cfg.enable (lib.mkMerge [ {
    assertions = [ {
      assertion = cfg.uplink != null || builtins.hasAttr cfg.bridge config.networking.bridges;
      message = "Kubernetes MicroVMs require an existing LAN bridge or an observed uplink and bridgeMac.";
    } {
      assertion = cfg.uplink == null || cfg.bridgeMac != null;
      message = "Set bridgeMac to the observed host MAC before moving DHCP to the bridge.";
    } ];

    microvm.vms = lib.genAttrs cfg.guests (name: {
      evaluatedConfig = self.nixosConfigurations.${name};
      # A host rebuild must not restart all etcd members together.
      restartIfChanged = false;
    });

    # The host uses NixOS scripted networking for br0, not networkd.
    # Attach each TAP after bridge creation, as part of its MicroVM unit.
    systemd.services = lib.mkMerge [
      (lib.genAttrs (map (name: "microvm@${name}") cfg.guests) (_: {
        serviceConfig.UMask = "0077";
      }))
      (lib.listToAttrs (map (name: lib.nameValuePair "microvm-tap-interfaces@${name}" {
        overrideStrategy = "asDropin";
        requires = [ "${cfg.bridge}-netdev.service" ];
        after = [ "${cfg.bridge}-netdev.service" ];
        serviceConfig.ExecStartPost =
          "${pkgs.iproute2}/bin/ip link set dev ${name} master ${cfg.bridge}";
      }) cfg.guests))
    ];
  } (lib.mkIf (cfg.uplink != null) {
    networking.useDHCP = lib.mkForce false;
    networking.bridges.${cfg.bridge}.interfaces = [ cfg.uplink ];
    networking.interfaces.${cfg.uplink}.useDHCP = false;
    networking.interfaces.${cfg.bridge} = {
      useDHCP = true;
      macAddress = cfg.bridgeMac;
    };
  }) ])) ];
}
