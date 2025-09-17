{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go_1_24,
}: let
  mk = import ../lib.nix {inherit lib buildGoModule;};
in
  mk {
    pname = "protoc-gen-connect-openapi";
    version = "v0.21.2";
    go = go_1_24;

    src = fetchFromGitHub {
      owner = "sudorandom";
      repo = "protoc-gen-connect-openapi";
      rev = "v0.21.2";
      hash = "sha256-7+8+DpObBxJZihy0kHOReDIlfZGRMQy6yUkGh864pJk=";
    };

    vendorHash = "sha256-ubcJP5q70F4mTqx+f8V+lCfjiGHxOvdPVaUwhVLmhb8=";
  }
