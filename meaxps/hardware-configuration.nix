{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];
  boot.initrd.systemd.enable = true;
  boot.kernelModules = [ "kvm-intel" ];

  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernelParams = [
    "quiet"
    "splash"
    "mem_sleep_default=deep"
  ];
  boot.extraModulePackages = [ ];

  powerManagement = {
    enable = true;
  };
  networking.hostName = "meaxps";

  services.tlp.enable = true;
  services.xserver.xkb = {
    layout = "gb,de";
    variant = ",us";
    options = "grp:alt_shift_toggle,compose:ralt"; # Tastenkombination zum Wechseln zwischen den Layouts
  };

  boot.initrd.luks.devices = {
    # Devices here need to be addressed via UUID even when they have a label
    # Use 'blkid' to find the correct UUID
    encrypted_root = {
      device = "/dev/disk/by-uuid/00e8acec-5a7a-48c5-a4b5-737b45111b60";
    };
    encrypted_swap = {
      device = "/dev/disk/by-uuid/fba5d436-dd5c-445a-a0a2-42ebb051b0a3";
    };
  };

  fileSystems."/" = {
    device = "/dev/mapper/encrypted_root";
    fsType = "ext4";
  };

  swapDevices = [
    {
      device = "/dev/mapper/encrypted_swap";
    }
  ];

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/EC99-87B5";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
