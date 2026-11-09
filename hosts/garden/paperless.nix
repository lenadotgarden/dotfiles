{ config, lib, pkgs, ... }:

let
  s = config.sops.secrets;
  mountPoint = "/mnt/paperless";
in
{
  ############################################################
  # Paperless-ngx — gestion de documents (NixOS natif, module
  # nixpkgs services.paperless). Base de données Postgres locale
  # (petite, doit rester sur disque local — un FUSE distant ne
  # tient pas les locks Postgres, même raison que state.db de
  # Hermes, cf hosts/garden/hermes.nix). Les documents eux-mêmes
  # (mediaDir : originaux, archives PDF/A, miniatures — le gros du
  # volume) sont stockés sur la Storage Box Hetzner, même compte
  # et même clé de chiffrement que media.nix/cloud.nix/hermes.nix,
  # dans un dossier dédié "paperless".
  #
  # consumptionDir (dossier d'import surveillé par inotify) reste
  # local : un montage FUSE rclone ne propage pas fiablement les
  # évènements inotify, ce qui casserait l'auto-import. Les
  # fichiers y sont de toute façon transitoires (déplacés dans
  # mediaDir une fois traités).
  ############################################################

  systemd.services."rclone-paperless-mount" = {
    description = "Montage chiffré (rclone crypt) de la Storage Box Hetzner — paperless";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.HOME = "/root";
    path = [ pkgs.rclone pkgs.fuse3 pkgs.gawk pkgs.util-linux pkgs.findutils ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = pkgs.writeShellScript "rclone-paperless-conf" ''
        set -eu
        umask 077
        install -d -m 0700 /run/rclone-paperless
        CRYPT_PW=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_password".path})")
        CRYPT_SALT=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_salt".path})")
        cat > /run/rclone-paperless/rclone.conf <<CONF
        [storagebox]
        type = sftp
        host = u709640.your-storagebox.de
        user = u709640
        port = 23
        key_file = ${s."media/storagebox_ssh_key".path}
        shell_type = unix
        md5sum_command = none
        sha1sum_command = none

        [paperlesscrypt]
        type = crypt
        remote = storagebox:paperless
        password = $CRYPT_PW
        password2 = $CRYPT_SALT
        filename_encryption = standard
        directory_name_encryption = true
        CONF
        install -d -m 0770 -o paperless -g paperless ${mountPoint}
        if ! mountpoint -q ${mountPoint}; then
          find ${mountPoint} -mindepth 1 -delete
        fi
      '';
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount paperlesscrypt: ${mountPoint} \
          --config /run/rclone-paperless/rclone.conf \
          --allow-other \
          --uid ${toString config.ids.uids.paperless} --gid ${toString config.ids.gids.paperless} \
          --dir-perms 0770 --file-perms 0660 \
          --vfs-cache-mode writes \
          --vfs-cache-max-size 1G \
          --vfs-cache-max-age 12h \
          --buffer-size 32M \
          --sftp-concurrency 16 \
          --transfers 4 \
          --log-level INFO
      '';
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u ${mountPoint}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  services.paperless = {
    enable = true;

    # Base de données Postgres locale sur disque (petite, rapide,
    # pas sur le montage distant).
    database.createLocally = true;

    # Documents (le gros volume) sur la Storage Box.
    mediaDir = "${mountPoint}/media";

    # Import surveillé + état applicatif (clé secrète, classifieur,
    # superuser-state) restent locaux — cf note en tête de fichier.
    # (dataDir/consumptionDir gardent leurs valeurs par défaut :
    # /var/lib/paperless et /var/lib/paperless/consume)

    address = "0.0.0.0";
    port = 28981; # accessible uniquement via NetBird (wt0, trustedInterfaces), pas exposé publiquement — même posture que hermes-agent.

    settings = {
      PAPERLESS_OCR_LANGUAGE = "fra+eng";
      PAPERLESS_TIME_ZONE = "Europe/Paris";
    };
  };

  # Les services paperless-* doivent attendre que le montage
  # Storage Box soit effectif avant de démarrer (RequiresMountsFor
  # seul ne suffit pas : ce n'est pas une unité .mount déclarée).
  systemd.services.paperless-scheduler.after = [ "rclone-paperless-mount.service" ];
  systemd.services.paperless-scheduler.wants = [ "rclone-paperless-mount.service" ];
  systemd.services.paperless-web.after = [ "rclone-paperless-mount.service" ];
  systemd.services.paperless-web.wants = [ "rclone-paperless-mount.service" ];
  systemd.services.paperless-consumer.after = [ "rclone-paperless-mount.service" ];
  systemd.services.paperless-consumer.wants = [ "rclone-paperless-mount.service" ];
  systemd.services.paperless-task-queue.after = [ "rclone-paperless-mount.service" ];
  systemd.services.paperless-task-queue.wants = [ "rclone-paperless-mount.service" ];
}
