{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    ./disko.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "meablack";
  networking.useDHCP = lib.mkDefault true;
  networking.firewall.enable = true;

  # First boot uses systemd-boot. Secure Boot is a separate, staged migration.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [ "nvme" "ahci" "xhci_pci" "usbhid" ];
  boot.kernelModules = [ "kvm-intel" ];

  nixpkgs.config.allowUnfree = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

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
    };
  };

  # Populated from https://github.com/mitschwimmer.keys during provisioning.
  # Never fetch mutable SSH keys automatically during boot.
  services.openssh.settings.AuthorizedKeysFile = "/etc/ssh/authorized_keys.d/%u";

  environment.systemPackages = with pkgs; [
    cryptsetup
    sbctl
    pciutils
    tpm2-tools
    helix
    git
    python312
    uv
    cmake
    gnumake
    gcc
    pkg-config
  ];

  # Strata's downloaded Linux engine is not Nix-built; enable compatibility
  # for dynamically linked binaries. Provision its user-level runtime separately.
  programs.nix-ld.enable = true;
  hardware.graphics.enable = true;
  system.stateVersion = "26.05";
}
