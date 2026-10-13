{ config, lib, pkgs, ... }:

let
  wallpaperSearch = pkgs.writeShellScriptBin "wallpaper-search" ''
    export PATH=${lib.makeBinPath (with pkgs; [ curl jq rofi feh libnotify findutils coreutils gnugrep ])}:$PATH
    ${builtins.readFile ./wallpaper-search.sh}
  '';
in
{
  home.packages = with pkgs; [
    xmobar rofi rofimoji xdotool xclip feh xss-lock i3lock picom libnotify
    xsetroot xset xrdb xmessage
    kdePackages.dolphin
    wallpaperSearch
  ];

  home.sessionVariables.DEFAULT_WM = lib.mkDefault "xmonad";

  # Recompiled by xmonad itself at login. Drop the cached binary when the source changes.
  home.file.".xmonad/xmonad.hs" = {
    source = ./xmonad.hs;
    onChange = "rm -f $HOME/.xmonad/xmonad-x86_64-linux $HOME/.cache/xmonad/xmonad-x86_64-linux $HOME/.xmonad/xmonad.hi $HOME/.xmonad/xmonad.o";
  };
  home.file.".xmobarrc".source = ./xmobarrc;
  xdg.configFile."picom/picom.conf".source = ./picom.conf;

  home.file.".xinitrc" = {
    executable = true;
    text = ''
      #!/bin/sh
      [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
      xsetroot -cursor_name left_ptr
      # last wallpaper picked with wallpaper-search (Super+W), else a plain colour
      wp="$(cat "$HOME/.cache/wallpaper/current" 2>/dev/null)"
      if [ -n "$wp" ] && [ -f "$wp" ]; then
        feh --bg-fill "$wp"
      else
        xsetroot -solid '#11111b'
      fi
      picom -b
      # screen blank after 10 min (5 s warning), DPMS off after 15 min
      xset s 600 5
      xset dpms 0 0 900
      xss-lock --transfer-sleep-lock -- i3lock -n -c 11111b &
      exec xmonad
    '';
  };
}
