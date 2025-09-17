{ lib, buildGoModule, fetchFromGitHub }:
let mkBufPlugin = import ../lib.nix { inherit lib buildGoModule fetchFromGitHub; };
in mkBufPlugin {
  owner = "sudorandom";
  repo  = "protoc-gen-connect-openapi";
  version = "v0.19.1";  # pick a tag; adjust if you want
}
