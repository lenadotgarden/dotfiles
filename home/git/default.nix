{ pkgs, inputs, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = "lena";
      user.email = "lena@example.com";
      init.defaultBranch = "main";
    };
  };
}
