{ lib, ... }:
{
  # Import only after creating/backing up keys and confirming the machine
  # supports custom Secure Boot key enrollment. See meablack/README.md.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
