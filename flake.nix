{
  description = "spike flake";

  inputs = {
    zig2nix.url = "github:Pivok7/zig2nix";
  };

  outputs =
    { zig2nix, self, ... }:
    let
      flake-utils = zig2nix.inputs.flake-utils;
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        # Zig flake helper
        # Check the flake.nix in zig2nix project for more options:
        # <https://github.com/Cloudef/zig2nix/blob/master/flake.nix>
        env = zig2nix.outputs.zig-env.${system} { zig = zig2nix.outputs.packages.${system}.zig-0_15_2; };
        pkgs = env.pkgs;
      in
      rec {
        packages.default = env.package rec {
          name = "spike";

          src = self;

          nativeBuildInputs = with env.pkgs; [
          ];

          buildInputs = with env.pkgs; [
            libGL
            libxkbcommon
            wayland
          ];

          zigWrapperLibs = buildInputs;

          zigBuildZonLock = ./build.zig.zon2json-lock;

          zigBuildFlags = [ "-Doptimize=Debug" ];
        };

        devShells.default = env.mkShell {
          # Packages required for compiling, linking and running
          # Libraries added here will be automatically added to the LD_LIBRARY_PATH and PKG_CONFIG_PATH
          nativeBuildInputs =
            [ ]
            ++ packages.default.nativeBuildInputs
            ++ packages.default.buildInputs
            ++ packages.default.zigWrapperLibs;
        };
      }
    ));
}
