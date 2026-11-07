{ ... }:
{
  ############################################################
  # hermes-real-agent — le vrai projet "Hermes Agent" (NousResearch),
  # celui que l'appli desktop officielle attend. C'est maintenant LE
  # cerveau (Telegram + backend desktop) ; hermes-agent-legacy (custom)
  # est retiré. Réutilise l'utilisateur `hermes` et son ACL vault.
  #
  # backend.mode = "dashboard" : API + panneau web, sur 0.0.0.0:9119.
  # Pas un vrai risque d'exposition publique : le firewall de garden est
  # en default-deny (seuls 22/2222/8443 sont ouverts), et wt0 (NetBird,
  # réseau déjà "trusted") est la seule interface qui le contourne — donc
  # dans les faits, joignable uniquement depuis ton Mac via NetBird
  # (http://100.79.103.184:9119), jamais depuis l'Internet public.
  #
  # Deux couches d'auth (un bind non-loopback active le portail
  # automatiquement) :
  #  - sessionTokenFile : jeton API pour la connexion "Remote gateway"
  #    de l'appli desktop.
  #  - HERMES_DASHBOARD_BASIC_AUTH_* : login/mot de passe pour le
  #    panneau web dans un navigateur.
  #
  # addToSystemPackages : le CLI `hermes` doit être sur le PATH système
  # (utile pour du debug via SSH en tant que ubuntu).
  ############################################################
  flake.modules.nixos."hermes-real-agent" = { config, lib, pkgs, ... }: {
    sops.secrets."hermes/backend_session_token" = { owner = "hermes"; mode = "0400"; };
    sops.secrets."hermes/deepseek_api_key" = { owner = "hermes"; mode = "0400"; };
    sops.secrets."hermes/telegram_bot_token" = { owner = "hermes"; mode = "0400"; };
    sops.secrets."hermes/dashboard_basic_auth_password" = { owner = "hermes"; mode = "0400"; };
    sops.secrets."hermes/dashboard_basic_auth_secret" = { owner = "hermes"; mode = "0400"; };
    sops.secrets."hermes/excalidash_api_key" = { owner = "hermes"; mode = "0400"; };
    sops.secrets."discord/bot_token" = { owner = "hermes"; mode = "0400"; };

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
        HERMES_DASHBOARD_BASIC_AUTH_USERNAME=lena
        HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${config.sops.placeholder."hermes/dashboard_basic_auth_password"}
        HERMES_DASHBOARD_BASIC_AUTH_SECRET=${config.sops.placeholder."hermes/dashboard_basic_auth_secret"}
        EXCALIDASH_API_URL=https://excali.lena.sh
        EXCALIDASH_API_KEY=${config.sops.placeholder."hermes/excalidash_api_key"}
        DISCORD_BOT_TOKEN=${config.sops.placeholder."discord/bot_token"}
        DISCORD_ALLOWED_USERS=352145457776033795
      '';
    };

    services.hermes-agent = {
      enable = true;
      user = "hermes";
      group = "hermes";
      workingDirectory = "/opt/vault";
      addToSystemPackages = true;
      settings.model.default = "deepseek/deepseek-chat";
      settings.discord.auto_thread = false;
      settings.display.tool_progress = "off";
      settings.display.interim_assistant_messages = false;
      environmentFiles = [ config.sops.templates."hermes-real-agent.env".path ];
      backend = {
        mode = "dashboard";
        host = "0.0.0.0";
        port = 9119;
        sessionTokenFile = config.sops.secrets."hermes/backend_session_token".path;
      };
    };
  };
}
