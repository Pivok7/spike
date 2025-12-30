{
  description = "SDL3 project flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        _nativeBuildInputs = with pkgs; [
          zig_0_15
        ];

        _buildInputs = with pkgs; [
          libGL
          libxkbcommon
          wayland
        ];
      in
      {
        devShells.default = pkgs.mkShell rec {
          nativeBuildInputs = _nativeBuildInputs;
          buildInputs = _buildInputs;

          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
        };
      }
    );
}
