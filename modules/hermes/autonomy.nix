############################################################
# hermes-autonomy — Hermes peut PROPOSER des changements (sa propre
# config, les fichiers par service de hosts/garden/) sans jamais toucher
# le checkout de prod (/etc/nixos, root:root, hermes n'y a aucun accès
# écriture) ni pousser/fusionner sur `main` lui-même.
#
# Garde-fous, du plus fort au plus faible :
#  1. Isolation cryptographique : clé age DÉDIÉE à Hermes
#     (/var/lib/hermes/.age/keys.txt, générée hors de toute clé admin).
#     Elle ne déchiffre QUE secrets/hermes-managed.yaml (voir .sops.yaml) —
#     secrets/garden.yaml (tes autres secrets) lui reste cryptographiquement
#     inaccessible, même sous instruction malveillante/injection de prompt.
#  2. Espace de travail séparé : un clone dédié
#     (/var/lib/hermes/dotfiles, appartenant à hermes), jamais /etc/nixos.
#     Hermes n'a aucun accès (ni lecture-écriture) à /etc/nixos : root:root,
#     755, et hermes n'est dans aucun groupe qui y donnerait accès.
#  3. Outil étroit (hermes-git-propose) : seul chemin pour committer depuis
#     ce clone. Refuse tout fichier en dehors de l'allowlist ci-dessous,
#     crée toujours une branche hermes/auto-*, ouvre une PR via l'API
#     GitHub — ne pousse jamais sur `main`. Allowlist (2026-11-07, élargie
#     sur demande explicite de Léna) : sa propre config
#     (modules/hermes/real-agent.nix), ses secrets
#     (secrets/hermes-managed.yaml), et tout hosts/garden/*.nix SAUF
#     default.nix (réseau, SSH, utilisateurs, disque — hors de portée).
#     Note : ça inclut comin.nix et disk.nix, qui ont plus de blast radius
#     que "gérer une appli" — explicitement acceptés par Léna en élargissant
#     à "tout hosts/garden/*.nix sauf default.nix", pas un oubli.
#  4. hermes-git-merge est un outil SÉPARÉ de hermes-git-propose : fusionner
#     une PR n'est jamais un effet de bord de la proposer. Pas de variable
#     d'environnement "auto-merge" permanente : Hermes ne peut se
#     l'accorder lui-même (ça avait été explicitement proposé par Hermes
#     sous couvert de "corriger un bug" qui n'existait pas — refusé). Léna
#     garde le dernier mot à chaque fusion, dans la conversation du moment.
#  5. Le jeton GitHub que ces outils utilisent est un fine-grained PAT
#     propre à Hermes (stocké DANS secrets/hermes-managed.yaml, donc
#     lui-même protégé par (1)) : Contents RW + Pull requests RW sur
#     lenadotgarden/dotfiles UNIQUEMENT, zéro droit admin. Même si ce token
#     fuitait, il ne permet pas de changer les protections de branche.
#
# Ce que ça NE fait PAS (volontairement) : pas de sudo supplémentaire pour
# hermes, pas d'accès à /etc/nixos, pas de push direct sur main, pas de
# bascule "auto-merge" permanente que Hermes pourrait s'activer seul.
############################################################
{ ... }:
{
flake.modules.nixos."hermes-autonomy" = { config, lib, pkgs, ... }:
let
  cloneDir = "/var/lib/hermes/dotfiles";
in
{
  systemd.services."hermes-dotfiles-clone" = {
    description = "Clone/synchronise le dépôt dotfiles pour l'espace de travail autonome de Hermes";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "hermes";
      Group = "hermes";
    };
    path = [ pkgs.git ];
    script = ''
      set -eu
      if [ ! -d ${cloneDir}/.git ]; then
        git clone https://github.com/lenadotgarden/dotfiles ${cloneDir}
      else
        cd ${cloneDir}
        git fetch origin
        git checkout main
        git reset --hard origin/main
      fi
    '';
  };

  environment.systemPackages = [
    # sops sur le PATH système : hermes n'est pas un utilisateur nix
    # trusted, `nix shell` lui est inaccessible (daemon refuse la
    # connexion, volontairement — pas d'évasion de sandbox nix). Un
    # binaire sops déjà construit, lui, ne demande rien au démon.
    pkgs.sops
    (pkgs.writeShellApplication {
      name = "hermes-git-propose";
      runtimeInputs = [ pkgs.git pkgs.sops pkgs.curl pkgs.jq ];
      text = ''
        # Usage : hermes-git-propose <fichier> <titre de la PR>
        # <fichier> doit être édité AVANT cet appel (dans ${cloneDir}),
        # via sops avec SOPS_AGE_KEY_FILE=/var/lib/hermes/.age/keys.txt.
        # Ce script se contente de committer/pousser/ouvrir la PR — il ne
        # touche jamais au contenu du fichier.
        if [ $# -lt 2 ]; then
          echo "usage: hermes-git-propose <fichier> <titre de la PR>" >&2
          exit 1
        fi
        file="$1"
        shift
        title="$*"

        case "$file" in
          secrets/hermes-managed.yaml) allowed=1 ;;
          modules/hermes/real-agent.nix) allowed=1 ;;
          hosts/garden/default.nix) allowed=0 ;;
          hosts/garden/*.nix) allowed=1 ;;
          *) allowed=0 ;;
        esac
        if [ "$allowed" -ne 1 ]; then
          echo "refusé : $file n'est pas dans l'allowlist (secrets/hermes-managed.yaml, modules/hermes/real-agent.nix, hosts/garden/*.nix sauf default.nix)" >&2
          exit 1
        fi

        cd ${cloneDir}

        dirty=$(git status --porcelain | awk '{print $2}')
        for f in $dirty; do
          if [ "$f" != "$file" ]; then
            echo "refusé : $f est aussi modifié, ce script ne committe que $file à la fois" >&2
            exit 1
          fi
        done
        if [ -z "$dirty" ]; then
          echo "rien à committer." >&2
          exit 1
        fi

        branch="hermes/auto-$(date +%Y%m%d-%H%M%S)"
        git checkout -b "$branch"
        git add "$file"
        git -c user.name="hermes" -c user.email="hermes@garden.lena.sh" commit -m "$title"

        token=$(SOPS_AGE_KEY_FILE=/var/lib/hermes/.age/keys.txt sops -d --extract '["github"]["hermes_pat"]' secrets/hermes-managed.yaml)
        git push "https://x-access-token:$token@github.com/lenadotgarden/dotfiles" "$branch"

        pr_url=$(curl -sS -X POST \
          -H "Authorization: Bearer $token" \
          -H "Accept: application/vnd.github+json" \
          https://api.github.com/repos/lenadotgarden/dotfiles/pulls \
          -d "$(jq -n --arg title "$title" --arg head "$branch" --arg base "main" \
                '{title: $title, head: $head, base: $base, body: "Proposé automatiquement par Hermes — ne touche que \($head)."}')" \
          | jq -r '.html_url')

        git checkout main
        echo "PR ouverte : $pr_url"
      '';
    })
    (pkgs.writeShellApplication {
      name = "hermes-git-merge";
      runtimeInputs = [ pkgs.git pkgs.sops pkgs.curl pkgs.jq ];
      text = ''
        # Usage : hermes-git-merge <numéro de PR>
        # Outil séparé de hermes-git-propose à dessein : fusionner une PR
        # n'est jamais un effet de bord de la proposer. À n'appeler QUE si
        # Léna l'a explicitement demandé, dans la conversation en cours,
        # pour CETTE PR précise. Pas de mode permanent.
        if [ $# -ne 1 ]; then
          echo "usage: hermes-git-merge <numero_PR>" >&2
          exit 1
        fi
        pr="$1"
        cd ${cloneDir}

        token=$(SOPS_AGE_KEY_FILE=/var/lib/hermes/.age/keys.txt sops -d --extract '["github"]["hermes_pat"]' secrets/hermes-managed.yaml)

        resp=$(curl -sS -X PUT \
          -H "Authorization: Bearer $token" \
          -H "Accept: application/vnd.github+json" \
          "https://api.github.com/repos/lenadotgarden/dotfiles/pulls/$pr/merge" \
          -d '{"merge_method":"squash"}')

        ok=$(echo "$resp" | jq -r '.merged // false')
        if [ "$ok" = "true" ]; then
          sha=$(echo "$resp" | jq -r '.sha')
          echo "fusionné : $sha (comin va déployer dans la minute)"
        else
          echo "échec : $(echo "$resp" | jq -r '.message // "réponse inattendue"')" >&2
          exit 1
        fi
      '';
    })
  ];
};
}
