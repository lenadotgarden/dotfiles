{ pkgs, inputs, ... }:

{
  home.packages = [
    inputs.fsel.packages.${pkgs.system}.default
    (pkgs.writeShellScriptBin "quicklauncher" ''
      hyprctl dispatch exec "[float; size 1000 650; center]" "kitty --class quicklauncher --name quicklauncher --title fsel -e fsel -d $@"
    '')
  ];

  xdg.configFile."fsel/config.toml".source = ../../config/fsel/config.toml;
}
