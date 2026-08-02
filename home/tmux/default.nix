{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    shortcut = "s";
    baseIndex = 1;
    newSession = true;
    escapeTime = 0;
    historyLimit = 10000;
    terminal = "screen-256color";
    extraConfig = ''
      # vim-style pane navigation
      bind h select-pane -L
      bind l select-pane -R
      bind j select-pane -D
      bind k select-pane -U
      bind-key b set-option status
    '';
  };
}
