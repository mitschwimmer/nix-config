{
  imports = [
    ./cli.nix
    ./shell.nix
    ./tmux.nix
  ];

  home = {
    username = "henner";
    homeDirectory = "/home/henner";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
