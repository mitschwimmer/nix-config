{
  pkgs,
  pkgs-unstable,
  ...
}:
{
  users.users.henner = {
    isNormalUser = true;
    description = "Henner";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];

    packages = with pkgs; [

      # Desktop Environment
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

      # apps
      recordbox
      vlc
      decibels
      pkgs-unstable.enpass
      pkgs-unstable.libreoffice
      pkgs-unstable.gthumb
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

      # terminal tools
      wl-clipboard
      acpi # show power state of the battery
      doggo # DNS query tool
      glow
    ];
  };

}
