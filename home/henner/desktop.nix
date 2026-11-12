{ pkgs, pkgs-unstable, ... }:
{
  imports = [ ./lockscreen.nix ];

  xdg.configFile = {
    "foot/foot.ini".source = ../../dotfiles/foot/foot.ini;
    "niri/config.kdl".source = ../../dotfiles/niri/config.kdl;
    "gtk-3.0/bookmarks".source = ../../dotfiles/gtk-3.0/bookmarks;
  };

  programs.quickshell = {
    enable = true;
    package = pkgs-unstable.quickshell;
    configs.workstation = ../../dotfiles/quickshell;
    activeConfig = "workstation";
  };

  home.packages =
    (with pkgs; [
      # Desktop environment
      foot
      pavucontrol
      xwayland-satellite
      nautilus
      adwaita-icon-theme
      swaylock
      brightnessctl
      dconf
      sushi
      guvcview

      # Applications
      recordbox
      vlc
      decibels
      signal-desktop
      ungoogled-chromium
      halftone
      newsflash
      gnome-sound-recorder
      easyeffects
      prismlauncher
      papers
      calibre
      teams-for-linux
      gimp
      baobab
      keepassxc

      # Workstation utilities
      wl-clipboard
      acpi
    ])
    ++ (with pkgs-unstable; [
      enpass
      libreoffice
      gthumb
      godot
    ]);
}
