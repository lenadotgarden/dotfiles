{ config, lib, pkgs, ... }:

{
  imports = [
    ../../core/boot.nix
    ../../core/networking.nix
    ../../core/fonts.nix
    ../../core/packages.nix
    ./hardware-configuration.nix
    ./users.nix
  ];

  system.stateVersion = "25.11";
}
