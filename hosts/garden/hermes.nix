{ config, lib, pkgs, ... }:

let
  s = config.sops.secrets;
  hermesUid = config.users.users.hermes.uid;
  hermesGid = config.users.groups.hermes.gid;
  mountPoint = "/mnt/hermes";
in
{
  ############################################################
  # Hermes — réglages propres à l'hôte garden. Les modules `hermes-*`
  # eux-mêmes (dendritic, cf modules/hermes/) sont importés depuis
  # flake.nix (nixosConfigurations.garden.modules), pas ici.
  #
  # hermes-agent-legacy (bot Telegram maison) est retiré : le vrai
  # hermes-agent (NousResearch, cf hermes-real-agent.nix) gère Telegram
  # maintenant (TELEGRAM_ALLOWED_USERS dans son env).
  ############################################################

  ############################################################
  # Stockage Hetzner pour Hermes.
  #
  # Un dossier dédié de la Storage Box (`hermes`), chiffré
  # bout-en-bout avec rclone crypt (même clé SSH et même mot de
  # passe que media.nix / cloud.nix), monté sur ${mountPoint} et
  # appartenant à l'utilisateur hermes.
  #
  # Destination par défaut des téléchargements et des gros
  # fichiers produits par l'agent. Le reste (state.db, skills,
  # tools, scratch) RESTE LOCAL : SQLite, binaires et worktrees
  # git ne survivent pas à un montage FUSE distant.
  #
  # Contrairement aux montages de cloud.nix (lecture des médias),
  # celui-ci est en écriture : --vfs-cache-mode writes bufferise
  # le fichier en local puis l'envoie à la fermeture, plafonné à
  # 3 Go pour ne pas remplir /.
  ############################################################

  systemd.services."rclone-hermes-mount" = {
    description = "Montage chiffré (rclone crypt) de la Storage Box Hetzner — hermes";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.HOME = "/root";
    path = [ pkgs.rclone pkgs.fuse3 pkgs.gawk pkgs.util-linux pkgs.findutils ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = pkgs.writeShellScript "rclone-hermes-conf" ''
        set -eu
        umask 077
        install -d -m 0700 /run/rclone-hermes
        CRYPT_PW=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_password".path})")
        CRYPT_SALT=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_salt".path})")
        cat > /run/rclone-hermes/rclone.conf <<CONF
        [storagebox]
        type = sftp
        host = u709640.your-storagebox.de
        user = u709640
        port = 23
        key_file = ${s."media/storagebox_ssh_key".path}
        shell_type = unix
        md5sum_command = none
        sha1sum_command = none

        [hermescrypt]
        type = crypt
        remote = storagebox:hermes
        password = $CRYPT_PW
        password2 = $CRYPT_SALT
        filename_encryption = standard
        directory_name_encryption = true
        CONF
        install -d -m 0770 -o hermes -g hermes ${mountPoint}
        # Si le montage FUSE n'est pas encore effectif, tout ce qui
        # traîne dans le dossier local est un résidu : on nettoie,
        # sinon rclone refuse de monter sur un dossier non vide.
        if ! mountpoint -q ${mountPoint}; then
          find ${mountPoint} -mindepth 1 -delete
        fi
      '';
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount hermescrypt: ${mountPoint} \
          --config /run/rclone-hermes/rclone.conf \
          --allow-other \
          --uid ${toString hermesUid} --gid ${toString hermesGid} \
          --dir-perms 0770 --file-perms 0660 \
          --vfs-cache-mode writes \
          --vfs-cache-max-size 3G \
          --vfs-cache-max-age 24h \
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

  # hermes-agent démarre après le montage (Wants, pas Requires :
  # si la Storage Box est injoignable, l'agent doit quand même
  # tourner, seul ${mountPoint} sera vide).
  systemd.services.hermes-agent = {
    after = [ "rclone-hermes-mount.service" ];
    wants = [ "rclone-hermes-mount.service" ];
  };
}
# test autonomie Sat Nov  7 02:13:03 PM UTC 2026
