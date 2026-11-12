{ config, lib, pkgs, unstable, ... }:

let
  port = 3456;
  hostname = "tasks.lena.sh";
in
{
  ############################################################
  # Vikunja - gestionnaire de tâches (module nixpkgs services.vikunja,
  # paquet nixos-unstable : 2.8.0 au moment de l'ajout, MCP intégré
  # servi sur /api/v2/mcp depuis la 2.7.0). SQLite locale dans
  # /var/lib/vikunja (petite, doit rester sur disque local).
  # Accès : NetBird uniquement via Traefik (tasks.lena.sh), et en direct
  # sur localhost:3456 pour l'agent Hermes (MCP).
  ############################################################

  services.vikunja = {
    enable = true;
    package = unstable.vikunja;
    frontendScheme = "https";
    frontendHostname = hostname;
    address = "0.0.0.0"; # joignable via NetBird (wt0 est de confiance), pas exposé publiquement
    inherit port;
    environmentFiles = [ "/var/lib/vikunja-secret/secret.env" ];
    settings.service.timezone = "Europe/Paris";
    # A passer à false une fois ton compte créé.
    settings.service.enableregistration = true;
  };

  # Secret de signature des sessions : généré une fois par un oneshot root
  # (avant vikunja : systemd lit l'EnvironmentFile avant tout ExecStartPre, donc
  # le fichier doit déjà exister au premier démarrage). Sans lui, chaque
  # redémarrage déconnecte tout le monde.
  systemd.services.vikunja-secret = {
    description = "Génère le secret de session Vikunja";
    before = [ "vikunja.service" ];
    requiredBy = [ "vikunja.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      d=/var/lib/vikunja-secret
      install -d -m 0700 $d
      if [ ! -s $d/secret.env ]; then
        umask 077
        echo "VIKUNJA_SERVICE_SECRET=$(${pkgs.openssl}/bin/openssl rand -hex 32)" > $d/secret.env
      fi
    '';
  };

  # Traefik (br-proxy) doit pouvoir atteindre vikunja pour tasks.lena.sh.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ port ];

  # Route Traefik versionnée ici (sans secret), copiée à chaque activation
  # dans le dossier dynamic (même mécanisme que docs.yml dans compose.nix).
  system.activationScripts.traefikTasksRoute = ''
    if [ -d /srv/garden/traefik/dynamic ]; then
      ${pkgs.coreutils}/bin/install -m 0644 ${pkgs.writeText "tasks.yml" ''
        http:
          routers:
            tasks-router:
              rule: Host(`${hostname}`)
              service: tasks-service
              entryPoints:
                - web
              middlewares:
                - redirect-to-https
            tasks-router-secure:
              rule: Host(`${hostname}`)
              service: tasks-service
              entryPoints:
                - websecure
              tls:
                certResolver: letsencrypt
              middlewares:
                - netbird-only
          services:
            tasks-service:
              loadBalancer:
                servers:
                  - url: http://172.30.0.1:${toString port}
                passHostHeader: true
      ''} /srv/garden/traefik/dynamic/tasks.yml
    fi
  '';
}
