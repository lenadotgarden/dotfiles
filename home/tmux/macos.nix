{ ... }:

{
  # Réglages complémentaires migrés depuis l'ancienne config tmux
  # pre-nix de macOS (~/.config/tmux.pre-nix-backup/tmux.conf).
  # Le reste (prefix C-s, escape-time, history-limit, nav vim des panes...)
  # est déjà couvert par ../tmux/default.nix, partagé avec le host Linux.
  programs.tmux.extraConfig = ''
    setw -g pane-base-index 1
    setw -g clock-mode-style 12
  '';
}
