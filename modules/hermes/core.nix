{ ... }:
{
  ############################################################
  # hermes-core — pont Telegram "maison" écrit avant de découvrir le vrai
  # projet NousResearch/hermes-agent (cf hermes-real-agent.nix, qui est
  # maintenant le cerveau officiel). Gardé sous le nom hermes-agent-legacy
  # (renommé pour ne plus entrer en collision avec le service officiel
  # `hermes-agent` du module importé) UNIQUEMENT pour ne pas couper le
  # canal Telegram qui fonctionne déjà, en attendant de le migrer vers
  # `hermes gateway` (le gateway messagerie natif du vrai projet). À
  # retirer une fois cette migration faite.
  #
  # La sécurité ne repose pas sur un système de permissions interne au
  # modèle : Hermes n'a tout simplement pas les outils/droits Unix pour
  # faire du mal. Les seules actions "privilégiées" (statut docker,
  # redémarrage, changement de niveau de confiance) passent par une
  # boîte aux lettres fichiers vers hermes-ctl (utilisateur séparé,
  # process séparé, pas de LLM dedans) — cf hermes-ctl.nix.
  ############################################################
  flake.modules.nixos."hermes-core" = { config, lib, pkgs, ... }:
    let
      cfg = config.hermes;
      hermesAgent = pkgs.writers.writePython3Bin "hermes-agent"
        {
          libraries = [ pkgs.python3Packages.requests pkgs.python3Packages.python-telegram-bot ];
          flakeIgnore = [ "E501" "E265" "E131" ];
        }
        (builtins.readFile ./scripts/hermes_agent.py);
    in
    {
      options.hermes = {
        workspace = lib.mkOption {
          type = lib.types.str;
          default = "/opt/vault";
          description = "Répertoire de travail de Hermes (son vault, sa mémoire).";
        };
        telegramAllowedChatId = lib.mkOption {
          type = lib.types.int;
          description = "Seul chat_id Telegram autorisé à parler à Hermes.";
        };
      };

      config = {
        sops.secrets."hermes/deepseek_api_key" = { owner = "hermes"; mode = "0400"; };
        sops.secrets."hermes/telegram_bot_token" = { owner = "hermes"; mode = "0400"; };
        # EnvironmentFile veut des lignes KEY=VALUE : passer par un template
        # sops (comme matrix.nix) plutôt que les secrets bruts.
        sops.templates."hermes-agent.env" = {
          owner = "hermes";
          mode = "0400";
          content = ''
            DEEPSEEK_API_KEY=${config.sops.placeholder."hermes/deepseek_api_key"}
            TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes/telegram_bot_token"}
          '';
        };

        environment.etc."hermes/AGENTS.md".text = ''
          # Toi, Hermes

          Tu es Hermes, un agent qui vit sur le serveur "garden" de Léna, avec accès
          à son vault Obsidian "Garden" (ton espace de travail) pour mémoire, journal
          et contexte. Tu es traité comme un·e stagiaire : tu commences en lecture
          quasi-seule et tu gagnes en responsabilité progressivement, avec l'accord
          explicite de Léna à chaque étape — jamais par toi-même.

          ## Outils disponibles
          - `read_file` / `write_file` / `list_dir` dans ton vault (chemins relatifs
            à sa racine). Utilise `6 Archive/Hermes/` pour ton propre journal.
          - `status` : état en lecture seule du serveur (services, niveau actuel).
          - `restart_service` : redémarre un service docker-compose déjà connu.
            Nécessite le niveau de confiance 1 — refusé sinon, c'est normal.
          - `request_promotion` : demande à Léna de faire passer ton niveau de
            confiance, avec une vraie raison concrète. Rien ne change avant sa
            confirmation explicite sur Telegram. Ne redemande pas en boucle si elle
            dit non ou ne répond pas.

          ## Règles
          - Tu n'as pas de sudo, pas d'accès docker direct, pas d'accès à `/etc/nixos`.
            C'est voulu. Toute action hors de tes outils doit passer par une demande
            explicite à Léna.
          - Annonce ce que tu fais et pourquoi quand tu agis (restart_service), pas
            seulement le résultat.
        '';

        systemd.services.hermes-agent-legacy = {
          description = "Hermes (legacy) — pont Telegram maison, à migrer vers hermes gateway";
          after = [ "network-online.target" "sops-nix.service" "garden-vault-acl.service" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          environment = {
            HERMES_WORKSPACE = cfg.workspace;
            TELEGRAM_ALLOWED_CHAT_ID = toString cfg.telegramAllowedChatId;
          };
          serviceConfig = {
            Type = "simple";
            User = "hermes";
            Group = "hermes";
            UMask = "0002";
            WorkingDirectory = cfg.workspace;
            Restart = "always";
            RestartSec = 10;
            ExecStart = "${hermesAgent}/bin/hermes-agent";
            EnvironmentFile = [ config.sops.templates."hermes-agent.env".path ];
            # NoNewPrivileges : même si hermes obtenait un jour une entrée
            # sudoers par erreur de config, ce service ne pourrait pas s'en
            # servir (ceinture-bretelles).
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ReadWritePaths = [ cfg.workspace "/var/lib/hermes-ctl/requests" ];
            ProtectHome = "read-only";
          };
        };
      };
    };
}
