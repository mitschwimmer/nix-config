{ lib, pkgs, modulesPath, targetSystem, recoveryPassphraseFile, ... }:
let
  # Only the formatting script uses this runtime-created alias. The installed
  # system refers to GPT partition labels and /dev/mapper/cryptroot, not the alias.
  partitioning = targetSystem.extendModules {
    modules = [ {
      disko.devices.disk.main.device = lib.mkForce "/dev/disk/by-id/meablack-install-target";
      disko.devices.disk.main.content.partitions.root.content.passwordFile =
        "/run/meablack-recovery-passphrase";
    } ];
  };
  install = pkgs.writeShellApplication {
    name = "install-meablack";
    runtimeInputs = with pkgs; [
      coreutils util-linux systemd cryptsetup nix nixos-install
    ] ++ [ selectDisk ];
    runtimeEnv = {
      MEABLACK_SYSTEM = targetSystem.config.system.build.toplevel;
      MEABLACK_DISKO_SCRIPT = partitioning.config.system.build.diskoScript;
      MEABLACK_RECOVERY_FILE = recoveryPassphraseFile;
      MEABLACK_AUTHORIZED_KEYS = "${./authorized_keys}";
    };
    text = builtins.readFile ./install.sh;
  };
  selectDisk = pkgs.writeShellApplication {
    name = "select-meablack-disk";
    runtimeInputs = with pkgs; [ systemd util-linux jq gnugrep ];
    text = builtins.readFile ./select-disk.sh;
  };
in
{
  assertions = [ {
    assertion = builtins.match "[0-9a-f]{64}" (builtins.readFile recoveryPassphraseFile) != null;
    message = "The meablack recovery file must contain exactly 64 lowercase hex characters without newline.";
  } ];
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  networking.hostName = "meablack-installer";
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
    isoName = "meablack-unattended.iso";
    volumeID = "MEABLACK_INSTALL";
    appendToMenuLabel = " — ERASES THE INTERNAL DISK";
    storeContents = [ targetSystem.config.system.build.toplevel install ];
    # Visible recovery file on the read-only ISO, usable from another computer.
    contents = [ { source = recoveryPassphraseFile; target = "/meablack-recovery-passphrase"; } ];
  };
  boot.loader.timeout = lib.mkForce 1;
  boot.supportedFilesystems = lib.mkForce [ "vfat" "ext4" ];
  environment.systemPackages = [ install ];

  systemd.services.install-meablack = {
    description = "Erase the sole internal disk and install meablack offline";
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
