{ ... }:

{
  # Ghostty n'est pas packagé pour aarch64-darwin dans nixpkgs : l'app
  # (Ghostty.app) doit être installée à la main (site officiel ou
  # `brew install --cask ghostty`). Ici on ne gère que sa config.
  programs.ghostty = {
    enable = true;
    package = null;
    enableZshIntegration = true;

    settings = {
      # Catppuccin Mocha (sombre) / Latte (clair), bascule automatique avec
      # l'apparence du Mac — thèmes livrés nativement par Ghostty.
      theme = "dark:Catppuccin Mocha,light:Catppuccin Latte";

      font-family = "Iosevka";
      font-size = 13;

      window-padding-x = 14;
      window-padding-y = 14;
      macos-titlebar-style = "hidden";

      background-opacity = 0.94;
      background-blur-radius = 20;

      cursor-style = "block";
      cursor-style-blink = true;
      mouse-hide-while-typing = true;

      confirm-close-surface = false;
      # false (pas true) : sur clavier français, Option produit les caractères
      # spéciaux ({ [ ] } \ @ etc.) ; en "alt" il sert de modificateur Meta pour
      # le shell/readline mais avale ces caractères avant qu'ils soient produits.
      macos-option-as-alt = false;
    };
  };
}
