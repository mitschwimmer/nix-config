{ config, lib, pkgs, name, node, ... }:
{
  # Guests deliberately do not inherit mkHost's Home Manager/workstation setup.
  imports = [ ../profiles/base.nix ./k3s.nix ./cilium.nix ./argocd.nix ];

  # ble.sh cannot initialize its cache inside the guest's read-only Nix store.
  programs.bash.blesh.enable = lib.mkForce false;

  networking.hostName = name;
  # Cilium's eBPF datapath may return pod traffic on a different interface
  # than NixOS's netfilter rpfilter expects. Kernel rp_filter is also off below.
  # Keep the regular NixOS ingress firewall and port allowlist enabled.
  networking.firewall.checkReversePath = false;
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    links."10-lan" = {
      matchConfig.MACAddress = node.mac;
      linkConfig.Name = "lan0";
    };
    networks."20-lan" = {
      matchConfig.Name = "lan0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
      };
      dhcpV4Config.ClientIdentifier = "mac";
      linkConfig.RequiredForOnline = "routable";
    };
    wait-online.enable = true;
  };

  microvm = {
    hypervisor = "cloud-hypervisor";
    inherit (node) vcpu mem;
    # Stable and distinct for every guest so Cloud Hypervisor can report readiness.
    vsock.cid = node.vsockCid;
    # The normal NixOS kernel, including loadable container/eBPF/LVM modules.
    kernel = config.boot.kernelPackages.kernel;
    # Self-contained read-only store image; no host virtiofs dependency.
    storeOnDisk = true;
    interfaces = [ {
      type = "tap";
      id = name;
      inherit (node) mac;
    } ];
    volumes = [ {
      image = "state.img";
      label = "vm-state";
      mountPoint = "/var";
      size = node.stateMiB;
      fsType = "ext4";
      imageType = "raw";
    } ];
  };

  fileSystems."/var".neededForBoot = true;
  boot.kernelModules = [ "overlay" "br_netfilter" "dm_thin_pool" ];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;
  };
  swapDevices = [ ];
  zramSwap.enable = false;
  services.timesyncd.enable = true;

  # /etc is reconstructed at boot. Keep SSH identity on the persistent disk.
  services.openssh = {
    settings.PermitRootLogin = "prohibit-password";
    hostKeys = [ { path = "/var/lib/ssh/ssh_host_ed25519_key"; type = "ed25519"; } ];
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../users/henner/authorized_keys ];
  environment.systemPackages = [ pkgs.iproute2 pkgs.util-linux ];
  system.stateVersion = "26.05";
}
