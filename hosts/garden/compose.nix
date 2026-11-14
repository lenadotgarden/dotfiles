{ config, lib, pkgs, ... }:
{
  imports = [ ./vikunja.nix ];

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
