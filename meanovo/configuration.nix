{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

let
  # Match NixOS's default SDDM Weston keyboard/libinput settings and add
  # HiDPI scaling for the built-in OLED. Unspecified outputs remain at 1x.
  sddmWestonConfig = (pkgs.formats.ini { }).generate "meanovo-sddm-weston.ini" {
    libinput = {
      enable-tap = config.services.libinput.mouse.tapping;
      left-handed = config.services.libinput.mouse.leftHanded;
    };
    keyboard = {
      keymap_model = config.services.xserver.xkb.model;
      keymap_layout = config.services.xserver.xkb.layout;
      keymap_variant = config.services.xserver.xkb.variant;
      keymap_options = config.services.xserver.xkb.options;
    };
    output = {
      name = "eDP-1";
      scale = 2;
    };
  };
in
{
  imports = [ ./hardware-configuration.nix ];
  system.stateVersion = "26.05";

  # Initialize Intel graphics in the initrd before Plymouth.
  boot.initrd.kernelModules = [ "xe" ];

  # Preserve the firmware's chosen GOP mode instead of switching to "max".
  # The later KMS/greeter mode may still differ; test on the real display.
  boot.loader.systemd-boot.consoleMode = lib.mkForce "keep";
  # The secure default and explicit legacy recovery both keep four entries.
  boot.loader.systemd-boot.configurationLimit = 4;

  # Weston's integer 2x scale is closest to Niri's 1.75x laptop scale.
  # Keep the external displays at their default 1x; do not change Niri.
  services.displayManager.sddm.settings.Wayland.CompositorCommand =
    "${lib.getExe pkgs.weston} --shell=kiosk -c ${sddmWestonConfig}";

  # Keep signing, recovery and diagnostic tools available locally.
  environment.systemPackages = with pkgs; [
    cryptsetup
    sbctl
    tpm2-tools
    pciutils
  ];
}
