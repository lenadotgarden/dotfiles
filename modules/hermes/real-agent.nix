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

    services.hermes-agent = {
      enable = true;
      user = "hermes";
      group = "hermes";
      workingDirectory = "/opt/vault";
      settings.model.default = "deepseek/deepseek-chat";
      environmentFiles = [ config.sops.templates."hermes-agent.env".path ];
      backend = {
        mode = "serve";
        host = "127.0.0.1";
        port = 9119;
        sessionTokenFile = config.sops.secrets."hermes/backend_session_token".path;
      };
    };
  };
}
