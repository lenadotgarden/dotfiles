{ config, lib, pkgs, ... }:

{
  # networking.hostName is set in each host's default.nix
  networking.networkmanager.enable = true;
}
