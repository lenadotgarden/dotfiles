{ ... }:
{
  ############################################################
  # hermes-ctl — l'exécutant privilégié. Process séparé, utilisateur
  # séparé (hermes-ctl, pas hermes), aucun LLM dedans : juste une boucle
  # fixe qui lit /var/lib/hermes-ctl/requests/, revérifie elle-même le
  # niveau de confiance courant, et exécute via sudo les scripts root
  # étroits définis dans hermes-trust.nix. C'est la seule vraie barrière
  # de sécurité entre "Hermes a envie de faire X" et "X est fait".
  ############################################################
  flake.modules.nixos."hermes-ctl" = { config, lib, pkgs, ... }:
    let
      hermesCtl = pkgs.writers.writePython3Bin "hermes-ctl" { } (builtins.readFile ./scripts/hermes_ctl.py);
    in
    {
      systemd.tmpfiles.rules = [
        "d /var/lib/hermes-ctl 0750 hermes-ctl hermes-ctl -"
        # requests : hermes dépose des fichiers à un nom qu'il choisit (uuid),
        # mais ne peut ni lister ni lire/supprimer ceux des autres (sticky bit).
        "d /var/lib/hermes-ctl/requests 1730 hermes-ctl hermes -"
        # responses : hermes-ctl écrit, hermes lit seulement (pas d'écriture).
        # setgid pour que les fichiers créés dedans héritent du groupe hermes.
        "d /var/lib/hermes-ctl/responses 2750 hermes-ctl hermes -"
      ];

      systemd.services.hermes-ctl = {
        description = "Hermes — exécutant privilégié (sans LLM)";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          User = "hermes-ctl";
          Group = "hermes-ctl";
          Restart = "always";
          RestartSec = 5;
          ExecStart = "${hermesCtl}/bin/hermes-ctl";
          NoNewPrivileges = false; # il DOIT pouvoir utiliser sudo (NOPASSWD) — c'est son seul rôle
        };
      };
    };
}
