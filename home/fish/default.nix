{ pkgs, ... }:

{
  programs.fish = {
    enable = true;
    shellAliases = {
      pbcopy = "wl-copy";
      pbpaste = "wl-paste";
      v = "nvim";
      o = "nvim ~/Garden";
      gay = "agy";
      fsel = "quicklauncher";
      sleep = "systemctl suspend";
    };
    shellAbbrs = {
      v = "nvim";
      gay = "agy";
    };
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
