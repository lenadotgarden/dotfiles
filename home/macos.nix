{ config, pkgs, inputs, ... }:

{
  imports = [
    ./neovim
    ./kitty
    ./zsh
    ./git
    ./tmux
    ./tmux/macos.nix
    ./iterm2
  ];

  home.username = "alex";
  home.homeDirectory = "/Users/alex";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;



  # On ne peut pas importer systemd.user.services sur macOS
  # Donc on se contente des CLI tools
  home.packages = with pkgs; [
    fastfetch
    jq
    btop
  ];
}
