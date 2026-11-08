{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ ./disko.nix (modulesPath + "/installer/scan/not-detected.nix") ];
  networking.hostName = "meawhite";
  networking.useDHCP = lib.mkDefault true;
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
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  time.timeZone = "Europe/Berlin";
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
      AuthorizedKeysFile = "/etc/ssh/authorized_keys.d/%u";
    };
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./authorized_keys ];
  environment.systemPackages = with pkgs; [ cryptsetup mdadm sbctl pciutils tpm2-tools helix git ];
  system.stateVersion = "26.05";
}
