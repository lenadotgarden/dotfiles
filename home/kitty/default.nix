{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "Iosevka";
      package = pkgs.iosevka-bin;
      size = 13;
    };
    settings = {
      enable_audio_bell = false;
      confirm_os_window_close = 0;
      window_padding_width = 14;
      background_opacity = "0.94";
      dynamic_background_opacity = true;

      # Curseur & Style
      cursor_shape = "beam";
      cursor_blink_interval = 0.5;
      hide_window_decorations = "yes";

      # Fort Contraste Garantie (Fond Sombre + Texte Blanc Pur)
      foreground = "#ffffff";
      background = "#11111b";
      selection_foreground = "#11111b";
      selection_background = "#89b4fa";

      color0 = "#45475a";
      color8 = "#585b70";
      color1 = "#f38ba8";
      color9 = "#f38ba8";
      color2 = "#a6e3a1";
      color10 = "#a6e3a1";
      color3 = "#f9e2af";
      color11 = "#f9e2af";
      color4 = "#89b4fa";
      color12 = "#89b4fa";
      color5 = "#f5c2e7";
      color13 = "#f5c2e7";
      color6 = "#94e2d5";
      color14 = "#94e2d5";
      color7 = "#bac2de";
      color15 = "#a6adc8";
    };
    keybindings = {
    #   "super+c" = "copy_to_clipboard";
    #   "super+v" = "paste_from_clipboard";
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
    };
    extraConfig = ''
      include ~/.cache/wal/colors-kitty.conf
    '';
  };
}
