{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    iosevka-bin
  ];
}
