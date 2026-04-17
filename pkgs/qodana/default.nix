{
  lib,
  stdenv,
  fetchurl,
}: let
  version = "2025.3.2";

  assets = {
    x86_64-linux = {
      url = "https://github.com/JetBrains/qodana-cli/releases/download/v${version}/qodana_linux_x86_64.tar.gz";
      hash = "sha256-8n4tLLE07akTlF6eGqlfPEOlhDsAKwy58EIZyRG3k5k=";
    };
    aarch64-linux = {
      url = "https://github.com/JetBrains/qodana-cli/releases/download/v${version}/qodana_linux_arm64.tar.gz";
      hash = "sha256-zl3BcgWj91N9OFUkU1hcYokpvMxkX1u6OWGVOlloCqk=";
    };
    x86_64-darwin = {
      url = "https://github.com/JetBrains/qodana-cli/releases/download/v${version}/qodana_darwin_x86_64.tar.gz";
      hash = "sha256-4kgG/BWz/SQVyYJD1V22AjtCX98Gq4/xRc0E+8ljMKM=";
    };
    aarch64-darwin = {
      url = "https://github.com/JetBrains/qodana-cli/releases/download/v${version}/qodana_darwin_arm64.tar.gz";
      hash = "sha256-j30qjTdBRuh/cKRQKSiCo0mJZD2gUh4io+YQTHUrPII=";
    };
  };

  asset =
    assets.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation {
    pname = "qodana";
    inherit version;

    src = fetchurl {
      inherit (asset) url hash;
    };

    sourceRoot = ".";

    dontBuild = true;
    dontConfigure = true;
    dontFixup = stdenv.hostPlatform.isDarwin;

    installPhase = ''
      runHook preInstall
      install -Dm755 qodana $out/bin/qodana
      runHook postInstall
    '';

    meta = with lib; {
      description = "JetBrains Qodana CLI for static code analysis";
      homepage = "https://github.com/JetBrains/qodana-cli";
      license = licenses.asl20;
      mainProgram = "qodana";
      platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
      sourceProvenance = with sourceTypes; [binaryNativeCode];
    };
  }
