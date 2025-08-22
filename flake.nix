{
  nixConfig = {
    extra-substituters = "https://neorocks.cachix.org";
    extra-trusted-public-keys = "neorocks.cachix.org-1:WqMESxmVTOJX7qoBC54TwrMMoVI1xAM+7yFin8NRfwk=";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    neorocks.url = "github:nvim-neorocks/neorocks";
  };
  outputs = {
    self,
    nixpkgs,
    neorocks,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        neorocks.overlays.default
      ];
    };
  in {
    # ...
    checks.${system} = {
      neorocks-test = pkgs.neorocksTest {
        src = self; # Project containing the rockspec and .busted files.
        # Plugin name. If running multiple tests,
        # you can use pname for the plugin name instead
        name = "nvimmer-ps";
        version = "scm-1"; # Optional, defaults to "scm-1";
        neovim = pkgs.neovim-nightly; # Optional, defaults to neovim-nightly.
        luaPackages = ps:
        # Optional
          with ps; [
            # LuaRocks dependencies must be added here.
            plenary-nvim
          ];
        extraPackages = []; # Optional. External test runtime dependencies.
      };
    };
  };
}
