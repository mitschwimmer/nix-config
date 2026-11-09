{ lib, pkgs, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  time.timeZone = "Europe/Berlin";
  environment.sessionVariables.EDITOR = "hx";
  # Keep system-wide Bash and ble.sh support; user preferences live in Home Manager.
  programs.bash = {
    enable = true;
    blesh.enable = true;
    completion.enable = true;
  };

  # Make Foot's terminal description available on SSH destinations too.
  environment.systemPackages = [ pkgs.foot.terminfo ];

  services.openssh = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
    settings = {
      AuthenticationMethods = "publickey";
      PubkeyAuthentication = true;
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitEmptyPasswords = false;
      PermitRootLogin = lib.mkDefault "no";
      MaxAuthTries = 3;
      LoginGraceTime = 30;
      X11Forwarding = false;
      PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
    };
  };
}
