{ pkgs, ... }:

{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
      fastfetch --logo nixos2

      # Auto-start Hyprland on TTY1 if not already inside a graphical session
      if test (tty) = "/dev/tty1"; and test -z "$WAYLAND_DISPLAY"
        exec Hyprland
      end
    '';
  };

  # Bash fallback to auto-exec fish for interactive shells
  programs.bash = {
    enable = true;
    initExtra = ''
      unset "Xft.dpi"
      if [[ $- == *i* ]] && [ -z "$NIX_BUILD_TOP" ] && [ -z "$FISH_VERSION" ]; then
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  };
}
