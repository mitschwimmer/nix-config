{ pkgs, pkgs-unstable, lib, ... }:
let
  lockConfig = pkgs.runCommand "workstation-lock-config" { } ''
    mkdir -p "$out"
    cp -R ${../../dotfiles/quickshell-lock}/. "$out/"
    ln -s ${../../dotfiles/quickshell/DotClock.qml} "$out/DotClock.qml"
  '';
  lock = pkgs.writeShellApplication {
    name = "workstation-lock";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if systemctl --user is-active --quiet workstation-lock-fallback.service; then
        exit 0
      fi
      if ! systemctl --user start workstation-lock.service; then
        systemctl --user start workstation-lock-fallback.service
      fi
    '';
  };
  start = pkgs.writeShellApplication {
    name = "workstation-lock-start";
    runtimeInputs = [ pkgs.python3 pkgs.niri pkgs.grim ];
    text = ''
      exec python3 ${../../dotfiles/quickshell-lock/capture.py} ${lib.getExe pkgs-unstable.quickshell}
    '';
  };
in
{
  programs.quickshell.configs.workstation-lock = lockConfig;
  home.packages = [ lock ];

  systemd.user.services.workstation-lock = {
    Unit = {
      Description = "Quickshell session lock";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      OnFailure = [ "workstation-lock-fallback.service" ];
    };
    Service = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = lib.getExe start;
      Environment = [
        "WORKSTATION_LOCK_NOTIFY=${pkgs.systemd}/bin/systemd-notify"
        "QT_QPA_PLATFORM=wayland"
      ];
      RuntimeDirectory = "workstation-lock";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      TimeoutStartSec = 5;
      TimeoutStopSec = 2;
    };
  };

  systemd.user.services.workstation-lock-fallback = {
    Unit = {
      Description = "Emergency Swaylock session lock";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "forking";
      ExecStart = "${pkgs.swaylock}/bin/swaylock --daemonize -K -c 000000";
      TimeoutStartSec = 5;
    };
  };

  services.swayidle = {
    enable = true;
    # No automatic idle timeout: only explicit logind locks and suspend.
    events = {
      lock = lib.getExe lock;
      before-sleep = lib.getExe lock;
    };
  };
}
