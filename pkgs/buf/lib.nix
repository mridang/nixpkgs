{
  lib,
  buildGoModule,
}: {
  pname,
  version,
  src,
  vendorHash,
  go,
  subPackages ? ["."],
  ldflags ? ["-s" "-w"],
  cgoEnabled ? "0",
  doCheck ? false,
}:
buildGoModule {
  inherit pname version src vendorHash subPackages ldflags doCheck go;
  env.CGO_ENABLED = cgoEnabled;

  meta = with lib; {
    description = "Buf plugin ${pname}";
    license = licenses.mit;
    mainProgram = pname;
    platforms = platforms.unix ++ platforms.darwin;
  };
}
