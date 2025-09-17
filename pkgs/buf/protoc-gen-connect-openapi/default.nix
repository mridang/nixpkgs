{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go_1_24,
}: let
  mkBufPlugin = import ../lib.nix {inherit lib buildGoModule fetchFromGitHub;};
in
  mkBufPlugin {
    owner = "sudorandom";
    repo = "protoc-gen-connect-openapi";
    version = "v0.21.2";
    go = go_1_24;
  }
