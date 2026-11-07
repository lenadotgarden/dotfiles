{ ... }:
{
  ############################################################
  # garden-secret-tool — ajouter un secret à secrets/garden.yaml en une
  # commande, sans jamais le faire passer par un chat ou un historique
  # shell. Avant : convertir la clé SSH de l'hôte en clé age, lancer
  # sops, taper le bloc YAML à la main, nettoyer la clé temporaire —
  # répété manuellement plusieurs fois le 2026-11-06/07.
  #
  # Usage : garden-secret-set hermes/excalidash_api_key
  #         (demande la valeur, invisible à la frappe, ne l'affiche jamais)
  ############################################################
  flake.modules.nixos."garden-secret-tool" = { config, lib, pkgs, ... }: {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "garden-secret-set";
        runtimeInputs = [ pkgs.sops pkgs.ssh-to-age ];
        text = ''
          if [ $# -ne 1 ]; then
            echo "usage: garden-secret-set <categorie/nom> (ex: hermes/excalidash_api_key)" >&2
            exit 1
          fi
          path="$1"
          cat="''${path%%/*}"
          key="''${path#*/}"
          if [ "$cat" = "$path" ]; then
            echo "format attendu : categorie/nom (ex: hermes/excalidash_api_key)" >&2
            exit 1
          fi

          read -r -s -p "Valeur pour $path : " value
          echo
          if [ -z "$value" ]; then
            echo "valeur vide, abandon." >&2
            exit 1
          fi

          tmpkey=$(mktemp)
          trap 'rm -f "$tmpkey"' EXIT
          ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key -o "$tmpkey"
          chmod 600 "$tmpkey"

          SOPS_AGE_KEY_FILE="$tmpkey" sops set /etc/nixos/secrets/garden.yaml \
            "[\"$cat\"][\"$key\"]" "\"$value\""

          echo "OK : $path ajouté/mis à jour dans secrets/garden.yaml."
          echo "Reste à : déclarer sops.secrets.\"$path\" quelque part et committer/pousser."
        '';
      })
    ];
  };
}
