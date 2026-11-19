{ config, lib, pkgs, unstable, ... }:

let
  port = 5006;
  hostname = "budget.lena.sh";
in
{
  ############################################################
  # Actual Budget - budget personnel local-first (module nixpkgs
  # services.actual, paquet nixos-unstable). Données dans /var/lib/actual
  # (disque local). Pas de mot de passe dans la config : il se définit à
  # la première ouverture de l'interface (ne rien mettre dans le store).
  # Accès : NetBird uniquement via Traefik (budget.lena.sh, HTTPS requis
  # par le navigateur), et en direct sur localhost:5006 pour le MCP Hermes.
  ############################################################

  services.actual = {
    enable = true;
    package = unstable.actual-server;
    settings = {
      hostname = "0.0.0.0"; # joignable via NetBird (wt0 de confiance), port non ouvert publiquement
      inherit port;
    };
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
