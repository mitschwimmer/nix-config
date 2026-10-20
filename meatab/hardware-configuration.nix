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
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sdhci_pci"
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

  networking.hostName = "meatab";

  powerManagement = {
    enable = true;
    powerDownCommands = "${pkgs.coreutils}/bin/sh -c 'echo AWAC > /proc/acpi/wakeup'";
  };

  services.tlp.enable = true;
  services.xserver.xkb = {
    layout = "de,de";
    variant = ",us";
    options = "grp:alt_shift_toggle"; # Tastenkombination zum Wechseln zwischen den Layouts
  };

  boot.initrd.luks.devices = {
    encrypted_root = {
      device = "/dev/disk/by-uuid/f30127f7-1ea9-485a-98b6-91cfa1061710";
    };
    encrypted_swap = {
      device = "/dev/disk/by-uuid/acca56f6-57ab-44be-8ccc-733d387be835";
    };
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/051E-F535";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
