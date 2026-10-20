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
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.initrd.systemd.enable = true;

  boot.initrd.luks.devices = {
    encrypted_root = {
      device = "/dev/disk/by-uuid/bfa890b4-55af-49d3-abbe-4fbd020045ea";
    };
    encrypted_swap = {
      device = "/dev/disk/by-uuid/22ef3ad6-c8ca-4acc-93dc-7aa30a152da6";
    };
  };

  boot.kernelModules = [ "kvm-intel" ];

  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernelParams = [
    "quiet"
    "splash"
    "mem_sleep_default=deep"
    "plymouth.force-scale=1"
    "zswap.enabled=1"
    "acpi_mask_gpe=0x6E" # There is an ACPI Event Storm on IRQ9
  ];

  boot.extraModulePackages = [ ];

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  networking.hostName = "mearock";

  services.tlp.enable = true;
  services.xserver.xkb = {
    layout = "de";
    variant = "us";
  };

  fileSystems."/" = {
    device = "/dev/mapper/encrypted_root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    {
      device = "/dev/mapper/encrypted_swap";
    }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
