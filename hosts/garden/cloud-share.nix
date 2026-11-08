{ config, lib, pkgs, ... }:

let
  s = config.sops.secrets;

  webdavShareService = {
    description = "WebDAV chiffré (rclone serve, Hetzner Storage Box) — files.lena.sh";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.HOME = "/root";
    path = [ pkgs.rclone pkgs.openssl pkgs.coreutils ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = pkgs.writeShellScript "webdav-share-conf" ''
        set -eu
        umask 077
        install -d -m 0700 /run/webdav-share
        CRYPT_PW=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_password".path})")
        CRYPT_SALT=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_salt".path})")
        cat > /run/webdav-share/rclone.conf <<CONF
        [storagebox]
        type = sftp
        host = u709640.your-storagebox.de
        user = u709640
        port = 23
        key_file = ${s."media/storagebox_ssh_key".path}
        shell_type = unix
        md5sum_command = none
        sha1sum_command = none

        [webdavcrypt]
        type = crypt
        remote = storagebox:webdav
        password = $CRYPT_PW
        password2 = $CRYPT_SALT
        filename_encryption = standard
        directory_name_encryption = true
        CONF
        {
          printf 'lena:%s\n' "$(${pkgs.openssl}/bin/openssl passwd -apr1 "$(cat ${s."webdav/lena_pass".path})")"
          printf 'hermes:%s\n' "$(${pkgs.openssl}/bin/openssl passwd -apr1 "$(cat ${s."webdav/hermes_pass".path})")"
        } > /run/webdav-share/htpasswd
        chmod 600 /run/webdav-share/htpasswd /run/webdav-share/rclone.conf
      '';
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone serve webdav webdavcrypt: \
          --config /run/webdav-share/rclone.conf \
          --addr 172.30.0.1:8060 \
          --htpasswd /run/webdav-share/htpasswd \
          --vfs-cache-mode writes \
          --vfs-cache-max-size 4G \
          --vfs-cache-max-age 48h \
          --buffer-size 32M \
          --sftp-concurrency 16 \
          --transfers 4 \
          --log-level INFO
      '';
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
in
{
  ############################################################
  # WebDAV chiffré (files.lena.sh) — accès fichiers simple pour Léna
  # (OnlyOffice mobile inclus) + Hermes. Chiffré bout-en-bout (rclone
  # crypt), stockage réel = Hetzner Storage Box. Inchangé par le pivot
  # ci-dessous (outil sans état/DB propre, pas concerné par le problème
  # de verrous fichiers FUSE).
  ############################################################
  sops.secrets."webdav/lena_pass" = { owner = "root"; mode = "0400"; };
  sops.secrets."webdav/hermes_pass" = {
    owner = "root";
    mode = "0400";
    sopsFile = ../../secrets/hermes-managed.yaml;
  };

  systemd.services.webdav-share = webdavShareService;

  ############################################################
  # oCIS / cloud.lena.sh : stockage réel — EN LOCAL, pas sur la Storage Box.
  #
  # FileBrowser (le projet ET son fork "Quantum") a été abandonné — Léna
  # a trouvé que le projet original est en cours d'archivage (2026-09-01,
  # failles de sécurité connues non corrigées). Remplacé par ownCloud
  # Infinite Scale (oCIS, voir hosts/garden/compose.nix + /srv/garden/ocis),
  # maintenu activement, WebDAV natif (pas expérimental), liens de partage
  # OCS intégrés.
  #
  # Deux tentatives de stockage distant ont échoué, pour deux raisons
  # DIFFÉRENTES — ce n'est pas un problème de config mais une vraie limite
  # structurelle d'oCIS (comme Nextcloud et probablement Seafile) :
  #  1. rclone crypt + FUSE (chiffré) : son NATS/JetStream interne a besoin
  #     de vrais verrous fichiers POSIX, que FUSE+VFS-cache ne fournit pas
  #     correctement (même classe de problème que SQLite sur FUSE, cf.
  #     hermes.nix). Échec confirmé ("nats: no servers available").
  #  2. CIFS/Samba natif de la Storage Box (non chiffré, testé ensuite) :
  #     fonctionne pour les verrous, MAIS oCIS a aussi besoin de vrais
  #     symlinks pour organiser son stockage interne (content-addressed),
  #     que CIFS ne supporte pas ("symlink ... operation not supported").
  # Décision finale avec Léna (2026-11-08) : stockage en LOCAL sur le
  # disque de la VM (/var/lib/ocis-data, /var/lib/ocis-config), sans
  # chiffrement, sans volume Hetzner — elle préfère ça à un nouveau volume
  # OCI séparé. Le vrai disque local (45 Go, marge serrée, cf.
  # garden_disk_no_resize) devient la limite de taille réelle.
  ############################################################

  # Traefik (br-proxy, passerelle 172.30.0.1) doit atteindre ce service côté hôte.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ 8060 ];
}
