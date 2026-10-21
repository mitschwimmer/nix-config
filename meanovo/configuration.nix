{
  config,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];
  system.stateVersion = "26.05";

  environment.systemPackages = with pkgs; [

  ];
}
