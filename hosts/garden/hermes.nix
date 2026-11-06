{ ... }:
{
  ############################################################
  # Hermes — réglages propres à l'hôte garden. Les modules `hermes-*`
  # eux-mêmes (dendritic, cf modules/hermes/) sont importés depuis
  # flake.nix (nixosConfigurations.garden.modules), pas ici.
  #
  # hermes-agent-legacy (bot Telegram maison) est retiré : le vrai
  # hermes-agent (NousResearch, cf hermes-real-agent.nix) gère Telegram
  # maintenant (TELEGRAM_ALLOWED_USERS dans son env). Rien à régler ici.
  ############################################################
}
