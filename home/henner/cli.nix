{ pkgs, ... }:
{
  home.packages = with pkgs; [
    doggo glow git delta dnsutils bat htop helix eza fd ripgrep libqalculate
  ];

  # Terminal configuration shared by workstations and servers.
  xdg.configFile = {
    "helix/config.toml".source = ../../dotfiles/helix/config.toml;
    "helix/languages.toml".source = ../../dotfiles/helix/languages.toml;

    # Git's includeIf entries in config reference these exact paths.
    "git/gitconfig-archaic".source = ../../dotfiles/git/gitconfig-archaic;
    "git/gitconfig-assense".source = ../../dotfiles/git/gitconfig-assense;
    "git/gitconfig-mitschwimmer".source = ../../dotfiles/git/gitconfig-mitschwimmer;
  };

  # Install the existing global Git configuration without translating or
  # changing conditional identity selection.
  home.file.".gitconfig".source = ../../dotfiles/git/config;
}
