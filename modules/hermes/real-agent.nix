{ ... }:
{
  ############################################################
  # hermes-real-agent — le vrai projet "Hermes Agent" (NousResearch),
  # celui que l'appli desktop officielle attend. C'est maintenant LE
  # cerveau (Telegram + backend desktop) ; hermes-agent-legacy (custom)
  # est retiré. Réutilise l'utilisateur `hermes` et son ACL vault.
  #
  # backend.mode = "serve" : expose /api/ws en local uniquement
  # (127.0.0.1:9119) — pas de port public ouvert. L'appli desktop s'y
  # connecte via une passerelle SSH (ubuntu@hermes.lena.sh), jamais en
  # HTTP direct depuis Internet.
  #
  # addToSystemPackages : le CLI `hermes` doit être sur le PATH de
  # l'utilisateur SSH (ubuntu) pour que la passerelle SSH de l'appli
  # desktop puisse le trouver et démarrer une session.
  ############################################################
  flake.modules.nixos."hermes-real-agent" = { config, lib, pkgs, ... }: {
    sops.secrets."hermes/backend_session_token" = { owner = "hermes"; mode = "0400"; };
    sops.secrets."hermes/deepseek_api_key" = { owner = "hermes"; mode = "0400"; };
    sops.secrets."hermes/telegram_bot_token" = { owner = "hermes"; mode = "0400"; };

    # TELEGRAM_ALLOWED_USERS n'est pas un secret (juste ton chat_id) :
    # valeur Nix normale, pas besoin de sops pour ça.
    # restartUnits : le chemin rendu par sops-nix est stable (toujours le
    # même /run/secrets-rendered/...), donc NixOS ne redémarre PAS
    # hermes-agent tout seul quand seul le CONTENU change (le nom du
    # fichier dans l'unit systemd ne bouge pas) — constaté en prod,
    # Telegram restait configuré avec l'ancien contenu après plusieurs
    # déploiements. Explicite ici pour que ça ne se reproduise plus.
    sops.templates."hermes-real-agent.env" = {
      owner = "hermes";
      mode = "0400";
      restartUnits = [ "hermes-agent.service" "hermes-backend.service" ];
      content = ''
        DEEPSEEK_API_KEY=${config.sops.placeholder."hermes/deepseek_api_key"}
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes/telegram_bot_token"}
        TELEGRAM_ALLOWED_USERS=5077790394
      '';
    };

    services.hermes-agent = {
      enable = true;
      user = "hermes";
      group = "hermes";
      workingDirectory = "/opt/vault";
      addToSystemPackages = true;
      settings.model.default = "deepseek/deepseek-chat";
      environmentFiles = [ config.sops.templates."hermes-real-agent.env".path ];
      backend = {
        mode = "serve";
        host = "127.0.0.1";
        port = 9119;
        sessionTokenFile = config.sops.secrets."hermes/backend_session_token".path;
      };
    };
  };
}
