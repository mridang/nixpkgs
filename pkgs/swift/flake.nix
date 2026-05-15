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

              # Setup hook: sourced automatically by Nix when this package is in
              # buildInputs of any mkShell (including devbox-generated ones).
              #
              # pkgs.mkShell activates stdenv.cc (the Nix CC wrapper) even when only
              # a pre-built Swift binary is requested.  That wrapper:
              #   1. Prepends clang-wrapper and cctools-binutils bin dirs to PATH,
              #      shadowing /usr/bin/ld with a wrapper that can't find libc++.tbd.
              #   2. Registers ccWrapper_addCVars / bintoolsWrapper_addLDVars in
              #      envHostTargetHooks which later set NIX_CFLAGS_COMPILE / NIX_LDFLAGS,
              #      corrupting the macOS SDK paths Swift discovers on its own.
              #   3. Leaves DYLD_FRAMEWORK_PATH unset, preventing swiftlint from
              #      dlopen-ing sourcekitdInProc.framework at startup.
              #
              # Fix: define swiftFixupCCWrapper and append it to envHostTargetHooks.
              # Because this setup hook runs AFTER the CC wrapper's setup hook
              # (buildInputs are processed after nativeBuildInputs), our entry is
              # appended after ccWrapper_addCVars / bintoolsWrapper_addLDVars in the
              # array.  Nix calls array entries in order, so our cleanup fires last
              # and wins — no init_hook in devbox.json required.
              cat > $out/nix-support/setup-hook <<'EOF'
              swiftFixupCCWrapper() {
                # 1. Clear compiler/linker flags set by the CC wrapper's envHostTargetHooks.
                unset NIX_CFLAGS_COMPILE NIX_LDFLAGS NIX_HARDENING_ENABLE
                unset NIX_DONT_SET_RPATH NIX_NO_SELF_RPATH NIX_IGNORE_LD_THROUGH_GCC

                # 2. Teach devbox to filter the CC wrappers from PATH.
                #    devbox removes PATH entries whose prefix matches any buildInputs
                #    store path.  NIX_CC / NIX_BINTOOLS are the store paths of the two
                #    wrapper derivations whose /bin dirs shadow the system linker; adding
                #    them here causes devbox's computeEnv to strip them without an
                #    init_hook.  (Direct PATH mutation via envHostTargetHooks is not
                #    preserved in the nix print-dev-env JSON output because PATH is
                #    reconstructed from packages after all hooks have run.)
                buildInputs="''${buildInputs:+$buildInputs }''${NIX_CC:+$NIX_CC }''${NIX_BINTOOLS:+$NIX_BINTOOLS}"
                export buildInputs

                # 3. Expose SourceKit framework so swiftlint can dlopen it.
                #    Use path probing — not xcode-select — because /usr/bin is absent
                #    from PATH during nix print-dev-env evaluation.
                for _d in \
                  "/Library/Developer/CommandLineTools/usr/lib" \
                  "/Applications/Xcode.app/Contents/Developer/usr/lib"; do
                  if [ -d "$_d/sourcekitdInProc.framework" ]; then
                    export DYLD_FRAMEWORK_PATH="$_d''${DYLD_FRAMEWORK_PATH:+:''${DYLD_FRAMEWORK_PATH}}"
                    break
                  fi
                done
                unset _d
              }

              # Append to envHostTargetHooks so swiftFixupCCWrapper is called
              # AFTER ccWrapper_addCVars and bintoolsWrapper_addLDVars.
              envHostTargetHooks+=(swiftFixupCCWrapper)
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
