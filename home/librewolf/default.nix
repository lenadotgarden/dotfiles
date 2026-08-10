{ config, pkgs, ... }:

{
  programs.librewolf = {
    enable = true;
    profiles.default = {
      userChrome = ''
        /* 1. Police Iosevka sur la barre d'URL / Omnibox */
        #urlbar-input, #urlbar, .urlbar-input {
          font-family: "Iosevka", monospace !important;
        }

        /* 2. Masquer la barre de menu classique (File, Edit...) */
        #toolbar-menubar {
          display: none !important;
        }

        /* 3. Masquage de l'en-tête (barre d'onglets + barre d'URL) */
        #navigator-toolbox {
          position: fixed !important;
          top: 0;
          left: 0;
          right: 0;
          z-index: 1000 !important;
          margin-top: -95px !important;
          transition: none !important;
          opacity: 0 !important;
          pointer-events: none !important;
          background-color: var(--lwt-accent-color, var(--toolbar-bgcolor, -moz-dialog)) !important;
          box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4) !important;
        }

        /* Fond opaque avec la couleur du thème */
        #titlebar,
        #TabsToolbar,
        #nav-bar {
          background-color: inherit !important;
        }

        /* Désactiver complètement le "Megabar breakout" pour éviter qu'elle prenne 100% de la largeur */
        #urlbar[breakout][breakout-extend] {
          position: static !important;
          margin: 0 !important;
          padding: 0 !important;
          margin-left: 0 !important;
          margin-right: 0 !important;
          padding: 0 !important;
        }

        #urlbar[breakout][breakout-extend] > #urlbar-background {
          animation: none !important;
          box-shadow: none !important;
        }

        #urlbar[breakout][breakout-extend] > #urlbar-input-container {
          padding: 0 !important;
        }

        /* 4. Révéler l'en-tête (onglets + nav-bar) quand le focus est à l'intérieur */
        #navigator-toolbox:focus-within,
        #navigator-toolbox:has(#urlbar[focused="true"]) {
          margin-top: 0 !important;
          opacity: 1 !important;
          pointer-events: auto !important;
        }
      '';
      settings = {
        # Déverrouiller la personnalisation du style CSS
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        # Masquer la barre de menu et de titre
        "browser.menubar.visible" = false;
        "ui.key.menuAccessKeyFocuses" = false;
        "browser.tabs.inTitlebar" = 1;
        # Sécurité et sauvegardes LibreWolf
        "privacy.resistFingerprinting" = true;
        "browser.startup.page" = 3; # Restaurer la session précédente
        "identity.fxaccounts.enabled" = false;
      };
    };
  };
}
