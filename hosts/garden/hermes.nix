{ ... }:
{
  ############################################################
  # Hermes — réglages propres à l'hôte garden. Les modules `hermes-*`
  # eux-mêmes (dendritic, cf modules/hermes/) sont importés depuis
  # flake.nix (nixosConfigurations.garden.modules), pas ici.
  ############################################################

  # Le seul chat_id Telegram autorisé à parler à Hermes (toi). Pas un
  # secret — remplace 0 par ton vrai chat_id (demande à @userinfobot sur
  # Telegram, ou dis-le moi et je le mets).
  hermes.telegramAllowedChatId = 5077790394;
}
