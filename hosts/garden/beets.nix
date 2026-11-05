{ config, lib, pkgs, ... }:

let
  musicMount = "/mnt/music";

  beetsConfig = (pkgs.formats.yaml { }).generate "beets-config.yaml" {
    directory = musicMount;
    library = "/var/lib/beets/library.db";

    # On ne bouge / copie / renomme jamais les fichiers : Lidarr gère déjà
    # l'organisation des dossiers. beets ne fait que lire/corriger les tags
    # et aider à repérer les doublons.
    import = {
      move = false;
      copy = false;
      write = true;
      resume = "ask";
      incremental = true;
    };

    plugins = [ "fetchart" "embedart" "duplicates" "missing" "scrub" ];

    fetchart = {
      auto = true;
      sources = [ "coverart" "itunes" ];
    };

    duplicates = {
      album = true;
      checksum = false;
    };
  };
in
{
  environment.systemPackages = [ pkgs.beets ];

  environment.etc."beets/config.yaml".source = beetsConfig;

  # beets ne lit pas /etc/beets automatiquement sans BEETSDIR.
  environment.variables.BEETSDIR = "/etc/beets";

  systemd.tmpfiles.rules = [
    "d /var/lib/beets 0750 ubuntu users -"
  ];
}
