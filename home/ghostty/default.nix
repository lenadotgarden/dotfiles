{ pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  programs.ghostty = {
    enable = true;
    # Ghostty n'est pas packagé pour aarch64-darwin dans nixpkgs : sur le Mac,
    # l'app (Ghostty.app) s'installe à la main (`brew install --cask ghostty`) et
    # on ne gère que sa config. Sur Linux, c'est le paquet nixpkgs.
    package = if isDarwin then null else pkgs.ghostty;
    enableZshIntegration = true;

    settings = {
      font-family = "Iosevka";
      font-size = 13;

      window-padding-x = 14;
      window-padding-y = 14;

      background-opacity = 1;

      cursor-style = "block";
      cursor-style-blink = true;
      mouse-hide-while-typing = true;

      confirm-close-surface = false;
    }
    // lib.optionalAttrs isDarwin {
      # Catppuccin Mocha (sombre) / Latte (clair), bascule automatique avec
      # l'apparence du Mac - thèmes livrés nativement par Ghostty.
      theme = "dark:Catppuccin Mocha,light:Catppuccin Latte";
      background-opacity = 0.94;
      macos-titlebar-style = "hidden";
      background-blur-radius = 20;
      # false (pas true) : sur clavier français, Option produit les caractères
      # spéciaux ({ [ ] } \ @ etc.) ; en "alt" il sert de modificateur Meta pour
      # le shell/readline mais avale ces caractères avant qu'ils soient produits.
      macos-option-as-alt = false;
    }
    // lib.optionalAttrs (!isDarwin) {
      # Noctalia écrit ~/.config/ghostty/themes/noctalia à chaque changement de
      # palette (template "ghostty") et recharge Ghostty : terminal, zsh (ANSI),
      # btop... suivent le thème du bureau.
      theme = "noctalia";
      window-decoration = "none";
      gtk-titlebar = false;
      gtk-single-instance = true;
    };
  };
}
