{ config, lib, pkgs, ... }:

let
  s = config.sops.secrets;
  mediaGroup = "media"; # groupe déjà créé par media.nix (gid 20000)
  domain = "lena.sh";

  ##########################################################
  # Montage chiffré générique (même pattern que rclone-music-mount
  # dans media.nix) : un dossier de la Storage Box Hetzner, chiffré
  # bout-en-bout avec rclone crypt, monté en FUSE localement.
  # Réutilise les secrets media/* (même clé SSH, même mot de passe
  # de chiffrement) : seul le sous-dossier distant change.
  ##########################################################
  mkRcloneCryptMount = { name, remoteDir, mountPoint, group, uid ? 0, dirMode ? "0770" }: {
    "rclone-${name}-mount" = {
      description = "Montage chiffré (rclone crypt) de la Storage Box Hetzner — ${name}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      environment.HOME = "/root";
      path = [ pkgs.rclone pkgs.fuse3 pkgs.gawk pkgs.util-linux pkgs.findutils ];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = pkgs.writeShellScript "rclone-${name}-conf" ''
          set -eu
          umask 077
          install -d -m 0700 /run/rclone-${name}
          CRYPT_PW=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_password".path})")
          CRYPT_SALT=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_salt".path})")
          cat > /run/rclone-${name}/rclone.conf <<CONF
          [storagebox]
          type = sftp
          host = u709640.your-storagebox.de
          user = u709640
          port = 23
          key_file = ${s."media/storagebox_ssh_key".path}
          shell_type = unix
          md5sum_command = none
          sha1sum_command = none

          [${name}crypt]
          type = crypt
          remote = storagebox:${remoteDir}
          password = $CRYPT_PW
          password2 = $CRYPT_SALT
          filename_encryption = standard
          directory_name_encryption = true
          CONF
          install -d -m ${dirMode} -o ${toString uid} -g ${group} ${mountPoint}
          # Sécurité : si un service dépendant a démarré avant que le montage FUSE
          # précédent ne soit effectif (course au boot), il a pu écrire directement
          # dans le dossier local sous-jacent. rclone refuse de monter sur un dossier
          # non-vide -> on nettoie, mais seulement si rien n'est actuellement monté
          # (sinon on toucherait aux vraies données servies par le montage en cours).
          if ! mountpoint -q ${mountPoint}; then
            find ${mountPoint} -mindepth 1 -delete
          fi
        '';
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount ${name}crypt: ${mountPoint} \
            --config /run/rclone-${name}/rclone.conf \
            --allow-other \
            --uid ${toString uid} --gid ${toString config.users.groups.${group}.gid} \
            --dir-perms ${dirMode} --file-perms 0660 \
            --vfs-cache-mode writes \
            --vfs-cache-max-size 4G \
            --vfs-cache-max-age 48h \
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
  };

  # UID fixe (pas celui alloué dynamiquement par le module) : il faut le connaître
  # à l'évaluation Nix pour l'utiliser comme --uid du montage rclone.
  nextcloudUid = 10001;
  nextcloudDataMount = "/mnt/nextcloud-data";
  audiobooksMount = "/mnt/audiobooks";
  booksMount = "/mnt/books";
in
{
  systemd.services =
    (mkRcloneCryptMount {
      name = "nextcloud";
      remoteDir = "nextcloud";
      mountPoint = nextcloudDataMount;
      group = mediaGroup;
      uid = nextcloudUid;
    }) //
    (mkRcloneCryptMount {
      name = "audiobooks";
      remoteDir = "audiobooks";
      mountPoint = audiobooksMount;
      group = mediaGroup;
    }) //
    (mkRcloneCryptMount {
      name = "books";
      remoteDir = "books";
      mountPoint = booksMount;
      group = mediaGroup;
    }) //
    {
      "nextcloud-setup" = {
        after = [ "postgresql.service" "rclone-nextcloud-mount.service" ];
        requires = [ "postgresql.service" "rclone-nextcloud-mount.service" ];
        # rclone-nextcloud-mount.service est "active" dès que le process est lancé,
        # pas forcément une fois le montage FUSE effectif -> on attend explicitement,
        # sinon nextcloud-setup peut écrire dans le dossier local sous-jacent au lieu
        # du montage (course observée au premier déploiement).
        serviceConfig.ExecStartPre = [
          (pkgs.writeShellScript "wait-nextcloud-mount" ''
            set -eu
            for i in $(seq 1 30); do
              ${pkgs.util-linux}/bin/mountpoint -q ${nextcloudDataMount} && exit 0
              sleep 1
            done
            echo "timeout en attendant le montage ${nextcloudDataMount}" >&2
            exit 1
          '')
        ];
      };
      "phpfpm-nextcloud" = {
        after = [ "rclone-nextcloud-mount.service" ];
        requires = [ "rclone-nextcloud-mount.service" ];
      };
      audiobookshelf = {
        after = [ "rclone-audiobooks-mount.service" ];
        requires = [ "rclone-audiobooks-mount.service" ];
      };
      "calibre-web" = {
        after = [ "rclone-books-mount.service" ];
        requires = [ "rclone-books-mount.service" ];
      };
    };

  ############################################################
  # Nextcloud (cloud.lena.sh) — WebDAV natif sur /remote.php/dav/,
  # données sur la Storage Box (montage chiffré ci-dessus). DB
  # Postgres existante (auth peer via socket unix, comme Synapse).
  ############################################################
  sops.secrets."nextcloud/admin_pass" = { owner = "nextcloud"; mode = "0400"; };

  services.postgresql = {
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
      { name = "nextcloud"; ensureDBOwnership = true; }
    ];
  };

  services.nextcloud = {
    enable = true;
    hostName = "cloud.${domain}";
    datadir = nextcloudDataMount;
    database.createLocally = false;
    config = {
      dbtype = "pgsql";
      dbhost = "/run/postgresql";
      dbuser = "nextcloud";
      dbname = "nextcloud";
      adminuser = "admin";
      adminpassFile = s."nextcloud/admin_pass".path;
    };
    settings = {
      overwriteprotocol = "https";
      trusted_proxies = [ "172.30.0.1" ];
      enable_previews = true;
    };
  };
  users.users.nextcloud = {
    uid = nextcloudUid;
    extraGroups = [ mediaGroup ];
  };

  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    listen = [{ addr = "172.30.0.1"; port = 8020; }];
  };

  ############################################################
  # Audiobookshelf (audiobooks.lena.sh) — serveur HTTP intégré,
  # pas besoin de nginx. Bibliothèque sur la Storage Box.
  ############################################################
  services.audiobookshelf = {
    enable = true;
    host = "172.30.0.1";
    port = 8030;
  };
  users.users.audiobookshelf.extraGroups = [ mediaGroup ];

  ############################################################
  # Calibre-Web (books.lena.sh) — serveur HTTP intégré. Nécessite
  # une bibliothèque Calibre existante (metadata.db) dans ${booksMount} ;
  # si absente, créer via `calibredb --with-library ${booksMount} list`
  # ou depuis l'UI au premier lancement.
  ############################################################
  services.calibre-web = {
    enable = true;
    listen.ip = "172.30.0.1";
    listen.port = 8040;
    options = {
      calibreLibrary = booksMount;
      enableBookUploading = true;
    };
  };
  users.users."calibre-web".extraGroups = [ mediaGroup ];

  # Traefik (br-proxy, passerelle 172.30.0.1) doit atteindre ces trois services côté hôte.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ 8020 8030 8040 ];
}
