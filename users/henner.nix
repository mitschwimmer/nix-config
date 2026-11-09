{
  users.users.henner = {
    isNormalUser = true;
    description = "Henner";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [ ./henner/authorized_keys ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.henner = import ../home/henner;
  };
}
