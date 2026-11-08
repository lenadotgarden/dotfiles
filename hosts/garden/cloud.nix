{ config, lib, pkgs, ... }:

let
  s = config.sops.secrets;
  mediaGroup = "media"; # groupe déjà créé par media.nix (gid 20000)

  ##########################################################
  # Montage chiffré générique (même pattern que rclone-music-mount
  # dans media.nix) : un dossier de la Storage Box Hetzner, chiffré
  # bout-en-bout avec rclone crypt, monté en FUSE localement.
  # Réutilise les secrets media/* (même clé SSH, même mot de passe
  # de chiffrement) : seul le sous-dossier distant change.
  ##########################################################
  mkRcloneCryptMount = { name, remoteDir, mountPoint, group, dirMode ? "0770" }: {
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
          install -d -m ${dirMode} -o root -g ${group} ${mountPoint}
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
            --uid 0 --gid ${toString config.users.groups.${group}.gid} \
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

  audiobooksMount = "/mnt/audiobooks";
  booksMount = "/mnt/books";
in
{
  # Nextcloud a été retiré (2026-11-08) : remplacé par FileBrowser
  # (cloud.lena.sh, liens de partage client) et un WebDAV chiffré séparé
  # (files.lena.sh) — voir hosts/garden/cloud-share.nix. Les 2 xlsx réels
  # et le dossier Trash ont été migrés vers le nouveau stockage avant ce
  # retrait. audiobookshelf/calibre-web, indépendants, restent inchangés.
  systemd.services =
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

  # Traefik (br-proxy, passerelle 172.30.0.1) doit atteindre ces deux services côté hôte.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ 8030 8040 ];
}
