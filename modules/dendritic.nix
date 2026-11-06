{ lib, ... }:
{
  ############################################################
  # Déclare `flake.modules.<classe>.<nom>` comme une option fusionnable
  # (sinon flake-parts refuse plusieurs définitions du même attribut de
  # sortie) — c'est ce qui permet le pattern dendritic : chaque fichier
  # sous modules/ s'auto-déclare sans toucher à flake.nix.
  ############################################################
  options.flake.modules = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.unspecified);
    default = { };
  };
}
