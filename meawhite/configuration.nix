{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ ./disko.nix ./microvms.nix (modulesPath + "/installer/scan/not-detected.nix") ];
  networking.hostName = "meawhite";
  # Bridge the physical LAN only after a guarded remote network migration.
  # Keep the host DHCP reservation by reusing enp129s0's observed MAC.
  networking.useDHCP = false;
  networking.bridges.br0.interfaces = [ "enp129s0" ];
  networking.interfaces.enp129s0.useDHCP = false;
  networking.interfaces.br0 = {
    useDHCP = true;
    macAddress = "9c:6b:00:96:f2:10";
  };
  networking.firewall.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [ "nvme" "ahci" "sd_mod" "xhci_pci" "usbhid" "raid1" ];
  boot.kernelModules = [ "kvm-intel" ];
  # Keep mdadm's monitor running and record RAID events in the journal.
  boot.swraid.mdadmConf = ''
    PROGRAM ${pkgs.writeShellScript "meawhite-raid-event" ''
      exec ${pkgs.util-linux}/bin/logger -t mdadm -- "$@"
    ''}
  '';
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # Use the integrated Intel graphics for the console. No VFIO or inference stack.
  zramSwap.enable = true;
  swapDevices = [ ];
  services.openssh = {
    settings = {
      # This headless host is administered through the bundled root public keys.
      PermitRootLogin = "prohibit-password";
      AuthorizedKeysFile = "/etc/ssh/authorized_keys.d/%u";
    };
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./authorized_keys ];
  environment.systemPackages = with pkgs; [ cryptsetup mdadm sbctl pciutils tpm2-tools helix git ];
  system.stateVersion = "26.05";

}
