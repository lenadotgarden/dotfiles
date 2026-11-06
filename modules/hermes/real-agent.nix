{ ... }:
{
  ############################################################
  # hermes-real-agent — le vrai projet "Hermes Agent" (NousResearch),
  # celui que l'appli desktop officielle attend. Remplace l'agent custom
  # (hermes-core) comme cerveau ; réutilise le même utilisateur `hermes`
  # et donc le même ACL vault déjà corrigé (hermes-vault-acl).
  #
  # backend.mode = "serve" : expose /api/ws en local uniquement
  # (127.0.0.1:9119) — pas de port public ouvert. L'appli desktop doit
  # s'y connecter via une passerelle SSH (user ubuntu@garden, tunnel),
  # jamais en HTTP direct depuis Internet.
  ############################################################
  flake.modules.nixos."hermes-real-agent" = { config, lib, pkgs, ... }: {
    sops.secrets."hermes/backend_session_token" = { owner = "hermes"; mode = "0400"; };

    # Fichier d'env dédié : surtout PAS le même que hermes-agent-legacy
    # (hermes-agent.env), qui contient aussi TELEGRAM_BOT_TOKEN — sinon le
    # vrai hermes gateway tente de poller Telegram en même temps que le
    # bot maison et les deux se font jeter par l'API Telegram (un seul
    # poller autorisé par token). Telegram reste pour l'instant la
    # responsabilité exclusive du legacy, tant que la migration vers
    # `hermes gateway` n'est pas faite délibérément.
    sops.templates."hermes-real-agent.env" = {
      owner = "hermes";
      mode = "0400";
      content = "DEEPSEEK_API_KEY=${config.sops.placeholder."hermes/deepseek_api_key"}";
    };

    services.hermes-agent = {
      enable = true;
      user = "hermes";
      group = "hermes";
      workingDirectory = "/opt/vault";
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
