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
  flake.modules.nixos."hermes-real-agent" = { config, lib, pkgs, ... }:
    let
      # Route "petites tâches" : DeepSeek 4.1 flash (API DeepSeek, modèle
      # `deepseek-flash`). Sert aux tâches internes qui n'ont pas besoin de
      # l'orchestrateur (compression, titres, classifieur d'approbation, MCP,
      # triage/décomposition Kanban, routeur de groupe, ...).
      auxFlash = {
        provider = "deepseek";
        model = "deepseek-flash";
      };
    in
    {
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
        # /sethome ne persiste pas : la passerelle le perd à chaque redémarrage.
        # Déclaré ici pour que le canal par défaut (cron + messages) soit stable.
        DISCORD_HOME_CHANNEL=1568658252634267791
        DISCORD_HOME_CHANNEL_NAME="#《🔔》notifs"
      '';
    };

    services.hermes-agent = {
      enable = true;
      user = "hermes";
      group = "hermes";
      workingDirectory = "/opt/vault";
      addToSystemPackages = true;
      # Orchestrateur = Claude Sonnet via l'abonnement Claude Pro, à travers la
      # CLI officielle `claude` (plugin claude-subscription-directsdk). Aucune
      # clé API Anthropic, aucune facture au token : la conso est imputée au
      # quota Agent SDK de l'abonnement. `sonnet` est l'alias natif (résout
      # vers claude-sonnet-5[1m]).
      settings.model.provider = "claude-subscription-directsdk-experimental";
      settings.model.default = "sonnet";
      settings.discord.auto_thread = false;
      settings.display.tool_progress = "off";
      settings.display.interim_assistant_messages = false;
      # CLI installs hors nixpkgs (defuddle, bw, codebase-memory-mcp, agent-reach)
      settings.mcp_servers.codebase-memory = {
        command = "/var/lib/hermes/.local/bin/codebase-memory-mcp";
        args = [ ];
        timeout = 120;
      };

      # ── Routage des modèles ──────────────────────────────────────────
      # Plugins installés en user-space (~/.hermes/plugins) ; la passerelle
      # tourne sous l'utilisateur hermes et partage ce home.
      settings.plugins.enabled = [
        "claude-subscription-directsdk-experimental"
        "advanced-delegation"
      ];

      # Le login `claude` a été fait avec un HOME différent (le home passwd de
      # l'utilisateur hermes est /opt/vault) : on fige le dossier de config
      # pour que la passerelle lise toujours /var/lib/hermes/.claude.
      settings.plugins.entries."claude-subscription-directsdk-experimental".settings.claude_config_dir =
        "/var/lib/hermes/.claude";

      # Tâches internes qui ne méritent pas l'orchestrateur : DeepSeek flash.
      # Volontairement exclues de cette liste : `background_review` et
      # `curator` (ils relisent et réécrivent mémoire et skills, la qualité
      # prime sur le coût) et `vision` (pas un modèle texte).
      settings.auxiliary = {
        compression = auxFlash;
        title_generation = auxFlash;
        approval = auxFlash;
        mcp = auxFlash;
        memory_query_rewrite = auxFlash;
        triage_specifier = auxFlash;
        kanban_decomposer = auxFlash;
        profile_describer = auxFlash;
        group_router = auxFlash;
        goal_judge = auxFlash;
        monitor = auxFlash;
        tts_audio_tags = auxFlash;
      };

      # Sous-agents : le modèle choisit une route nommée par tâche (plugin
      # advanced-delegation). Une tâche sans route hérite de l'orchestrateur.
      settings.delegation = {
        backend = "model_map";
        backends.model_map = {
          options = [
            {
              name = "fast";
              description = "Rapide et pas cher : recherches simples, résumés, extractions, petites éditions.";
              provider = "deepseek";
              model = "deepseek-flash";
            }
            {
              name = "balanced";
              description = "Tâches courantes : rédaction, analyse moyenne, plusieurs étapes.";
              provider = "deepseek";
              model = "deepseek-chat";
            }
            {
              name = "deep";
              description = "Raisonnement complexe, debug difficile, décisions structurantes.";
              provider = "claude-subscription-directsdk-experimental";
              model = "sonnet";
            }
          ];
        };
      };

      environmentFiles = [ config.sops.templates."hermes-real-agent.env".path ];
      backend = {
        mode = "dashboard";
        host = "0.0.0.0";
        port = 9119;
        sessionTokenFile = config.sops.secrets."hermes/backend_session_token".path;
      };
    };

    # ── Réglages de l'unité (hors de l'attrset services.hermes-agent) ────
    # `systemd.services.<x>.path` ajoute "/bin" (et "/sbin") à CHAQUE entrée
    # (nixpkgs modules/system/boot/systemd.nix, makeBinPath) : il faut donner
    # le dossier PARENT de bin/, pas bin/ lui-même. L'ancienne valeur
    # ("/var/lib/hermes/.local/bin") produisait ".local/bin/bin", qui n'existe
    # pas - au final ~/.local/bin n'a jamais été sur le PATH de l'unité, les
    # CLI user-space (defuddle, bw, codebase-memory-mcp, agent-reach) restaient
    # appelables seulement par chemin absolu (bug préexistant, corrigé ici).
    # "/run/current-system/sw" ajouté pour que `claude` (environment.systemPackages,
    # hosts/garden/default.nix) soit trouvable par le plugin Claude Subscription
    # DirectSDK - sans ça la passerelle répond "Could not find ... 'claude'"
    # après chaque redémarrage, malgré un `claude auth login` déjà fait.
    systemd.services.hermes-agent.path = [ "/var/lib/hermes/.local" "/run/current-system/sw" ];
  };
}
