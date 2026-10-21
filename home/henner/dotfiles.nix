{ ... }:
{
  # Preserve the original application configurations exactly during migration.
  xdg.configFile = {
    "ghostty/config".source = ../../dotfiles/ghostty/config;
    "helix/config.toml".source = ../../dotfiles/helix/config.toml;
    "helix/languages.toml".source = ../../dotfiles/helix/languages.toml;
    "quickshell/shell.qml".source = ../../dotfiles/quickshell/shell.qml;
    "gtk-3.0/bookmarks".source = ../../dotfiles/gtk-3.0/bookmarks;

    # Git's includeIf entries in config reference these exact paths.
    "git/gitconfig-archaic".source = ../../dotfiles/git/gitconfig-archaic;
    "git/gitconfig-assense".source = ../../dotfiles/git/gitconfig-assense;
    "git/gitconfig-mitschwimmer".source = ../../dotfiles/git/gitconfig-mitschwimmer;
  };

  # Install the existing global Git configuration without translating or
  # changing conditional identity selection.
  home.file.".gitconfig".source = ../../dotfiles/git/config;
}
