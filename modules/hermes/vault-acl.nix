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
  #
  # Même traitement pour /var/lib/hermes/incoming (2026-11-07) : c'est le
  # dépôt où `ubuntu` dépose des fichiers pour Hermes (ex. cookies
  # chiffrés .age). scp les crée ubuntu:hermes 644 — hermes pouvait déjà
  # les SUPPRIMER (l'unlink dépend des droits du DOSSIER, pas du fichier,
  # tant qu'il n'y a pas de sticky bit — il n'y en a pas ici), mais pas
  # les ÉCRASER (shred a besoin d'écrire le contenu du fichier lui-même).
  # Mêmes ACL par défaut que /opt/vault : les fichiers déposés par
  # n'importe qui deviennent group-rw pour hermes, donc shreddables.
  ############################################################
  flake.modules.nixos."hermes-vault-acl" = { config, lib, pkgs, ... }: {
    systemd.services.garden-vault-acl = {
      description = "Corrige les permissions/ACL de /opt/vault et /var/lib/hermes/incoming (groupe hermes rw partout)";
      after = [ "local-fs.target" ];
      before = [ "garden-compose-syncthing.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.acl pkgs.findutils ];
      serviceConfig = { Type = "oneshot"; };
      script = ''
        set -eu
        V=/opt/vault
        if [ -d "$V" ]; then
          find "$V" -type d -exec chmod 2775 {} +
          find "$V" -type f ! -perm -u+x -exec chmod 664 {} +
          find "$V" -type f -perm -u+x -exec chmod 775 {} +
          setfacl -R -m g:hermes:rwX -d -m g:hermes:rwX "$V"
        fi
        I=/var/lib/hermes/incoming
        if [ -d "$I" ]; then
          find "$I" -type f -exec chmod 660 {} +
          setfacl -R -m g:hermes:rwX -d -m g:hermes:rwX "$I"
        fi
      '';
    };

    systemd.timers.garden-vault-acl = {
      description = "Ré-applique périodiquement les ACL de /opt/vault et /var/lib/hermes/incoming";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "15min";
      };
    };
  };
}
