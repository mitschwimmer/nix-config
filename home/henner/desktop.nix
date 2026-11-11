{ pkgs, pkgs-unstable, ... }:
{
  xdg.configFile = {
    "foot/foot.ini".source = ../../dotfiles/foot/foot.ini;
    "niri/config.kdl".source = ../../dotfiles/niri/config.kdl;
    "gtk-3.0/bookmarks".source = ../../dotfiles/gtk-3.0/bookmarks;
  };

  programs.quickshell = {
    enable = true;
    configs.workstation = ../../dotfiles/quickshell;
    activeConfig = "workstation";
  };

  home.shellAliases = {
    prefer-light = "dconf write /org/gnome/desktop/interface/color-scheme \"'prefer-light'\"";
    prefer-dark = "dconf write /org/gnome/desktop/interface/color-scheme \"'prefer-dark'\"";
  };

  home.packages =
    (with pkgs; [
      # Desktop environment
      foot
      fuzzel
      pavucontrol
      xwayland-satellite
      nautilus
      adwaita-icon-theme
      swaylock
      brightnessctl
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
