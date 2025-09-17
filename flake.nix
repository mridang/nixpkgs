{
  description = "Extra Nix packages with a bufPackages namespace";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in {
      packages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          pkgsUnstable = import nixpkgs-unstable { inherit system; };
        in {
          # Namespace: bufPackages
          bufPackages = {
            protoc-gen-connect-openapi =
              pkgs.callPackage ./pkgs/buf/protoc-gen-connect-openapi {
                # Use the unstable builder so the go-modules step runs with our Go
                buildGoModule = pkgsUnstable.buildGoModule;
                # Toolchain required by go.mod/toolchain (Go 1.24)
                go_1_24 = pkgsUnstable.go_1_24;
              };
          };

          # convenience attrs
          protoc-gen-connect-openapi = self.packages.${system}.bufPackages.protoc-gen-connect-openapi;
          default = self.packages.${system}.bufPackages.protoc-gen-connect-openapi;
        }
      );

      # Optional overlay (kept as-is; can omit if you don't use it)
      overlays.default = final: prev: {
        protoc-gen-connect-openapi =
          (import ./pkgs/buf/protoc-gen-connect-openapi) {
            lib = prev.lib;
            buildGoModule = (import nixpkgs-unstable { system = prev.stdenv.system; }).buildGoModule;
            fetchFromGitHub = prev.fetchFromGitHub;
            go_1_24 = (import nixpkgs-unstable { system = prev.stdenv.system; }).go_1_24;
          };
      };
    };
}
