{
  description = "Extra Nix packages with a bufPackages namespace";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in {
      packages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          callPackage = pkgs.callPackage;

          # namespace: bufPackages
          bufPackages = {
            protoc-gen-connect-openapi =
              callPackage ./pkgs/buf/protoc-gen-connect-openapi { };
          };

          # optional bundle: all buf plugins on PATH at once
          bufPlugins = pkgs.buildEnv {
            name = "buf-plugins";
            paths = [
              bufPackages.protoc-gen-connect-openapi
            ];
          };
        in
        {
          # expose directly under outputs.packages.${system}.<name>
          bufPackages = bufPackages;
          bufPlugins = bufPlugins;

          # conveniences
          protoc-gen-connect-openapi = bufPackages.protoc-gen-connect-openapi;
          default = bufPackages.protoc-gen-connect-openapi;
        }
      );

      # Optional overlay for non-flake consumers
      overlays.default = final: prev: {
        protoc-gen-connect-openapi =
          prev.callPackage ./pkgs/buf/protoc-gen-connect-openapi { };
      };
    };
}
