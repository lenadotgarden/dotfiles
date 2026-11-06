{ ... }:
{
  ############################################################
  # hermes-vault-acl — corrige le bug historique "1 fois sur 10" de
  # lecture/écriture sur /opt/vault : le dossier était en 755/644 (groupe
  # hermes en lecture seule) et l'umask des processus écrivains (022)
  # retirait de toute façon le bit d'écriture groupe sur tout ce qui était
  # créé. Les ACL POSIX par défaut ci-dessous s'appliquent aux nouveaux
  # fichiers/dossiers indépendamment de l'umask du processus qui écrit
  # (conteneur Syncthing 10000:10000, ubuntu via nvim, ou Hermes) — donc
  # fiable à 100% au lieu de "parfois".
  ############################################################
  flake.modules.nixos."hermes-vault-acl" = { config, lib, pkgs, ... }: {
    systemd.services.garden-vault-acl = {
      description = "Corrige les permissions/ACL de /opt/vault (groupe hermes rw partout)";
      after = [ "local-fs.target" ];
      before = [ "garden-compose-syncthing.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.acl pkgs.findutils ];
      serviceConfig = { Type = "oneshot"; };
      script = ''
        set -eu
        V=/opt/vault
        [ -d "$V" ] || exit 0
        find "$V" -type d -exec chmod 2775 {} +
        find "$V" -type f ! -perm -u+x -exec chmod 664 {} +
        find "$V" -type f -perm -u+x -exec chmod 775 {} +
        setfacl -R -m g:hermes:rwX -d -m g:hermes:rwX "$V"
      '';
    };

    systemd.timers.garden-vault-acl = {
      description = "Ré-applique périodiquement les ACL de /opt/vault (dérive Syncthing)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "15min";
      };
    };
  };
}
