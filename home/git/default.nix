{ pkgs, inputs, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = "lena";
      user.email = "lenadotgarden@proton.me";
      init.defaultBranch = "main";
      credential.helper = "store";
    };
  };
}
