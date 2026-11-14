{ config, pkgs, inputs, ... }:

{
  imports = [
    ./neovim
    ./kitty
    ./zsh
    ./git
    ./tmux
    ./tmux/macos.nix
    ./ghostty
  ];

  home.username = "alex";
  home.homeDirectory = "/Users/alex";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Sans ça, fontconfig n'a aucune config du tout sur macOS (contrairement à
  # Linux dans home/default.nix) : lilypond ne trouve alors aucune police de
  # texte et dessine titres/paroles/markup avec la police de notation
  # musicale, qui n'a pas ces glyphes → texte invisible dans le PDF.
  fonts.fontconfig.enable = true;

  # FONTCONFIG_FILE explicite : le binaire lilypond issu de nixpkgs ne trouve
  # pas de fichier de config par défaut sur macOS ("Cannot load default
  # config file"), donc ~/.config/fontconfig seul (généré ci-dessus) ne suffit
  # pas à le faire fonctionner — il faut lui pointer un fonts.conf complet qui
  # liste les polices macOS + la police de secours DejaVu.
  home.sessionVariables.FONTCONFIG_FILE = toString (pkgs.makeFontsConf {
    fontDirectories = [
      pkgs.dejavu_fonts
      "/System/Library/Fonts"
      "/Library/Fonts"
    ];
  });

  # On ne peut pas importer systemd.user.services sur macOS
  # Donc on se contente des CLI tools
  home.packages = with pkgs; [
    fastfetch
    jq
    btop
    dejavu_fonts # police de secours réclamée par la config fontconfig de lilypond
  ];
}
