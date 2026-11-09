{ config, lib, pkgs, ... }:

let
  s = config.sops.secrets;
  mediaGroup = "media";
  rcloneRemoteName = "storagebox";
  cryptRemoteName = "musiccrypt";
  musicMount = "/mnt/music"; # vue déchiffrée (FUSE), servie à Navidrome/Lidarr/slskd

  ##########################################################
  # Soularr : pont Lidarr <-> slskd (pas de module nixpkgs,
  # ni de paquet pyarr/slskd-api -> on les packages nous-mêmes)
  ##########################################################
  pyarr = pkgs.python3Packages.buildPythonPackage rec {
    pname = "pyarr";
    version = "5.2.0";
    pyproject = true;
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/d7/dc/3df29efc72a53cad21de33e84144822ddfdbdd68127df6c577a187313de9/pyarr-5.2.0.tar.gz";
      sha256 = "8e571cf4a8f53184ac9ef2642995d75962550f1dca22ea238db1ad97c903529c";
    };
    build-system = [ pkgs.python3Packages.poetry-core ];
    postPatch = ''
      sed -i 's/poetry\.masonry\.api/poetry.core.masonry.api/' pyproject.toml
      sed -i 's/^poetry\s*=.*/poetry-core/' pyproject.toml
    '';
    dependencies = with pkgs.python3Packages; [ requests overrides types-requests ];
    doCheck = false;
  };

  slskdApi = pkgs.python3Packages.buildPythonPackage rec {
    pname = "slskd-api";
    version = "0.1.5";
    pyproject = true;
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/74/eb/b1e43d099cca89d313352b3ac0ae1100494c5f7b4a727dde82b89b2a0ca9/slskd-api-0.1.5.tar.gz";
      sha256 = "2e658fedb9cae48562776e79a92d8d18e9b22b31a9525df1b0ee6f8b9b8923cf";
    };
    build-system = with pkgs.python3Packages; [ setuptools setuptools-git-versioning ];
    dependencies = [ pkgs.python3Packages.requests ];
    doCheck = false;
    pythonImportsCheck = [ "slskd_api" ];
  };

  soularrPython = pkgs.python3.withPackages (ps: [
    ps.requests
    ps.music-tag
    ps.flask
    ps.waitress
    pyarr
    slskdApi
  ]);

  soularrSrc = pkgs.fetchFromGitHub {
    owner = "mrusse";
    repo = "soularr";
    rev = "33116daedb54f692e9209cb580b952f07a10cd4c";
    hash = "sha256-2ipDV1oOlO06ZSjhhzyMRVdoGtdDtSo8ND3ijJqJTKg=";
  };

  soularrPackage = pkgs.writeShellApplication {
    name = "soularr";
    runtimeInputs = [ soularrPython ];
    text = ''
      exec python3 ${soularrSrc}/soularr.py "$@"
    '';
  };
in
{
  sops.defaultSopsFile = lib.mkDefault ../../secrets/garden.yaml;
  sops.age.sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets = {
    "media/storagebox_ssh_key" = { owner = "root"; mode = "0400"; };
    "media/rclone_crypt_password" = { owner = "root"; mode = "0400"; };
    "media/rclone_crypt_salt" = { owner = "root"; mode = "0400"; };
    "media/slskd_env" = { owner = "root"; mode = "0400"; };
  };

  users.groups.${mediaGroup} = { gid = 20000; };

  ############################################################
  # Montage chiffré de la Hetzner Storage Box (rclone crypt sur SFTP)
  # Chiffrement bout-en-bout : Hetzner ne voit que du contenu chiffré.
  # Cache VFS local borné pour ne pas remplir le disque du serveur.
  ############################################################
  systemd.services.rclone-music-mount = {
    description = "Montage chiffré (rclone crypt) de la Storage Box Hetzner";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.HOME = "/root";
    path = [ pkgs.rclone pkgs.fuse3 pkgs.gawk ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = pkgs.writeShellScript "rclone-music-conf" ''
        set -eu
        umask 077
        install -d -m 0700 /run/rclone
        CRYPT_PW=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_password".path})")
        CRYPT_SALT=$(${pkgs.rclone}/bin/rclone obscure "$(cat ${s."media/rclone_crypt_salt".path})")
        cat > /run/rclone/rclone.conf <<CONF
        [${rcloneRemoteName}]
        type = sftp
        host = u709640.your-storagebox.de
        user = u709640
        port = 23
        key_file = ${s."media/storagebox_ssh_key".path}
        shell_type = unix
        md5sum_command = none
        sha1sum_command = none

        [${cryptRemoteName}]
        type = crypt
        remote = ${rcloneRemoteName}:music
        password = $CRYPT_PW
        password2 = $CRYPT_SALT
        filename_encryption = standard
        directory_name_encryption = true
        CONF
        install -d -m 0770 -o root -g ${mediaGroup} ${musicMount}
      '';
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount ${cryptRemoteName}: ${musicMount} \
          --config /run/rclone/rclone.conf \
          --allow-other \
          --uid 0 --gid ${toString config.users.groups.${mediaGroup}.gid} \
          --dir-perms 0770 --file-perms 0660 \
          --vfs-cache-mode writes \
          --vfs-cache-max-size 4G \
          --vfs-cache-max-age 48h \
          --buffer-size 32M \
          --sftp-concurrency 16 \
          --transfers 4 \
          --log-level INFO
      '';
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u ${musicMount}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # FUSE "allow_other" nécessite ce réglage noyau
  environment.etc."fuse.conf".text = lib.mkDefault "user_allow_other\n";
  systemd.tmpfiles.rules = [
    "d ${musicMount} 0770 root ${mediaGroup} -"
    "d /var/lib/slskd/incomplete 0750 slskd slskd -"
    "d /var/lib/slskd/downloads 0770 slskd slskd -"
  ];

  ############################################################
  # Navidrome — accessible via music.lena.sh (Traefik, filtré par IP
  # NetBird) ou directement en 100.79.103.184:4533.
  ############################################################
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ 4533 ];

  services.navidrome = {
    enable = true;
    settings = {
      Address = "0.0.0.0";
      Port = 4533;
      MusicFolder = musicMount;
      ScanInterval = "30m";
      EnableInsightsCollector = false;
      LogLevel = "info";
      TranscodingCacheSize = "2GB";
      LastFM.Enabled = true;
      LastFM.ApiKey = "9a26827f02d92eb6a6ae8a3241193b8a";
      LastFM.Secret = "22abf953b10fdfc0acd8e627b3446d8b";
      # Maloja (scrobbler auto-hébergé) via l'API compatible ListenBrainz qu'il expose.
      # Chaque utilisateur active "Scrobble to ListenBrainz" dans ses réglages perso et
      # colle la clé API Maloja (admin -> API Keys) à la place d'un vrai token LB.
      ListenBrainz.Enabled = true;
      ListenBrainz.BaseURL = "http://100.79.103.184:42010/apis/listenbrainz/1/";
      # Discord Rich Presence (plugin .ndp téléchargé manuellement, cf.
      # systemd.services.navidrome.environment pour ND_PLUGINS_FOLDER) :
      Plugins.Enabled = true;
    };
  };
  systemd.services.navidrome = {
    after = [ "rclone-music-mount.service" ];
    requires = [ "rclone-music-mount.service" ];
    # Folder est en lecture seule dans le module nix (pointe sur le store) ->
    # override par variable d'env (ND_PLUGINS_FOLDER), lue par Navidrome
    # avec une priorité supérieure au fichier de config.
    environment.ND_PLUGINS_FOLDER = "/var/lib/navidrome/plugins";
  };
  users.users.navidrome.extraGroups = [ mediaGroup ];

  ############################################################
  # Lidarr — admin uniquement via NetBird (pas de domaine public)
  ############################################################
  services.lidarr = {
    enable = true;
    settings.server.port = 8686;
  };
  systemd.services.lidarr = {
    after = [ "rclone-music-mount.service" ];
    requires = [ "rclone-music-mount.service" ];
  };
  users.users.lidarr.extraGroups = [ mediaGroup ];

  ############################################################
  # slskd (client Soulseek) — admin uniquement via NetBird
  ############################################################
  services.slskd = {
    enable = false; # désactivé : upload manuel via Syncthing, Soularr ne l'utilise plus
    domain = null;
    environmentFile = s."media/slskd_env".path;
    openFirewall = true; # port Soulseek P2P (50300), nécessaire au réseau
    settings = {
      web.port = 5030;
      directories = {
        incomplete = "/var/lib/slskd/incomplete";
        downloads = "/var/lib/slskd/downloads";
      };
      shares.directories = [ ];
      shares.filters = [ "\\.ini$" "Thumbs\\.db$" "\\.DS_Store$" ];
      rooms = [ ];
      flags.force_share_scan = false;
      soulseek.listen_port = 50300;
      global.upload.slots = 2;
      global.download.slots = 4;
      retention.files.incomplete = 10080;
      retention.transfers.upload = { succeeded = 10080; errored = 10080; cancelled = 1440; };
      retention.transfers.download = { succeeded = 10080; errored = 10080; cancelled = 1440; };
    };
  };
  users.users.slskd = lib.mkIf config.services.slskd.enable {
    extraGroups = [ mediaGroup ];
    # $HOME par défaut (/var/empty) est en lecture seule ; slskd (.NET) y écrit
    # un verrou de mutex applicatif au démarrage -> besoin d'un HOME inscriptible.
    home = lib.mkForce "/var/lib/slskd";
  };

  ############################################################
  # Soularr — relie les albums "wanted" de Lidarr à slskd, toutes les 15 min.
  # Les fichiers finis sont déplacés par Lidarr lui-même (import) dans
  # ${musicMount}, donc directement sur la Storage Box chiffrée.
  ############################################################
  systemd.services.soularr = {
    description = "Soularr — pont Lidarr <-> slskd";
    after = [ "lidarr.service" "slskd.service" ];
    requires = [ "lidarr.service" "slskd.service" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      SupplementaryGroups = [ "slskd" ];
      StateDirectory = "soularr";
      RuntimeDirectory = "soularr";
      WorkingDirectory = "/var/lib/soularr";
      # Ecrit la config avec les clés API (lues en root), lisible ensuite par
      # l'utilisateur dynamique via le groupe "slskd".
      ExecStartPre = "+" + (pkgs.writeShellScript "soularr-conf" ''
        set -eu
        umask 077
        LIDARR_KEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<ApiKey>)[^<]+' /var/lib/lidarr/.config/Lidarr/config.xml)
        SLSKD_KEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=^SLSKD_API_KEY=).+' ${s."media/slskd_env".path})
        cat > /run/soularr/config.ini <<CONF
        [Lidarr]
        api_key = $LIDARR_KEY
        host_url = http://127.0.0.1:8686
        download_dir = /var/lib/slskd/downloads
        disable_sync = False

        [Slskd]
        api_key = $SLSKD_KEY
        host_url = http://127.0.0.1:5030
        url_base = /
        download_dir = /var/lib/slskd/downloads
        delete_searches = False
        stalled_timeout = 3600
        remote_queue_timeout = 300

        [Release Settings]
        use_most_common_tracknum = True
        allow_multi_disc = True
        accepted_countries = Europe, Japan, United Kingdom, United States, [Worldwide], Australia, Canada
        skip_region_check = False
        accepted_formats = CD, Digital Media, Vinyl

        [Search Settings]
        search_timeout = 5000
        maximum_peer_queue = 50
        minimum_peer_upload_speed = 0
        minimum_filename_match_ratio = 0.8
        minimum_search_interval = 5
        search_retry_wait_hours = 24
        allowed_filetypes = flac 24/192, flac 16/44.1, flac
        album_prepend_artist = False
        search_type = incrementing_page
        number_of_albums_to_grab = 10
        search_source = missing
        failed_import_denylist = True
        ignore_failed_users = False
        failed_user_ignore_hours = 168

        [Download Settings]
        download_filtering = True
        use_extension_whitelist = False
        rename_download_folders = True

        [Logging]
        level = INFO
        log_to_file = True
        log_file = /var/lib/soularr/soularr.log
        max_bytes = 1048576
        backup_count = 3
        CONF
        chgrp slskd /run/soularr/config.ini
        chmod 0640 /run/soularr/config.ini
      '');
      ExecStart = "${soularrPackage}/bin/soularr --config-dir /run/soularr --var-dir /var/lib/soularr --no-lock-file";
    };
  };

  systemd.timers.soularr = {
    enable = false; # désactivé : upload manuel via Syncthing, évite les doublons slskd
    description = "Lance Soularr toutes les 15 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
  };

  ############################################################
  # Rescan périodique forcé : le watcher temps réel de Navidrome ne voit
  # pas les fichiers écrits via le montage SFTP du Mac (même backend Hetzner,
  # chemin d'accès différent de celui que Navidrome surveille).
  ############################################################
  systemd.services.navidrome-rescan = {
    description = "Rescan forcé de la bibliothèque Navidrome";
    after = [ "navidrome.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "navidrome";
      Group = "navidrome";
      WorkingDirectory = "/var/lib/navidrome";
      ExecStart = "${config.services.navidrome.finalPackage}/bin/navidrome --configfile ${(pkgs.formats.json { }).generate "navidrome-scan.json" config.services.navidrome.settings} scan";
    };
  };

  systemd.timers.navidrome-rescan = {
    description = "Lance le rescan Navidrome toutes les 10 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "10min";
      Persistent = true;
    };
  };
}
