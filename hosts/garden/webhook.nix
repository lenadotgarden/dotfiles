{ config, lib, pkgs, ... }:

{
  ############################################################
  # Récepteur de webhook GitHub — déclenche un `comin fetch` immédiat sur
  # push vers main, plutôt que d'attendre le polling (jusqu'à 60s, parfois
  # plus en pratique). Exposé publiquement (webhook.lena.sh, GitHub doit
  # pouvoir l'atteindre), protégé par vérification HMAC du secret partagé
  # plutôt que par mot de passe.
  ############################################################
  sops.secrets."webhook/github_secret" = {
    owner = "comin-webhook";
    mode = "0400";
  };

  users.users.comin-webhook = {
    isSystemUser = true;
    group = "comin-webhook";
    extraGroups = [ "users" ]; # accès à /run/comin-grpc.sock (grpc.unix_socket_group)
  };
  users.groups.comin-webhook = { };

  systemd.services.comin-webhook = {
    description = "Récepteur de webhook GitHub pour comin";
    after = [ "comin.service" ];
    wants = [ "comin.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      GITHUB_WEBHOOK_SECRET_FILE = config.sops.secrets."webhook/github_secret".path;
      COMIN_BIN = "${config.services.comin.package}/bin/comin";
      PORT = "9000";
    };
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./webhook-receiver.py}";
      User = "comin-webhook";
      Group = "comin-webhook";
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  # Traefik (br-proxy) doit pouvoir atteindre le récepteur côté hôte.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ 9000 ];
}
