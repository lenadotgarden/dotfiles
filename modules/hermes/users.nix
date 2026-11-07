{ ... }:
{
  ############################################################
  # hermes-users — réglages de l'utilisateur `hermes` existant (uid
  # 10000), qui fait tourner le vrai hermes-agent (NousResearch). Jamais
  # de sudo, jamais dans wheel/docker : hérité de la définition d'origine
  # dans hosts/garden/default.nix, juste étendu ici.
  #
  # (hermes-ctl, le "plan de contrôle" construit pour l'agent custom
  # retiré, est parti avec lui — plus personne ne s'en sert.)
  ############################################################
  flake.modules.nixos."hermes-users" = { config, lib, pkgs, ... }: {
    users.users.hermes.extraGroups = [ "systemd-journal" ];
    users.users.hermes.home = lib.mkForce "/opt/vault";
    users.users.hermes.createHome = lib.mkForce false;
  };
}
