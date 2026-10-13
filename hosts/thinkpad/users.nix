{ config, lib, pkgs, ... }:

{
  users.users.lena = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" ];
    # No initialPassword here: the password set with `passwd` at install time is kept.
  };

  # The disk is LUKS-encrypted, so autologin only happens after the passphrase.
  # Logs in on TTY1, where zsh starts the compositor (see home/zsh).
  services.getty.autologinUser = "lena";
}
