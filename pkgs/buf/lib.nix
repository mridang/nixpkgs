{ lib, buildGoModule, fetchFromGitHub }:
{ owner, repo, version, subPackages ? [ "." ], ldflags ? [ "-s" "-w" ] }:

buildGoModule {
  pname = repo;
  inherit subPackages ldflags;
  version = version;

  src = fetchFromGitHub {
    inherit owner repo;
    rev = version;
    sha256 = lib.fakeSha256;     # build once; replace with real hash
  };

  vendorHash = lib.fakeSha256;   # build once; replace with real hash

  meta = with lib; {
    description = "Buf plugin ${repo}";
    homepage = "https://github.com/${owner}/${repo}";
    license = licenses.mit or licenses.asl20;
    mainProgram = repo;
    platforms = platforms.unix ++ platforms.darwin;
  };
}
