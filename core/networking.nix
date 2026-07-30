{ config, lib, pkgs, ... }:

{
  networking.hostName = "nixos-macbook";
  networking.networkmanager.enable = true;
}
