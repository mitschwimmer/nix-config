{
  imports = [
    ./packages.nix
    ./shell.nix
    ./dotfiles.nix
  ];

  home = {
    username = "henner";
    homeDirectory = "/home/henner";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
