{ config, lib, nixvirt, pkgs, ... }:
let
  cfg = config.meawhite.talos;
  fastPath = "/var/lib/libvirt/talos";
  dataPath = "/data/talos";
  mac = "52:54:00:7a:10:01";

  disk = name: size: nixvirt.lib.volume.writeXML {
    inherit name;
    capacity = { count = size; unit = "GiB"; };
    target.format.type = "qcow2";
  };

  vmDisks = [
    {
      type = "volume";
      device = "disk";
      driver = { name = "qemu"; type = "qcow2"; cache = "none"; discard = "unmap"; };
      source = { pool = "talos-fast"; volume = "talos-system.qcow2"; };
      target = { dev = "vda"; bus = "virtio"; };
      serial = "talos-system";
    }
    {
      type = "volume";
      device = "disk";
      driver = { name = "qemu"; type = "qcow2"; cache = "none"; discard = "unmap"; };
      source = { pool = "talos-data"; volume = "talos-data.qcow2"; };
      target = { dev = "vdb"; bus = "virtio"; };
      serial = "talos-data";
    }
  ];
in
{
  options.meawhite.talos = {
    start = lib.mkEnableOption "automatic startup of the Talos VM";
    installerIso = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/var/lib/libvirt/talos/metal-amd64.iso";
      description = ''
        Absolute host path to a locally downloaded Talos installer ISO.
        Keep installer images and Talos secrets outside the Nix store.
        Set back to null after installation and verify disk boot.
      '';
    };
  };

  config = {
    virtualisation.libvirt = {
      enable = true;
      connections."qemu:///system" = {
        networks = [
          {
            definition = nixvirt.lib.network.writeXML {
              name = "talos";
              uuid = "699423c0-897c-4b93-b923-49e4a22da7ed";
              forward.mode = "nat";
              bridge.name = "virbr-talos";
              ip = {
                address = "192.168.127.1";
                netmask = "255.255.255.0";
                dhcp = {
                  range = { start = "192.168.127.10"; end = "192.168.127.99"; };
                  host = [ { inherit mac; name = "talos"; ip = "192.168.127.10"; } ];
                };
              };
            };
            active = true;
            restart = false;
          }
        ];

        pools = [
          {
            definition = nixvirt.lib.pool.writeXML {
              name = "talos-fast";
              uuid = "69c81d55-5b44-4dd5-8696-030b5995f8d0";
              type = "dir";
              target.path = fastPath;
            };
            active = true;
            restart = false;
            volumes = [ { definition = disk "talos-system.qcow2" 64; } ];
          }
          {
            definition = nixvirt.lib.pool.writeXML {
              name = "talos-data";
              uuid = "c24f578c-6dad-47ad-a208-5918d8d1dbf1";
              type = "dir";
              target.path = dataPath;
            };
            active = true;
            restart = false;
            volumes = [ { definition = disk "talos-data.qcow2" 256; } ];
          }
        ];

        domains = [
          {
            definition = nixvirt.lib.domain.writeXML {
              type = "kvm";
              name = "talos";
              uuid = "1e998041-10ee-4b18-a516-ae879e3e3ee9";
              memory = { count = 12; unit = "GiB"; };
              vcpu.count = 4;
              cpu.mode = "host-passthrough";
              os = {
                type = "hvm";
                arch = "x86_64";
                machine = "q35";
                boot =
                  lib.optionals (cfg.installerIso != null) [ { dev = "cdrom"; } ]
                  ++ [ { dev = "hd"; } ];
              };
              features = { acpi = { }; apic = { }; };
              on_reboot = "restart";
              on_crash = "destroy";
              devices = {
                disk = vmDisks ++ lib.optionals (cfg.installerIso != null) [
                  {
                    type = "file";
                    device = "cdrom";
                    driver = { name = "qemu"; type = "raw"; };
                    source.file = cfg.installerIso;
                    target = { dev = "sda"; bus = "sata"; };
                    readonly = true;
                  }
                ];
                interface = [
                  {
                    type = "network";
                    source.network = "talos";
                    model.type = "virtio";
                    mac.address = mac;
                  }
                  # Secondary LAN NIC. Retain NAT as the bootstrap/recovery path.
                  # NixVirt does not restart the running guest on a rebuild;
                  # add an explicit Talos network policy before its next reboot.
                  {
                    type = "bridge";
                    source.bridge = "br0";
                    model.type = "virtio";
                    mac.address = "52:54:00:7a:10:02";
                  }
                ];
                serial = [ { type = "pty"; } ];
                console = [ { type = "pty"; } ];
                rng = { model = "virtio"; backend = { model = "random"; source = "/dev/urandom"; }; };
                memballoon.model = "none";
              };
            };
            active = if cfg.start then true else null;
            # A rebuild can redefine XML, but must not power-cycle etcd.
            restart = false;
          }
        ];
      };
    };

    virtualisation.libvirtd.onShutdown = "shutdown";

    # Never activate the RAID-backed pool on an absent /data mount.
    systemd.services.nixvirt = {
      requires = [ "data.mount" ];
      after = [ "data.mount" ];
      preStart = ''
        ${pkgs.coreutils}/bin/install -d -m 0750 ${fastPath} ${dataPath}
      '';
    };
  };
}
