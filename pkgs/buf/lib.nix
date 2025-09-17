{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
# pass `go` in the argset below
{
  owner,
  repo,
  version,
  go, # <- REQUIRED: e.g., pkgsUnstable.go_1_24
  subPackages ? ["."],
  ldflags ? ["-s" "-w"],
  cgoEnabled ? "0",
  doCheck ? false,
}:
buildGoModule {
  pname = repo;
  inherit version subPackages ldflags doCheck;

  # source tarball for the tag (build from source, not releases)
  src = fetchFromGitHub {
    inherit owner repo;
    rev = version;
    hash = "sha256-7+8+DpObBxJZihy0kHOReDIlfZGRMQy6yUkGh864pJk="; # you filled this already
  };

  # will fail once and print the real value; paste it here
  vendorHash = "sha256-ubcJP5q70F4mTqx+f8V+lCfjiGHxOvdPVaUwhVLmhb8=";

  # ensure Go 1.24 is used
  go = go;
  env.CGO_ENABLED = cgoEnabled;

  meta = with lib; {
    description = "Buf plugin ${repo}";
    homepage = "https://github.com/${owner}/${repo}";
    license = licenses.mit;
    mainProgram = repo;
    platforms = platforms.unix ++ platforms.darwin;
  };
}
