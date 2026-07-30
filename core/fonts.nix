{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    iosevka-bin
    nerd-fonts.symbols-only
  ];
}
