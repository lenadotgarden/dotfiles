{ config, lib, pkgs, unstable, ... }:

let
  port = 5006;
  hostname = "budget.lena.sh";
  # 2e volume Oracle (50 Go, détachable) : le disque de boot est presque plein.
  dataDir = "/mnt/storage2/.garden-data/actual";
  backupDir = "/mnt/hermes/backups/actual"; # Storage Box Hetzner (chiffré)
in
{
  ############################################################
  # Actual Budget - budget personnel local-first (module nixpkgs
  # services.actual, paquet nixos-unstable). Données sur le volume Oracle
  # (${dataDir}), sauvegarde nocturne chiffrée sur la Storage Box Hetzner.
  # Pas de mot de passe dans la config : il se définit à la première
  # ouverture de l'interface.
  # Accès : NetBird uniquement via Traefik (budget.lena.sh, HTTPS requis
  # par le navigateur), et en direct sur localhost:5006 pour le MCP Hermes.
  ############################################################

  # Utilisateur fixe (pas DynamicUser) pour pouvoir posséder un dossier hors /var/lib.
  users.users.actual = { isSystemUser = true; group = "actual"; };
  users.groups.actual = { };

  services.actual = {
    enable = true;
    package = unstable.actual-server;
    user = "actual";
    group = "actual";
    settings = {
      inherit port dataDir;
      hostname = "0.0.0.0"; # joignable via NetBird (wt0 de confiance), port non ouvert publiquement
    };
  };

  # Dossiers créés avant le service (ReadWritePaths du module exige qu'ils existent).
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0700 actual actual -"
    "d ${dataDir}/server-files 0700 actual actual -"
    "d ${dataDir}/user-files 0700 actual actual -"
  ];
  systemd.services.actual.unitConfig.RequiresMountsFor = [ "/mnt/storage2" ];

  # Sauvegarde nocturne -> Storage Box (rclone crypt), 14 jours de rétention.
  systemd.services.actual-backup = {
    description = "Sauvegarde Actual Budget vers la Storage Box";
    path = [ pkgs.gnutar pkgs.gzip pkgs.coreutils pkgs.findutils pkgs.util-linux ];
    serviceConfig = { Type = "oneshot"; };
    script = ''
      set -eu
      mountpoint -q /mnt/hermes
      install -d ${backupDir}
      tar czf ${backupDir}/actual-$(date +%F).tar.gz -C ${dataDir} .
      find ${backupDir} -name 'actual-*.tar.gz' -mtime +14 -delete
    '';
  };
  systemd.timers.actual-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* 03:30:00"; Persistent = true; };
  };

  # Traefik (br-proxy) doit pouvoir atteindre Actual pour budget.lena.sh.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ port ];

  system.activationScripts.traefikBudgetRoute = ''
    if [ -d /srv/garden/traefik/dynamic ]; then
      ${pkgs.coreutils}/bin/install -m 0644 ${pkgs.writeText "budget.yml" ''
        http:
          routers:
            budget-router:
              rule: Host(`${hostname}`)
              service: budget-service
              entryPoints:
                - web
              middlewares:
                - redirect-to-https
            budget-router-secure:
              rule: Host(`${hostname}`)
              service: budget-service
              entryPoints:
                - websecure
              tls:
                certResolver: letsencrypt
              middlewares:
                - netbird-only
          services:
            budget-service:
              loadBalancer:
                servers:
                  - url: http://172.30.0.1:${toString port}
                passHostHeader: true
      ''} /srv/garden/traefik/dynamic/budget.yml
    fi
  '';
}
