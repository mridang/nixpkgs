{
  description = "Extra Nix packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  # 'self' is not used, so omit it
  outputs = {
    nixpkgs,
    nixpkgs-unstable,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in {
    packages = nixpkgs.lib.genAttrs systems (
      system: let
        pkgs = import nixpkgs {inherit system;};
        unstable = import nixpkgs-unstable {inherit system;};
      in rec {
        protoc-gen-connect-openapi = pkgs.callPackage ./pkgs/buf/protoc-gen-connect-openapi {
          inherit (unstable) buildGoModule go_1_24;
        };

        qodana = pkgs.callPackage ./pkgs/qodana {};

        default = protoc-gen-connect-openapi;
      }
    );

    # keep a single overlay; underscore unused 'final'
    overlays.default = _final: prev: let
      unstable = import nixpkgs-unstable {inherit (prev.stdenv) system;};
    in {
      protoc-gen-connect-openapi = (import ./pkgs/buf/protoc-gen-connect-openapi) {
        inherit (prev) lib fetchFromGitHub;
        inherit (unstable) buildGoModule go_1_24;
      };

      qodana = prev.callPackage ./pkgs/qodana {};
    };
  };
}
