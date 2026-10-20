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

  boot.initrd.luks.devices = {
    encrypted_root = {
      device = "/dev/disk/by-uuid/247a442b-20ea-42ef-a41c-45450c070c06";
    };
    encrypted_swap = {
      device = "/dev/disk/by-uuid/0a995aba-d644-44fe-a86e-38ae467ccbfa";
    };
  };

  boot.zswap = {
    enable = true;
    compressor = "lz4";
  };
  boot.kernel.sysctl."vm.swappiness" = 100;

  boot.kernelModules = [
    "v4l2loopback"
    "kvm-intel"
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "quiet"
    "splash"
    "mem_sleep_default=deep"
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];

  hardware.cpu.intel.npu.enable = true;
  networking.hostName = "meanovo";

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
    device = "/dev/nvme0n1p1";
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

}
