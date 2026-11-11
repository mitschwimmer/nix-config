{
  config,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];
  system.stateVersion = "26.05";

  # Preserve the firmware's chosen GOP mode instead of switching to "max".
  # The later KMS/greeter mode may still differ; test on the real display.
  boot.loader.systemd-boot.consoleMode = lib.mkForce "keep";

  # Keep local recovery and diagnostics tools available before Secure Boot.
  environment.systemPackages = with pkgs; [
    cryptsetup
    sbctl
    tpm2-tools
    pciutils
  ];
}
