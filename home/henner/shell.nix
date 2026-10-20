{
  home.shellAliases = {
    la = "ls -lah";
    gs = "git status";
  };

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

  programs.fish.enable = true;

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };
}
