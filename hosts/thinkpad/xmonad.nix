{ config, lib, pkgs, ... }:

# X11 + xMonad session for the ThinkPad (fast to build, everything is cached).
# Started from TTY1 by zsh (`startx`), which reads ~/.xinitrc (home/desktops/xmonad).
{
  services.xserver = {
    enable = true;
    windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true; # xmonad-contrib + extras; user config is recompiled at runtime
    };
    displayManager.startx.enable = true;
    autoRepeatDelay = 250;
    autoRepeatInterval = 40;
  };

  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = true;
      disableWhileTyping = true;
    };
  };

  # home-manager's dconf.settings needs the dconf D-Bus service at activation
  # (its absence made home-manager-lena.service fail)
  programs.dconf.enable = true;

  # Screen locker (xss-lock + i3lock) needs its PAM service
  programs.i3lock.enable = true;

  # Backlight keys without root
  services.udev.packages = [ pkgs.brightnessctl ];
  users.users.lena.extraGroups = [ "video" ];
}
