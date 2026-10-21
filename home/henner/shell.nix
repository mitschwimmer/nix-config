{
  home.shellAliases = {
    la = "ls -lah";
    gs = "git status";
  };

  # Use the terminal's ANSI palette, following Ghostty's light/dark Gruvbox theme.
  home.file.".blerc".text = ''
    bleopt term_index_colors=16
    bleopt term_true_colors=
  '';

  programs.bash = {
    enable = true;
    enableCompletion = true;
    historySize = 10000;
    historyFileSize = 20000;
    historyControl = [
      "ignoreboth"
      "erasedups"
    ];
    initExtra = ''
      shopt -s checkwinsize
    '';
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = false;
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = false;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = false;
  };
}
