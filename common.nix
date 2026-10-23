{ pkgs, ... }:
let
  resolvedHook = "${pkgs.update-systemd-resolved}/libexec/openvpn/update-systemd-resolved";

  vpn = file: {
    config = "config ${file}";
    up = resolvedHook;
    down = resolvedHook;
  };
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.loader.timeout = 0;
  boot.plymouth.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console.useXkbConfig = true;

  virtualisation.podman.enable = true;

  # Do not delay boot while NetworkManager initializes the network.
  systemd.services.NetworkManager-wait-online.enable = false;
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  # Allow access to VIAL keyboard firmware.
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';

  services.fwupd.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      MaxAuthTries = 3;
      PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
  services.printing.enable = true;
  services.gvfs.enable = true;
  services.flatpak.enable = true;

  programs.niri.enable = true;
  xdg.portal.xdgOpenUsePortal = true;

  services.displayManager = {
    ly.enable = true;
    defaultSession = "niri";
    autoLogin = {
      enable = true;
      user = "henner";
    };
  };

  # Allow user processes to request realtime scheduling.
  security.rtkit.enable = true;

  # Use systemd-resolved for VPN DNS updates.
  services.resolved.enable = true;
  services.openvpn.servers = {
    officeVPN = vpn "/root/office.ovpn";
    lblVPN = vpn "/root/lbl.ovpn";
  };

  programs.firefox.enable = true;
  programs.chromium.enable = true;
  programs.localsend.enable = true;

  # Keep this font selection instead of the graphical desktop default set.
  fonts.enableDefaultPackages = false;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-lgc-plus
    dejavu_fonts
    freefont_ttf
    gyre-fonts
    liberation_ttf
    unifont
    inter
    noto-fonts-color-emoji
  ];

  # Keep system-wide Bash and ble.sh support; user preferences live in Home Manager.
  programs.bash = {
    enable = true;
    blesh.enable = true;
    completion.enable = true;
  };

  environment.sessionVariables.EDITOR = "hx";
  environment.systemPackages = with pkgs; [
    nixfmt
    wget
    powertop
    usbutils # lsusb
    incus
  ];
}
