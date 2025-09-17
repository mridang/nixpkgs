{
  description = "Extra Nix packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  in {
    packages = nixpkgs.lib.genAttrs systems (
      system: let
        pkgs = import nixpkgs {inherit system;};
        pkgsUnstable = import nixpkgs-unstable {inherit system;};
      in {
        protoc-gen-connect-openapi = pkgs.callPackage ./pkgs/buf/protoc-gen-connect-openapi {
          buildGoModule = pkgsUnstable.buildGoModule;
          go_1_24 = pkgsUnstable.go_1_24;
        };

        default = self.packages.${system}.protoc-gen-connect-openapi;
      }
    );

    overlays.default = final: prev: {
      protoc-gen-connect-openapi = (import ./pkgs/buf/protoc-gen-connect-openapi) {
        lib = prev.lib;
        buildGoModule =
          (import nixpkgs-unstable {system = prev.stdenv.system;}).buildGoModule;
        fetchFromGitHub = prev.fetchFromGitHub;
        go_1_24 =
          (import nixpkgs-unstable {system = prev.stdenv.system;}).go_1_24;
      };
    };
  };
}
