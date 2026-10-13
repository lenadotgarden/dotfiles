{ config, lib, pkgs, ... }:

{
  imports = [
    ../../core/boot.nix
    ../../core/networking.nix
    ../../core/fonts.nix
    ../../core/packages.nix
    ./asahi.nix
    ./hardware-configuration.nix
    ./users.nix
  ];

  networking.hostName = "nixos-macbook";

  system.stateVersion = "25.11";
}
