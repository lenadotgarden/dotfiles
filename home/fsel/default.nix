{ pkgs, inputs, ... }:

{
  home.packages = [
    inputs.fsel.packages.${pkgs.system}.default
    (pkgs.writeShellScriptBin "quicklauncher" ''
      # Floating by the niri window rule on app-id "quicklauncher" (see flake.nix)
      exec kitty --class quicklauncher --name quicklauncher --title fsel \
        --override initial_window_width=1000px --override initial_window_height=650px \
        -e fsel -d -r "$@"
    '')
  ];

  xdg.configFile."fsel/config.toml".source = ../../config/fsel/config.toml;
}
