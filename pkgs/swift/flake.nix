{
  description = "Swift 6.2 toolchain (pre-built binaries)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in {
      packages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs   = import nixpkgs { inherit system; };
          lib    = pkgs.lib;
          stdenv = pkgs.stdenv;

          version = "6.2-RELEASE";

          src = {
            x86_64-linux = pkgs.fetchurl {
              url  = "https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04.tar.gz";
              hash = "sha256-jj1jozccqtSV5pRBS5uaIsX2jGRzB3QGxylkcqQbwHc=";
            };
            aarch64-linux = pkgs.fetchurl {
              url  = "https://download.swift.org/swift-6.2-release/ubuntu2404-aarch64/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04-aarch64.tar.gz";
              hash = "sha256-+7SKae5rOborIyxVu0xCRX5reBi0t62nbLZXwisLe6g=";
            };
            aarch64-darwin = pkgs.fetchurl {
              url  = "https://download.swift.org/swift-6.2-release/xcode/swift-6.2-RELEASE/swift-6.2-RELEASE-osx.pkg";
              hash = "sha256-nqxKE1AMem3t/ZCBT9McF68u/DgVATe1a3C/X0Sy1ks=";
            };
            x86_64-darwin = pkgs.fetchurl {
              url  = "https://download.swift.org/swift-6.2-release/xcode/swift-6.2-RELEASE/swift-6.2-RELEASE-osx.pkg";
              hash = "sha256-nqxKE1AMem3t/ZCBT9McF68u/DgVATe1a3C/X0Sy1ks=";
            };
          }.${system} or (throw "Unsupported system: ${system}");

          swift = stdenv.mkDerivation {
            inherit src version;
            pname = "swift";

            nativeBuildInputs = lib.optionals stdenv.isLinux  [ pkgs.patchelf ]
                             ++ lib.optionals stdenv.isDarwin [ pkgs.xar pkgs.cpio ];

            phases = [ "unpackPhase" "installPhase" "checkPhase" ];

            unpackPhase = lib.optionalString stdenv.isDarwin ''
              xar -xf $src
              zcat < swift-${version}-osx-package.pkg/Payload | cpio -i
              find . -name '._*' -delete
            '';

            installPhase = ''
              cp -R . $out
            '' + lib.optionalString stdenv.isLinux ''
              rpath=$out/usr/lib
              rpath=$rpath:$out/usr/lib/swift/host
              rpath=$rpath:$out/usr/lib/swift/host/compiler
              rpath=$rpath:$out/usr/lib/swift/linux
              rpath=$rpath:${pkgs.stdenv.cc.cc.lib}/lib
              rpath=$rpath:${pkgs.sqlite.out}/lib
              rpath=$rpath:${pkgs.ncurses}/lib
              rpath=$rpath:${pkgs.libuuid.lib}/lib
              rpath=$rpath:${pkgs.zlib}/lib
              rpath=$rpath:${pkgs.curl.out}/lib
              rpath=$rpath:${pkgs.libxml2.out}/lib
              rpath=$rpath:${pkgs.libedit}/lib

              interp=$(cat $NIX_CC/nix-support/dynamic-linker)
              # Guard against non-ELF files (e.g. shell scripts): patchelf exits
              # non-zero on them and set -e would abort the build.
              find $out/usr/bin -type f -perm -0100 | while IFS= read -r f; do
                patchelf --print-interpreter "$f" &>/dev/null || continue
                patchelf --interpreter "$interp" --set-rpath "$rpath" "$f"
              done
              find $out/usr/lib -name "*.so" \
                -exec patchelf --set-rpath "$rpath" --force-rpath {} \;

              for b in swift swiftc; do
                ln -s $out/usr/bin/$b $out/bin/$b
              done
            '' + lib.optionalString stdenv.isDarwin ''
              # Expose usr/bin and usr/lib directly as bin and lib so that SPM
              # can locate libPackageDescription via the expected relative path:
              #   <swift-binary-dir>/../lib/swift/pm/ManifestAPI/libPackageDescription.dylib
              # When swift lives in $out/usr/bin, that resolves to $out/usr/lib/... which
              # exists.  A separate $out/bin wrapper breaks this lookup and causes SPM to
              # add -Xlinker -rpath flags that swift-frontend rejects.
              ln -sfn $out/usr/bin $out/bin
              ln -sfn $out/usr/lib $out/lib
            '';

            # Running swift --version inside the Nix macOS sandbox hangs
            # (SDK detection syscalls are blocked). Just verify the binaries exist.
            checkPhase = ''
              test -x $out/bin/swift  || (echo "swift binary missing"; exit 1)
              test -x $out/bin/swiftc || (echo "swiftc binary missing"; exit 1)
            '';

            meta = with lib; {
              description = "Swift ${version} programming language toolchain";
              homepage    = "https://swift.org";
              license     = licenses.asl20;
              platforms   = systems;
              mainProgram = "swift";
              sourceProvenance = [ sourceTypes.binaryNativeCode ];
            };
          };

        in { inherit swift; default = swift; }
      );
    };
}
