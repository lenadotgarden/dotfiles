{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    xmobar rofi rofimoji xdotool xclip feh xss-lock i3lock
    xsetroot xset xrdb xmessage
    kdePackages.dolphin
  ];

  home.sessionVariables.DEFAULT_WM = lib.mkDefault "xmonad";

  # Recompiled by xmonad itself at login. Drop the cached binary when the source changes.
  home.file.".xmonad/xmonad.hs" = {
    source = ./xmonad.hs;
    onChange = "rm -f $HOME/.xmonad/xmonad-x86_64-linux $HOME/.cache/xmonad/xmonad-x86_64-linux $HOME/.xmonad/xmonad.hi $HOME/.xmonad/xmonad.o";
  };
  home.file.".xmobarrc".source = ./xmobarrc;

  home.file.".xinitrc" = {
    executable = true;
    text = ''
      #!/bin/sh
      [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
      xsetroot -cursor_name left_ptr
      if [ -f "$HOME/.cache/wal/wal" ] && [ -f "$(cat "$HOME/.cache/wal/wal")" ]; then
        feh --bg-fill "$(cat "$HOME/.cache/wal/wal")"
      else
        xsetroot -solid '#11111b'
      fi
      # screen blank after 10 min (5 s warning), DPMS off after 15 min
      xset s 600 5
      xset dpms 0 0 900
      xss-lock --transfer-sleep-lock -- i3lock -n -c 11111b &
      exec xmonad
    '';
  };
}
