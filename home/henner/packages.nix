{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      # Desktop environment
      fuzzel
      pavucontrol
      xwayland-satellite
      nautilus
      adwaita-icon-theme
      swaylock
      brightnessctl
      playerctl
      mako
      swayosd
      sushi
      guvcview
      quickshell

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
      ghostty
      calibre
      teams-for-linux
      gimp
      baobab
      keepassxc

      # CLI
      wl-clipboard
      acpi
      doggo
      glow
      git
      delta
      dnsutils
      bat
      htop
      helix
      eza
      fd
      ripgrep
      libqalculate
    ])
    ++ (with pkgs-unstable; [
      enpass
      libreoffice
      gthumb
      godot
    ]);
}
