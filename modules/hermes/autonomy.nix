############################################################
# hermes-autonomy — Hermes peut PROPOSER des changements à sa propre
# config/secrets sans jamais toucher le checkout de prod (/etc/nixos,
# root:root, hermes n'y a aucun accès écriture) ni pousser sur `main`
# (qui ferait déployer comin automatiquement).
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
#     GitHub — ne pousse jamais sur `main`.
#  4. Le jeton GitHub que ce script utilise est un fine-grained PAT propre
#     à Hermes (stocké DANS secrets/hermes-managed.yaml, donc lui-même
#     protégé par (1)) : à créer dans github.com/settings/tokens avec
#     Contents: Read&Write + Pull requests: Read&Write sur
#     lenadotgarden/dotfiles UNIQUEMENT, zéro droit admin. Même si ce token
#     fuitait, il ne permet pas de pousser sur main ni de changer les
#     protections de branche.
#
# Ce que ça NE fait PAS (volontairement) : pas de sudo supplémentaire pour
# hermes, pas d'accès à /etc/nixos, pas de push direct sur main. La fusion
# de la PR reste un geste humain (toi, dans GitHub).
############################################################
{ ... }:
{
flake.modules.nixos."hermes-autonomy" = { config, lib, pkgs, ... }:
let
  cloneDir = "/var/lib/hermes/dotfiles";
  allowedPaths = [ "secrets/hermes-managed.yaml" ];
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

        allowed=0
        for p in ${lib.concatStringsSep " " allowedPaths}; do
          if [ "$file" = "$p" ]; then
            allowed=1
          fi
        done
        if [ "$allowed" -ne 1 ]; then
          echo "refusé : $file n'est pas dans l'allowlist (${lib.concatStringsSep ", " allowedPaths})" >&2
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
  ];
};
}
