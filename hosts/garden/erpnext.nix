{ config, lib, pkgs, ... }:

let
  port = 8085; # frontend nginx du bench (conteneur :8080)
  hostname = "erp.lena.sh";
  image = "frappe/erpnext:v16.60.0"; # arm64 OK ; épinglé (mise à jour = changer ce tag)
  secretDir = "/var/lib/erpnext-secret";

  # Adapté de frappe_docker/pwd.yml : mots de passe lus dans l'env-file généré
  # (${secretDir}/secret.env), jamais dans le store Nix.
  frappeVolumes = [
    "sites:/home/frappe/frappe-bench/sites"
    "logs:/home/frappe/frappe-bench/logs"
  ];
  redisEnv = {
    FRAPPE_REDIS_CACHE = "redis://redis-cache:6379";
    FRAPPE_REDIS_QUEUE = "redis://redis-queue:6379";
  };
  afterConfigurator = { configurator.condition = "service_completed_successfully"; };

  compose = {
    name = "erpnext";
    services = {
      configurator = {
        inherit image;
        restart = "no";
        entrypoint = [ "bash" "-c" ];
        command = [
          ''
            ls -1 apps > sites/apps.txt;
            bench set-config -g db_host $$DB_HOST;
            bench set-config -gp db_port $$DB_PORT;
            bench set-config -g redis_cache "redis://$$REDIS_CACHE";
            bench set-config -g redis_queue "redis://$$REDIS_QUEUE";
            bench set-config -g redis_socketio "redis://$$REDIS_QUEUE";
            bench set-config -gp socketio_port $$SOCKETIO_PORT;
          ''
        ];
        environment = {
          DB_HOST = "db";
          DB_PORT = "3306";
          REDIS_CACHE = "redis-cache:6379";
          REDIS_QUEUE = "redis-queue:6379";
          SOCKETIO_PORT = "9000";
        };
        volumes = frappeVolumes;
      };

      create-site = {
        inherit image;
        restart = "no";
        entrypoint = [ "bash" "-c" ];
        command = [
          ''
            wait-for-it -t 120 db:3306;
            wait-for-it -t 120 redis-cache:6379;
            wait-for-it -t 120 redis-queue:6379;
            export start=`date +%s`;
            until [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".db_host // empty"` ]] && \
              [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_cache // empty"` ]] && \
              [[ -n `grep -hs ^ sites/common_site_config.json | jq -r ".redis_queue // empty"` ]];
            do
              echo "Waiting for sites/common_site_config.json to be created";
              sleep 5;
              if (( `date +%s`-start > 120 )); then
                echo "could not find sites/common_site_config.json with required keys";
                exit 1
              fi
            done;
            if [ -d "sites/${hostname}" ]; then
              echo "Site ${hostname} already exists, skipping creation";
            else
              bench new-site --mariadb-user-host-login-scope='%' --admin-password="$$ADMIN_PASSWORD" --db-root-username=root --db-root-password="$$DB_ROOT_PASSWORD" --install-app erpnext --set-default ${hostname};
            fi;
          ''
        ];
        environment = {
          ADMIN_PASSWORD = "\${ERPNEXT_ADMIN_PASSWORD}";
          DB_ROOT_PASSWORD = "\${ERPNEXT_DB_ROOT_PASSWORD}";
        };
        volumes = frappeVolumes;
        depends_on.db.condition = "service_healthy";
      };

      db = {
        image = "mariadb:11.8";
        restart = "unless-stopped";
        healthcheck = {
          test = [ "CMD" "healthcheck.sh" "--connect" "--innodb_initialized" ];
          start_period = "5s";
          interval = "5s";
          timeout = "5s";
          retries = 10;
        };
        command = [
          "--character-set-server=utf8mb4"
          "--collation-server=utf8mb4_unicode_ci"
          "--skip-character-set-client-handshake"
          "--innodb-snapshot-isolation=OFF"
        ];
        environment = {
          MARIADB_ROOT_PASSWORD = "\${ERPNEXT_DB_ROOT_PASSWORD}";
        };
        volumes = [ "db-data:/var/lib/mysql" ];
      };

      backend = {
        inherit image;
        restart = "unless-stopped";
        volumes = frappeVolumes;
        depends_on = afterConfigurator;
      };

      websocket = {
        inherit image;
        restart = "unless-stopped";
        command = [ "node" "/home/frappe/frappe-bench/apps/frappe/socketio.js" ];
        environment = redisEnv;
        volumes = frappeVolumes;
        depends_on = afterConfigurator;
      };

      frontend = {
        inherit image;
        restart = "unless-stopped";
        command = [ "nginx-entrypoint.sh" ];
        environment = {
          BACKEND = "backend:8000";
          # Site unique : on force le nom du site quel que soit le Host reçu
          # (Traefik, ou localhost pour le MCP).
          FRAPPE_SITE_NAME_HEADER = hostname;
          SOCKETIO = "websocket:9000";
          UPSTREAM_REAL_IP_ADDRESS = "127.0.0.1";
          UPSTREAM_REAL_IP_HEADER = "X-Forwarded-For";
          UPSTREAM_REAL_IP_RECURSIVE = "off";
          PROXY_READ_TIMEOUT = "120";
          CLIENT_MAX_BODY_SIZE = "50m";
        };
        volumes = frappeVolumes;
        ports = [ "0.0.0.0:${toString port}:8080" ];
        depends_on = [ "backend" "websocket" ];
      };

      queue-long = {
        inherit image;
        restart = "unless-stopped";
        command = [ "bench" "worker" "--queue" "long,default,short" ];
        environment = redisEnv;
        volumes = frappeVolumes;
        depends_on = afterConfigurator;
      };

      queue-short = {
        inherit image;
        restart = "unless-stopped";
        command = [ "bench" "worker" "--queue" "short,default" ];
        environment = redisEnv;
        volumes = frappeVolumes;
        depends_on = afterConfigurator;
      };

      scheduler = {
        inherit image;
        restart = "unless-stopped";
        command = [ "bench" "schedule" ];
        volumes = frappeVolumes;
        depends_on = afterConfigurator;
      };

      redis-queue = {
        image = "redis:6.2-alpine";
        restart = "unless-stopped";
        volumes = [ "redis-queue-data:/data" ];
      };

      redis-cache = {
        image = "redis:6.2-alpine";
        restart = "unless-stopped";
      };
    };
    volumes = {
      db-data = { };
      redis-queue-data = { };
      sites = { };
      logs = { };
    };
  };

  composeFile = pkgs.writeText "erpnext-compose.json" (builtins.toJSON compose);
  docker = config.virtualisation.docker.package;
in
{
  ############################################################
  # ERPNext v16 (image officielle frappe/erpnext, arm64) en docker compose,
  # adapté de frappe_docker/pwd.yml. Volumes Docker locaux (MariaDB ne doit
  # pas aller sur le montage FUSE). Site unique : ${hostname}.
  # Les mots de passe (admin + root MariaDB) sont générés une fois dans
  # ${secretDir}/secret.env (root, 0600) ; le mot de passe Administrator est
  # aussi dans ${secretDir}/admin-password pour la première connexion
  # (utilisateur : Administrator).
  # Accès : NetBird uniquement via Traefik (erp.lena.sh), et en direct sur
  # localhost:${toString port} pour l'agent Hermes (MCP).
  ############################################################

  systemd.services.erpnext-secret = {
    description = "Génère les mots de passe ERPNext";
    before = [ "garden-compose-erpnext.service" ];
    requiredBy = [ "garden-compose-erpnext.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      install -d -m 0700 ${secretDir}
      if [ ! -s ${secretDir}/secret.env ]; then
        umask 077
        admin=$(${pkgs.openssl}/bin/openssl rand -hex 16)
        db=$(${pkgs.openssl}/bin/openssl rand -hex 24)
        printf '%s\n' "$admin" > ${secretDir}/admin-password
        {
          echo "ERPNEXT_ADMIN_PASSWORD=$admin"
          echo "ERPNEXT_DB_ROOT_PASSWORD=$db"
        } > ${secretDir}/secret.env
      fi
      # Copie lisible par l'agent Hermes (génération de la clé API pour le MCP) ;
      # jamais affichée dans le chat.
      install -m 0400 -o hermes -g hermes ${secretDir}/admin-password /var/lib/hermes/incoming/erpnext-admin-password
    '';
  };

  systemd.services.garden-compose-erpnext = {
    description = "docker compose : erpnext";
    after = [ "docker.service" "garden-docker-network.service" "garden-docker-firewall.service" "erpnext-secret.service" ];
    requires = [ "docker.service" "erpnext-secret.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ docker ];
    environment.HOME = "/root";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 7200; # premier démarrage : pull des images (volume Oracle lent) + création du site
      Restart = "on-failure"; # les couches déjà tirées sont conservées par Docker
      RestartSec = 60;
      ExecStart = "${docker}/bin/docker compose -f ${composeFile} --env-file ${secretDir}/secret.env up -d --remove-orphans";
      ExecStop = "${docker}/bin/docker compose -f ${composeFile} --env-file ${secretDir}/secret.env stop";
    };
  };

  # Sauvegarde nocturne -> Storage Box Hetzner (rclone crypt) : dump MariaDB +
  # fichiers du site. Les volumes Docker vivent déjà sur le volume Oracle
  # (/var/lib/docker est un bind de /mnt/storage2). 14 jours de rétention.
  systemd.services.erpnext-backup = {
    description = "Sauvegarde ERPNext vers la Storage Box";
    after = [ "garden-compose-erpnext.service" ];
    path = [ docker pkgs.gzip pkgs.gnutar pkgs.coreutils pkgs.findutils pkgs.util-linux ];
    serviceConfig = { Type = "oneshot"; TimeoutStartSec = 3600; };
    script = ''
      set -eu
      mountpoint -q /mnt/hermes
      d=/mnt/hermes/backups/erpnext
      install -d $d
      day=$(date +%F)
      docker exec erpnext-db-1 sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --all-databases --single-transaction' | gzip > $d/db-$day.sql.gz
      docker exec erpnext-backend-1 tar czf - --ignore-failed-read -C /home/frappe/frappe-bench/sites ${hostname}/private/files ${hostname}/public/files ${hostname}/site_config.json > $d/files-$day.tar.gz
      find $d -type f -mtime +14 -delete
    '';
  };
  systemd.timers.erpnext-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* 03:45:00"; Persistent = true; };
  };

  # Traefik (br-proxy) doit pouvoir atteindre ERPNext pour erp.lena.sh.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ port ];

  system.activationScripts.traefikErpRoute = ''
    if [ -d /srv/garden/traefik/dynamic ]; then
      ${pkgs.coreutils}/bin/install -m 0644 ${pkgs.writeText "erp.yml" ''
        http:
          routers:
            erp-router:
              rule: Host(`${hostname}`)
              service: erp-service
              entryPoints:
                - web
              middlewares:
                - redirect-to-https
            erp-router-secure:
              rule: Host(`${hostname}`)
              service: erp-service
              entryPoints:
                - websecure
              tls:
                certResolver: letsencrypt
              middlewares:
                - netbird-only
          services:
            erp-service:
              loadBalancer:
                servers:
                  - url: http://172.30.0.1:${toString port}
                passHostHeader: true
      ''} /srv/garden/traefik/dynamic/erp.yml
    fi
  '';
}
