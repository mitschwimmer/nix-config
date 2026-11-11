{ lib, ... }:
{
  # The secure default requires provisioned and backed-up signing keys.
  # See meanovo/README.md; never enroll firmware keys automatically.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # Use systemd-cryptsetup and TPM2 tokens in both LUKS2 devices.
  # Without enrolled TPM tokens, the passphrase/recovery slot remains usable.
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.tpm2.enable = true;
  boot.initrd.luks.devices = {
    encrypted_root.crypttabExtraOpts = [ "tpm2-device=auto" ];
    encrypted_swap.crypttabExtraOpts = [ "tpm2-device=auto" ];
  };
}
