{ config, lib, pkgs, ... }:

let
  s = config.sops.secrets;
  fbDataMount = "/mnt/filebrowser-data";

  ##########################################################
  # Même pattern que mkRcloneCryptMount dans cloud.nix : un dossier de
  # la Storage Box Hetzner, chiffré bout-en-bout avec rclone crypt, monté
  # en FUSE localement. Dupliqué ici plutôt que partagé depuis cloud.nix
  # (le helper y est local à son `let`) — même secrets media/* réutilisés.
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

  fbBootstrap = pkgs.writeShellScript "filebrowser-bootstrap" ''
    set -eu
    DB=/var/lib/filebrowser/database.db
    BOOTSTRAP_CFG=/var/lib/filebrowser/bootstrap-config.json
    if [ ! -f "$DB" ]; then
      printf '{"database": "%s"}' "$DB" > "$BOOTSTRAP_CFG"
      ${lib.getExe pkgs.filebrowser} --config "$BOOTSTRAP_CFG" config init
      ${lib.getExe pkgs.filebrowser} --config "$BOOTSTRAP_CFG" users add admin "$(cat ${s."filebrowser/admin_pass".path})" --perm.admin
      rm -f "$BOOTSTRAP_CFG"
    fi
  '';
in
{
  ############################################################
  # WebDAV chiffré (files.lena.sh) — remplace Nextcloud pour l'usage
  # "accès fichiers simple" : Léna (OnlyOffice mobile inclus) + Hermes,
  # lecture/écriture directe, sans la couche groupware/DB de Nextcloud.
  # Chiffré bout-en-bout (rclone crypt), stockage réel = Hetzner Storage
  # Box, même clé/sel que les autres montages (secrets media/*).
  #
  # Statut (2026-11-08) : gardé en parallèle de FileBrowser Quantum
  # ci-dessous tant qu'OnlyOffice iOS + macOS n'ont pas été testés sur le
  # WebDAV (expérimental) de FileBrowser Quantum — voir sa section pour le
  # détail. À retirer seulement après ce test réussi.
  ############################################################
  sops.secrets."webdav/lena_pass" = { owner = "root"; mode = "0400"; };
  sops.secrets."webdav/hermes_pass" = {
    owner = "root";
    mode = "0400";
    sopsFile = ../../secrets/hermes-managed.yaml;
  };

  ############################################################
  # FileBrowser (cloud.lena.sh) — remplace Nextcloud pour l'usage "envoyer
  # un lien de téléchargement à un client".
  #
  # Pivot (2026-11-08) : le fork "FileBrowser Quantum" (binaire externe,
  # tenté d'abord) a un bootstrap d'admin par config.yaml qui ne marche
  # pas comme documenté (log "Resetting admin user to default username
  # and password" à chaque démarrage, mais même admin/admin par défaut
  # rejeté — état d'auth incohérent en pratique), en plus de son WebDAV
  # déjà marqué "nouveau et expérimental" par le projet. Retour sur le
  # projet original **filebrowser/filebrowser** : vrai module NixOS
  # (`services.filebrowser`, mature, dans nixpkgs — pas de binaire externe
  # à faire confiance), bootstrap classique `config init` + `users add`.
  # Son système de liens de partage (avec expiration) est natif et mature
  # depuis des années — couvre le besoin de Léna sans les soucis ci-dessus.
  ############################################################
  sops.secrets."filebrowser/admin_pass" = { owner = "filebrowser"; mode = "0400"; };

  # gid stable requis par mkRcloneCryptMount (--gid dans la commande rclone
  # mount a besoin de la valeur à l'évaluation, pas d'une auto-assignation
  # décidée seulement à l'activation) — déjà ce qui a été auto-assigné ici
  # lors d'un essai précédent, donc pas de changement destructif.
  users.groups.filebrowser.gid = 980;

  services.filebrowser = {
    enable = true;
    settings = {
      address = "172.30.0.1";
      port = 8070;
      root = fbDataMount;
    };
  };

  systemd.services = (mkRcloneCryptMount {
    name = "filebrowser";
    remoteDir = "filebrowser";
    mountPoint = fbDataMount;
    group = "filebrowser";
  }) // {
    webdav-share = webdavShareService;
    filebrowser = {
      after = [ "rclone-filebrowser-mount.service" ];
      requires = [ "rclone-filebrowser-mount.service" ];
      serviceConfig.ExecStartPre = [ fbBootstrap ];
    };
  };

  # Traefik (br-proxy, passerelle 172.30.0.1) doit atteindre ces deux services côté hôte.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ 8060 8070 ];
}
