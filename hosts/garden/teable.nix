{ config, lib, pkgs, ... }:

let
  port = 3110;
  hostname = "teable.lena.sh";
  # 2e volume Oracle (50 Go) : Postgres doit rester sur un disque bloc local,
  # pas sur la Storage Box (montage distant trop lent pour une base).
  dataDir = "/mnt/storage2/.garden-data/teable";
  secretDir = "/var/lib/teable-secret";
  backupDir = "/mnt/hermes/backups/teable"; # Storage Box Hetzner (chiffré)
  docker = config.virtualisation.docker.package;

  composeFile = pkgs.writeText "teable-compose.yml" ''
    services:
      teable:
        image: ghcr.io/teableio/teable:latest
        restart: always
        ports:
          - "172.30.0.1:${toString port}:3000"
        volumes:
          - ${dataDir}/assets:/app/.assets:rw
        env_file:
          - ${secretDir}/env
        environment:
          - TZ=Europe/Paris
        networks:
          - teable
        depends_on:
          teable-db:
            condition: service_healthy
          teable-cache:
            condition: service_healthy
      teable-db:
        image: postgres:15.4
        restart: always
        volumes:
          - ${dataDir}/db:/var/lib/postgresql/data:rw
        environment:
          - TZ=Europe/Paris
          - POSTGRES_DB=teable
          - POSTGRES_USER=teable
          - POSTGRES_PASSWORD=''${POSTGRES_PASSWORD}
        networks:
          - teable
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U teable -d teable"]
          interval: 10s
          timeout: 3s
          retries: 5
      teable-cache:
        image: redis:7.2.4
        restart: always
        volumes:
          - ${dataDir}/cache:/data:rw
        networks:
          - teable
        command: redis-server --appendonly yes --requirepass ''${REDIS_PASSWORD}
        healthcheck:
          test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
          interval: 10s
          timeout: 3s
          retries: 5
    networks:
      teable:
        name: teable-network
        driver: bridge
  '';
in
{
  ############################################################
  # Teable (alternative libre à Airtable, PostgreSQL) pour les projets pro et
  # le calendrier édito. Données sur le 2e volume Oracle (${dataDir}),
  # sauvegarde nocturne vers la Storage Box. Secrets générés une fois, hors store.
  # Accès : Traefik (teable.lena.sh), même protection que Vikunja/Actual. Certificat LE : HTTP-01, l enregistrement DNS doit pointer sur l IP publique le temps de l émission.
  ############################################################

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 root root -"
    "d ${dataDir}/assets 0755 root root -"
    "d ${dataDir}/cache 0755 root root -"
  ];

  systemd.services.teable-secret = {
    description = "Génère les secrets Teable";
    before = [ "teable.service" ];
    requiredBy = [ "teable.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      install -d -m 0700 ${secretDir}
      if [ ! -s ${secretDir}/env ]; then
        umask 077
        pg=$(${pkgs.openssl}/bin/openssl rand -hex 24)
        rd=$(${pkgs.openssl}/bin/openssl rand -hex 24)
        cat > ${secretDir}/env <<EOF
    POSTGRES_PASSWORD=$pg
    REDIS_PASSWORD=$rd
    PUBLIC_ORIGIN=https://${hostname}
    PRISMA_DATABASE_URL=postgresql://teable:$pg@teable-db:5432/teable
    BACKEND_CACHE_PROVIDER=redis
    BACKEND_CACHE_REDIS_URI=redis://default:$rd@teable-cache:6379/0
    EOF
      fi
    '';
  };

  systemd.services.teable = {
    description = "Teable (docker compose)";
    after = [ "docker.service" "teable-secret.service" "garden-docker-network.service" "mnt-storage2.mount" ];
    requires = [ "docker.service" "teable-secret.service" ];
    unitConfig.RequiresMountsFor = [ "/mnt/storage2" ];
    wantedBy = [ "multi-user.target" ];
    path = [ docker ];
    environment.HOME = "/root";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 900;
      ExecStart = "${docker}/bin/docker compose -p teable --env-file ${secretDir}/env -f ${composeFile} up -d --remove-orphans";
      ExecStop = "${docker}/bin/docker compose -p teable --env-file ${secretDir}/env -f ${composeFile} down";
    };
  };

  # Sauvegarde nocturne : dump Postgres + assets -> Storage Box, 14 jours.
  systemd.services.teable-backup = {
    description = "Sauvegarde Teable vers la Storage Box";
    path = [ docker pkgs.gnutar pkgs.gzip pkgs.coreutils pkgs.findutils pkgs.util-linux ];
    serviceConfig = { Type = "oneshot"; };
    script = ''
      set -eu
      mountpoint -q /mnt/hermes
      install -d ${backupDir}
      d=$(date +%F)
      docker exec teable-teable-db-1 pg_dump -U teable teable | gzip > ${backupDir}/teable-db-$d.sql.gz
      tar czf ${backupDir}/teable-assets-$d.tar.gz -C ${dataDir} assets
      find ${backupDir} -name 'teable-*' -mtime +14 -delete
    '';
  };
  systemd.timers.teable-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* 03:45:00"; Persistent = true; };
  };

  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ port ];

  system.activationScripts.traefikTeableRoute = ''
    if [ -d /srv/garden/traefik/dynamic ]; then
      ${pkgs.coreutils}/bin/install -m 0644 ${pkgs.writeText "teable.yml" ''
        http:
          routers:
            teable-router:
              rule: Host(`${hostname}`)
              service: teable-service
              entryPoints:
                - web
              middlewares:
                - redirect-to-https
            teable-router-secure:
              rule: Host(`${hostname}`)
              service: teable-service
              entryPoints:
                - websecure
              tls:
                certResolver: letsencrypt
              middlewares:
                - netbird-only
          services:
            teable-service:
              loadBalancer:
                servers:
                  - url: http://172.30.0.1:${toString port}
                passHostHeader: true
      ''} /srv/garden/traefik/dynamic/teable.yml
    fi
  '';
}
