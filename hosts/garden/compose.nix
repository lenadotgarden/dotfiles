{ config, lib, pkgs, ... }:
{
  imports = [ ./vikunja.nix ];

  # NETTOYAGE UNIQUE (retrait d'ERPNext et d'Actual Budget, 2026-11-19) : le volume
  # Oracle (/mnt/storage2) est trop petit/lent pour ERPNext. À retirer après un
  # déploiement réussi (relancé pour débloquer comin).
  system.activationScripts.removeErpnextActual = ''
    d=${config.virtualisation.docker.package}/bin/docker
    if ${pkgs.coreutils}/bin/timeout 60 $d info >/dev/null 2>&1; then
      for c in $(${pkgs.coreutils}/bin/timeout 120 $d ps -aq --filter label=com.docker.compose.project=erpnext); do
        ${pkgs.coreutils}/bin/timeout 120 $d rm -f -v $c || true
      done
      for v in db-data redis-queue-data sites logs; do
        ${pkgs.coreutils}/bin/timeout 120 $d volume rm erpnext_$v >/dev/null 2>&1 || true
      done
      ${pkgs.coreutils}/bin/timeout 60 $d network rm erpnext_default >/dev/null 2>&1 || true
      ${pkgs.coreutils}/bin/timeout 600 $d rmi frappe/erpnext:v16.60.0 mariadb:11.8 redis:6.2-alpine >/dev/null 2>&1 || true
      ${pkgs.coreutils}/bin/timeout 600 $d image prune -f >/dev/null 2>&1 || true
    fi
    rm -rf /var/lib/erpnext-secret /var/lib/actual /mnt/storage2/.garden-data/actual
    rm -f /srv/garden/traefik/dynamic/budget.yml /srv/garden/traefik/dynamic/erp.yml
  '';

  ############################################################
  # Stack Docker (remplace Dokploy) : un docker-compose par service dans /srv/garden/<nom>
  # (les fichiers contiennent des secrets -> hors du store Nix). Images épinglées par digest.
  ############################################################
  # beets-flask (5001) : Traefik (br-proxy) doit pouvoir l'atteindre côté hôte.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ 5001 ];

  # Route Traefik publique de docs.lena.sh (liens de partage /share/ uniquement),
  # versionnée ici (sans secret) et copiée à chaque activation. Le reste du
  # répertoire dynamic reste géré à la main dans /srv/garden/traefik/dynamic.
  system.activationScripts.traefikDocsRoute = ''
    if [ -d /srv/garden/traefik/dynamic ]; then
      ${pkgs.coreutils}/bin/install -m 0644 ${./traefik/docs.yml} /srv/garden/traefik/dynamic/docs.yml
    fi
  '';

  systemd.services = {
  garden-docker-network = {
    description = "Réseau Docker 'proxy' (Traefik <-> services)";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.virtualisation.docker.package ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      docker network inspect proxy >/dev/null 2>&1 || \
        docker network create --subnet 172.30.0.0/24 --opt com.docker.network.bridge.name=br-proxy proxy
    '';
  };
  } // lib.listToAttrs (map (name: lib.nameValuePair "garden-compose-${name}" {
    description = "docker compose : ${name}";
    after = [ "docker.service" "garden-docker-network.service" "garden-docker-firewall.service" ];
    requires = [ "docker.service" "garden-docker-network.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.virtualisation.docker.package ];
    environment.HOME = "/root";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/srv/garden/${name}";
      TimeoutStartSec = 900;
      ExecStart = "${config.virtualisation.docker.package}/bin/docker compose up -d --remove-orphans";
    };
  # "netbird" retiré (2026-11-14, en pause -> Tailscale) : compose file
  # conservé sur disque sous /srv/garden/netbird pour une reprise facile.
  }) [ "traefik" "pihole" "syncthing" "excalidash" "mornye" "cadvisor" "beets-flask" "maloja" ]);
}
