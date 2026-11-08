{ lib, pkgs, modulesPath, targetSystem, recoveryPassphraseFile, ... }:
let
  partitioning = targetSystem.extendModules {
    modules = [ {
      disko.devices.disk.main.content.partitions.root.content.passwordFile =
        "/run/meawhite-recovery-passphrase";
      disko.devices.mdadm.meawhite-data.content.passwordFile =
        "/run/meawhite-recovery-passphrase";
    } ];
  };
  install = pkgs.writeShellApplication {
    name = "install-meawhite";
    runtimeInputs = with pkgs; [
      coreutils util-linux systemd cryptsetup mdadm nix nixos-install
    ] ++ [ checkDisks ];
    runtimeEnv = {
      MEAWHITE_SYSTEM = targetSystem.config.system.build.toplevel;
      MEAWHITE_DISKO_SCRIPT = partitioning.config.system.build.diskoScript;
      MEAWHITE_RECOVERY_FILE = recoveryPassphraseFile;
      MEAWHITE_AUTHORIZED_KEYS = "${./authorized_keys}";
    };
    text = builtins.readFile ./install.sh;
  };
  checkDisks = pkgs.writeShellApplication {
    name = "check-meawhite-disks";
    runtimeInputs = with pkgs; [ coreutils systemd util-linux jq gnugrep ];
    text = builtins.readFile ./check-disks.sh;
  };
in
{
  assertions = [ {
    assertion = builtins.match "[0-9a-f]{64}" (builtins.readFile recoveryPassphraseFile) != null;
    message = "The meawhite recovery file must contain exactly 64 lowercase hex characters without newline.";
  } ];
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  networking.hostName = "meawhite-installer";
  # Installation must work without network, including accidentally attached LAN.
  networking.useDHCP = lib.mkForce false;
  networking.wireless.enable = lib.mkForce false;
  networking.networkmanager.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;
  nix.settings = {
    substituters = lib.mkForce [ ];
    builders = lib.mkForce "";
    experimental-features = [ "nix-command" "flakes" ];
  };

  isoImage = {
    isoName = "meawhite-unattended.iso";
    volumeID = "MEAWHITE_INSTALL";
    appendToMenuLabel = " — ERASES THREE ALLOWLISTED DISKS";
    storeContents = [ targetSystem.config.system.build.toplevel install ];
    # Visible recovery file on the read-only ISO, usable from another computer.
    contents = [ { source = recoveryPassphraseFile; target = "/meawhite-recovery-passphrase"; } ];
  };
  boot.loader.timeout = lib.mkForce 1;
  boot.supportedFilesystems = lib.mkForce [ "vfat" "ext4" ];
  environment.systemPackages = [ install ];

  systemd.services.install-meawhite = {
    description = "Erase the three allowlisted disks and install meawhite offline";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" "local-fs.target" ];
    wants = [ "systemd-udev-settle.service" ];
    unitConfig.OnSuccess = "poweroff.target";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe install;
      TimeoutStartSec = "infinity";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
      # No automatic retries after a partial installation; boot USB again to retry.
      Restart = "no";
    };
  };
  system.stateVersion = "26.05";
}
