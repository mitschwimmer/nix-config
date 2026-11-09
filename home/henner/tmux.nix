{
  programs.tmux = {
    enable = true;
    prefix = "C-b";
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

      # Center the host and all windows as one group.
      # Rounded Powerline caps use the configured Nerd Font; colors stay native.
      set -g status-position bottom
      set -g status-style "fg=default,bg=default"
      set -g status-left "#[reverse,bold] #{host_short} #[default] │ "
      set -g window-status-format " #I:#W "
      set -g window-status-current-format "#[reverse,bold] #I:#W #[default]"
      set -g status-format[0] '#[align=centre]#{E:status-left}#{W:#[dim]#{E:window-status-format}#[default],#{E:window-status-current-format}}'
    '';
  };
}
