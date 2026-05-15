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
              mkdir -p $out/nix-support
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

              # Setup hook: sourced automatically by Nix whenever this package
              # is in buildInputs of any mkShell (including devbox-generated ones).
              #
              # pkgs.mkShell activates stdenv.cc — the Nix C compiler wrapper —
              # even when you only asked for a pre-built Swift binary. That wrapper:
              #   1. Exports NIX_CC / NIX_BINTOOLS / NIX_LDFLAGS / … which corrupt
              #      the macOS SDK paths that Apple's Swift driver discovers on its own.
              #   2. Prepends clang-wrapper and cctools-binutils bin dirs to PATH,
              #      shadowing /usr/bin/ld with a Nix wrapper that can't find libc++.tbd.
              #   3. Leaves swiftlint unable to dlopen sourcekitdInProc.framework
              #      because DYLD_FRAMEWORK_PATH is not set.
              # All three are undone here so consumers get a clean environment
              # without any workarounds in their own shell config.
              cat > $out/nix-support/setup-hook <<'EOF'
              # 1. Undo Nix CC wrapper environment variables.
              unset NIX_CC NIX_CC_WRAPPER_TARGET_HOST_aarch64_apple_darwin
              unset NIX_BINTOOLS NIX_BINTOOLS_WRAPPER_TARGET_HOST_aarch64_apple_darwin
              unset NIX_CFLAGS_COMPILE NIX_LDFLAGS NIX_HARDENING_ENABLE
              unset NIX_ENFORCE_NO_NATIVE NIX_DONT_SET_RPATH NIX_IGNORE_LD_THROUGH_GCC

              # 2. Remove Nix CC wrapper bin dirs so /usr/bin/ld is used for linking.
              PATH=$(echo "$PATH" | tr ':' '\n' | grep -Ev 'clang-wrapper|cctools-binutils' | tr '\n' ':' | sed 's/:$//')
              export PATH

              # 3. Expose SourceKit framework so swiftlint can dlopen it at runtime.
              if command -v xcode-select >/dev/null 2>&1; then
                export DYLD_FRAMEWORK_PATH="$(xcode-select -p)/usr/lib''${DYLD_FRAMEWORK_PATH:+:''${DYLD_FRAMEWORK_PATH}}"
              fi
              EOF
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
