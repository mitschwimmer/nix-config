{ pkgs, pkgs-unstable, ... }:
let
  resolvedHook = "${pkgs.update-systemd-resolved}/libexec/openvpn/update-systemd-resolved";

  vpn = file: {
    config = "config ${file}";
    up = resolvedHook;
    down = resolvedHook;
  };
in
{
  users.users.henner.extraGroups = [ "networkmanager" ];
  home-manager = {
    extraSpecialArgs = { inherit pkgs-unstable; };
    users.henner.imports = [ ../home/henner/desktop.nix ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.loader.timeout = 0;
  boot.plymouth.enable = true;

  nixpkgs.config.allowUnfree = true;

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

  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
  services.printing.enable = true;
  services.gvfs.enable = true;
  services.flatpak.enable = true;

  programs.niri.enable = true;
  security.polkit.enable = true;
  xdg.portal.xdgOpenUsePortal = true;

  # greetd handles authentication; Cage hosts the Quickshell login surface.
  services.greetd = {
    enable = true;
    settings.default_session = {
      user = "greeter";
      command = "${pkgs.cage}/bin/cage -s -- ${pkgs.quickshell}/bin/quickshell -p ${../../dotfiles/quickshell/greeter.qml}";
    };
  };

  # Used by the Wayland session locker inside the user Quickshell instance.
  security.pam.services.quickshell = { };

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

  environment.systemPackages = with pkgs; [
    nixfmt
    wget
    powertop
    usbutils # lsusb
    incus
  ];
}
