{
  home.shellAliases = {
    la = "ls -lah";
    gs = "git status";
    k = "kubecolor";
  };

  # Use the terminal's ANSI palette, following Foot's Gruvbox theme.
  home.file.".blerc".text = ''
    bleopt term_index_colors=16
    bleopt term_true_colors=
    ble-face auto_complete='fg=8,italic'
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
      # Share commands across interactive shells, including nix develop/shell.
      PROMPT_COMMAND="history -a; history -n''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

      # Initialize kubectl completion only when k is completed.
      _k_completion() {
        if command -v kubectl >/dev/null 2>&1; then
          source <(kubectl completion bash)
          complete -o default -F __start_kubectl k
          __start_kubectl "$@"
        fi
      }
      complete -o default -F _k_completion k
    '';
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    presets = [ "plain-text-symbols" ];
    settings = {
    shlvl = {
      disabled = false;
      threshold = 3;
      symbol = "⧉ ";
      format = "[$symbol]($style)";
      style = "bold blue";
    };
  };
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
