{
  programs.tmux = {
    enable = true;
    prefix = "M-`";
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    baseIndex = 1;
    terminal = "tmux-256color";
    escapeTime = 10;

    extraConfig = ''
      set -as terminal-features ',foot*:RGB'

      # Directional splitting: prefix + s, then h/j/k/l.
      bind -N "Split pane (h/j/k/l)" s switch-client -T split
      bind -T split -N "Split left" h split-window -h -b
      bind -T split -N "Split down" j split-window -v
      bind -T split -N "Split up" k split-window -v -b
      bind -T split -N "Split right" l split-window -h

      # Annotated window bindings for built-in keybinding help.
      bind -N "Create window" c new-window
      bind -N "Next window" n next-window

      # Minimal status line using the terminal's own colors.
      set -g status-position bottom
      set -g status-justify left
      set -g status-style "fg=default,bg=default"
      set -g status-left "#[reverse,bold] #{host_short} #[default] │ "
      set -g status-left-length 40
      set -g status-right ""
      set -g window-status-separator ""
      set -g window-status-format " #I:#W "
      set -g window-status-style "dim"
      set -g window-status-current-format " #I:#W "
      set -g window-status-current-style "reverse,bold"
    '';
  };
}
