{ config, lib, pkgs, inputs, ... }:

{
  ############################################################
  # comin — GitOps : poll le repo toutes les 60s, rebuild+switch si la
  # branche main a bougé, retente indéfiniment en cas d'échec de build
  # (le système en cours ne change pas tant que le nouveau n'a pas buildé).
  ############################################################
  services.comin = {
    enable = true;
    package = inputs.comin.packages.aarch64-linux.default;
    hostname = "garden";
    remotes = [
      {
        name = "origin";
        url = "https://github.com/lenadotgarden/dotfiles";
        branches.main = {
          name = "main";
          operation = "switch";
        };
        poller.period = 60;
      }
    ];
  };
}
