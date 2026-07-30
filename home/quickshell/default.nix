{ pkgs, ... }:

{
  home.packages = [ pkgs.quickshell ];

  xdg.configFile."quickshell" = {
    source = ../../config/quickshell;
    recursive = true;
  };
}
