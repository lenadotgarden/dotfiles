{ ... }:
{
  ############################################################
  # hermes-users — séparation de privilèges stricte :
  #   - `hermes` (existant, uid 10000) = le cerveau (opencode). Jamais de
  #     sudo, jamais dans wheel/docker. Son bash tool ne peut toucher que
  #     son propre home + /opt/vault.
  #   - `hermes-ctl` (nouveau) = le "bureau du superviseur" : seul compte
  #     qui a le droit (sudoers étroit, voir hermes-trust.nix) de relancer
  #     des services ou de changer le niveau de confiance. hermes ne lui
  #     parle que via une boîte aux lettres fichiers (voir hermes-ctl.nix),
  #     jamais via sudo direct — donc même un hermes compromis/mal guidé
  #     ne peut pas s'auto-promouvoir ni exécuter de commande privilégiée.
  ############################################################
  flake.modules.nixos."hermes-users" = { config, lib, pkgs, ... }: {
    # uid 10001 est déjà pris par `nextcloud` (ajouté après coup) : collision
    # UID réelle détectée en prod (id hermes-ctl affichait "nextcloud") — 10002
    # est libre, vérifié contre `getent passwd`.
    users.groups.hermes-ctl.gid = 10002;
    users.users.hermes-ctl = {
      uid = 10002;
      group = "hermes-ctl";
      extraGroups = [ "hermes" "systemd-journal" ];
      isSystemUser = true;
      description = "Hermes — plan de contrôle (bridge Telegram, actions privilégiées)";
      home = "/var/lib/hermes-ctl";
      createHome = true;
    };

    # hermes lit le journal (status en lecture seule, pas docker/wheel)
    users.users.hermes.extraGroups = [ "systemd-journal" ];
    users.users.hermes.home = lib.mkForce "/opt/vault";
    users.users.hermes.createHome = lib.mkForce false;
  };
}
