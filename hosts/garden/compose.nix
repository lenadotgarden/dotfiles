{ config, lib, pkgs, ... }:
{
  ############################################################
  # Stack Docker (remplace Dokploy) : un docker-compose par service dans /srv/garden/<nom>
  # (les fichiers contiennent des secrets -> hors du store Nix). Images épinglées par digest.
  ############################################################
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
  }) [ "traefik" "netbird" "pihole" "syncthing" "calcom" "excalidash" "baserow" "mornye" "cadvisor" ]);
}
