{ config, ... }:

{
  # Profil iTerm2 "Catppuccin" : couleurs Mocha (sombre) / Latte (clair),
  # basculement automatique avec l'apparence du Mac.
  # Géré via un Dynamic Profile (rechargé à chaud par iTerm2, pas besoin
  # de relancer l'app). Après la première application, il faut le
  # sélectionner une fois comme profil par défaut :
  #   iTerm2 > Réglages > Profiles > Catppuccin > Other Actions... > Set as Default
  home.file."Library/Application Support/iTerm2/DynamicProfiles/catppuccin.json".source =
    ./catppuccin.json;
}
