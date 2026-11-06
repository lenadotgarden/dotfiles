{ ... }:
{
  ############################################################
  # hermes-trust — le niveau de confiance de Hermes et les actions
  # privilégiées qu'il débloque. Règle absolue : `hermes` (le cerveau,
  # qui exécute le bash tool d'opencode) n'a AUCUNE entrée sudoers, et
  # /etc/hermes/trust_level est root:root 0644 (lisible par hermes,
  # jamais écrit par lui). Seul `hermes-ctl` (processus de contrôle fixe,
  # pas piloté par le LLM) a le droit d'exécuter ces scripts, et
  # uniquement après confirmation explicite de Léna sur Telegram pour
  # toute promotion de niveau.
  #
  # Niveaux :
  #   0 = lecture seule (par défaut)
  #   1 = peut redémarrer les projets docker-compose déjà déclarés
  #   2 = réservé (ouverture de PR GitHub) — scaffoldé, pas câblé
  #       tant qu'un token GitHub scopé n'existe pas (cf plan).
  ############################################################
  flake.modules.nixos."hermes-trust" = { config, lib, pkgs, ... }:
    let
      # Garder synchronisé avec la liste dans hosts/garden/compose.nix.
      composeProjects = [ "traefik" "netbird" "pihole" "syncthing" "calcom" "excalidash" "baserow" "mornye" ];

      garden-hermes-set-trust = pkgs.writeShellApplication {
        name = "garden-hermes-set-trust";
        runtimeInputs = [ pkgs.systemd pkgs.coreutils ];
        text = ''
          level="${"$"}{1:-}"
          if ! [[ "$level" =~ ^[0-2]$ ]]; then
            echo "usage: garden-hermes-set-trust <0|1|2>" >&2
            exit 1
          fi
          echo "$level" > /etc/hermes/trust_level.tmp
          chown root:root /etc/hermes/trust_level.tmp
          chmod 0644 /etc/hermes/trust_level.tmp
          mv -f /etc/hermes/trust_level.tmp /etc/hermes/trust_level
          systemctl restart hermes-opencode.service
          echo "trust_level=$level appliqué"
        '';
      };

      mkRestartScript = name: pkgs.writeShellApplication {
        name = "garden-hermes-restart-${name}";
        runtimeInputs = [ config.virtualisation.docker.package ];
        text = ''
          cd /srv/garden/${name}
          docker compose up -d --remove-orphans
        '';
      };

      garden-hermes-status = pkgs.writeShellApplication {
        name = "garden-hermes-status";
        runtimeInputs = [ config.virtualisation.docker.package pkgs.systemd ];
        text = ''
          echo "== docker ps =="
          docker ps --format 'table {{.Names}}\t{{.Status}}'
          echo "== niveau de confiance =="
          cat /etc/hermes/trust_level 2>/dev/null || echo 0
        '';
      };
    in
    {
      # /etc/hermes/trust_level est un fichier d'état RUNTIME, pas géré par
      # environment.etc (qui en ferait un lien symbolique immuable vers le
      # store) : juste créé une fois avec 0 s'il n'existe pas encore, puis
      # seul garden-hermes-set-trust (ci-dessus) le modifie.
      system.activationScripts.hermes-trust-init = lib.stringAfter [ "users" ] ''
        mkdir -p /etc/hermes
        [ -f /etc/hermes/trust_level ] && [ -s /etc/hermes/trust_level ] || echo 0 > /etc/hermes/trust_level
        chown root:root /etc/hermes/trust_level
        chmod 0644 /etc/hermes/trust_level
      '';

      environment.systemPackages = [ garden-hermes-set-trust garden-hermes-status ]
        ++ map mkRestartScript composeProjects;

      security.sudo.extraRules = [
        {
          users = [ "hermes-ctl" ];
          commands = [
            { command = "${garden-hermes-set-trust}/bin/garden-hermes-set-trust"; options = [ "NOPASSWD" ]; }
            { command = "${garden-hermes-status}/bin/garden-hermes-status"; options = [ "NOPASSWD" ]; }
          ] ++ map (name: {
            command = "${mkRestartScript name}/bin/garden-hermes-restart-${name}";
            options = [ "NOPASSWD" ];
          }) composeProjects;
        }
      ];
      # garden-hermes-status lit docker ps (nécessite root/groupe docker) :
      # seul hermes-ctl peut l'appeler (sudo ci-dessus), qui l'expose à
      # Hermes via la boîte aux lettres fichiers (cf hermes-ctl.nix) —
      # hermes lui-même n'a ni sudo ni accès docker.
    };
}
