_final: prev: {
  protoc-gen-connect-openapi =
    prev.callPackage ../pkgs/buf/protoc-gen-connect-openapi {};

  qodana =
    prev.callPackage ../pkgs/qodana {};
}
