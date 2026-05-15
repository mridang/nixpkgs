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
              # Create bin/ as a real directory.  swift and swiftc get thin
              # wrapper scripts that remove the Nix CC-wrapper bin dirs from PATH
              # before exec-ing the real binary.  This prevents the Nix ld wrapper
              # (which cannot locate libc++.tbd in the macOS SDK) from being used
              # when swiftc links test executables — without requiring an init_hook
              # in devbox.json.  exec uses the absolute store path so that SPM's
              # libPackageDescription relative-path lookup
              #   <swift-binary-dir>/../lib/swift/pm/ManifestAPI/libPackageDescription.dylib
              # resolves to $out/lib → $out/usr/lib/… correctly (argv[0] is the
              # real store path, not the wrapper).
              mkdir -p $out/bin
              # Every usr/bin entry gets a thin wrapper — not just swift/swiftc.
              # Tools like swift-package, swift-driver, swift-build, swift-test,
              # and swift-run can all drive a link step when called directly, so
              # they all need the Nix clang/cctools stripped from PATH.
              # .cfg files (musl cross-compilation stubs) are not executables;
              # skip them so we don't accidentally wrap a text file.
              for f in "$out/usr/bin/"*; do
                b="$(basename "$f")"
                case "$b" in *.cfg) continue;; esac
                cat > "$out/bin/$b" << 'SWIFTWRAP'
#!/bin/sh
export PATH=$(echo "$PATH" | tr ':' '\n' | grep -Ev '/nix/store/[a-z0-9]+-clang[- /]|/nix/store/[a-z0-9]+-cctools-binutils' | tr '\n' ':' | sed 's/:$//')
unset NIX_CFLAGS_COMPILE NIX_LDFLAGS NIX_HARDENING_ENABLE
SWIFTWRAP
                echo "exec $out/usr/bin/$b \"\$@\"" >> "$out/bin/$b"
                chmod +x "$out/bin/$b"
              done
              ln -sfn $out/usr/lib $out/lib

              # Setup hook: sourced automatically by Nix when this package is in
              # buildInputs of any mkShell (including devbox-generated ones).
              # Clears the CC-wrapper env vars that corrupt Swift SDK detection,
              # and sets DYLD_FRAMEWORK_PATH so swiftlint can dlopen SourceKit.
              # NOTE: heredoc content must start at column 0 — the SWIFTWRAP content
              # above forces Nix to strip 0 spaces, so the EOF terminator must also
              # be at column 0 or it won't be recognised as the heredoc delimiter.
              cat > $out/nix-support/setup-hook <<'EOF'
swiftFixupCCWrapper() {
  # Clear compiler/linker flags injected by the CC wrapper's
  # envHostTargetHooks (ccWrapper_addCVars, bintoolsWrapper_addLDVars).
  unset NIX_CFLAGS_COMPILE NIX_LDFLAGS NIX_HARDENING_ENABLE
  unset NIX_DONT_SET_RPATH NIX_NO_SELF_RPATH NIX_IGNORE_LD_THROUGH_GCC

  # Expose SourceKit so swiftlint can dlopen sourcekitdInProc.
  # Probe the filesystem — not xcode-select — because /usr/bin is
  # absent from PATH during nix print-dev-env evaluation.
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
# Append AFTER ccWrapper_addCVars / bintoolsWrapper_addLDVars so our cleanup fires last.
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
