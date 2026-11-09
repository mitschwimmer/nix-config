{ config, ... }:
{
  home.shellAliases = {
    la = "ls -lah";
    gs = "git status";
    k = "kubecolor";
  };

  # Use the terminal's ANSI palette, following Foot's Gruvbox theme.
  home.file.".blerc".text = ''
    # Alt+Up inserts the previous command's last argument, like Alt+period.
    ble-bind -m emacs -f 'M-up' insert-last-argument
    ble-bind -m lastarg -f 'M-up' lastarg/next

    # Run commands without submitting the line currently being edited.
    ble-bind -m emacs -c 'M-left' 'cd -'
    ble-bind -m emacs -c 'M-t' 'eza --tree'

    # Load fzf through ble.sh, then bind history search with the current input.
    _ble_contrib_fzf_base=${config.programs.fzf.package}/share/fzf
    ble-import -d integration/fzf-completion
    ble-import -d integration/fzf-key-bindings -C '
      ble-bind -m emacs -x up fzf-history-widget
    '

    bleopt term_index_colors=16
    bleopt term_true_colors=
    ble-face auto_complete='fg=8,italic'

    # Follow both Foot themes without fixed foreground/background pairs.
    ble-face region='reverse'
    ble-face region_insert='reverse'
    ble-face region_match='underline,bold'
    ble-face region_target='reverse,bold'
    ble-face overwrite_mode='reverse'

    ble-face syntax_error='fg=1,underline,bold'
    ble-face syntax_history_expansion='fg=5,bold'

    ble-face filename_directory_sticky='fg=4,underline,bold'
    ble-face filename_orphan='fg=1,underline'
    ble-face filename_setuid='fg=5,underline,bold'
    ble-face filename_setgid='fg=3,underline,bold'
    ble-face filename_socket='fg=6,underline'
    ble-face filename_pipe='fg=2,underline'
    ble-face filename_character='underline,bold'
    ble-face filename_block='fg=3,underline'
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
    # ble.sh loads fzf's completion and key bindings from .blerc.
    enableBashIntegration = false;
    enableFishIntegration = false;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = false;
  };
}
