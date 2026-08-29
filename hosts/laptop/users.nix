{ config, lib, pkgs, ... }:

{
  users.users.lena = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "3141";
  };

  # Autologin user lena on TTY1 to directly launch Hyprland on boot
  services.getty.autologinUser = "lena";
}
