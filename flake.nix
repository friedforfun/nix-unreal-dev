{
  description = "Unreal Editor development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};

        config = import ./unreal-versions.nix;
        defaultVersion = config.default;

        # Create a list of attributes excluding the default attirbute.
        versions = builtins.removeAttrs config ["default"];

        mkDevShell = versionName:
          import ./unreal.nix {
            inherit pkgs;
            paramVersion = versionName;
          };
      in {
        devShells = builtins.mapAttrs (_: mkDevShell) versions // {default = mkDevShell defaultVersion;};
      }
    );
}
