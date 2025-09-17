# nixpkgs - Extra Nix Packages Collection

A curated collection of Nix packages that don't exist in the official nixpkgs
repository or other package collections. This repository provides additional
packages organized under specialized namespaces for easy discovery and use.

This collection focuses on filling gaps in the Nix ecosystem by packaging
useful tools and utilities that haven't made it into the main nixpkgs tree.
Each package is carefully maintained with proper metadata, licensing information,
and platform support to ensure seamless integration with your Nix workflows.

## Why?

The official nixpkgs repository is comprehensive but can't include every useful
package due to maintenance overhead, licensing concerns, or simply because
packages haven't been submitted yet. This creates gaps where developers need
specific tools that aren't readily available through standard Nix channels.

Without a collection like this, developers typically face several challenges:

- **Manual Packaging:** Building custom derivations for missing packages
  adds complexity and maintenance burden to individual projects.
- **Duplicate Efforts:** Multiple teams often end up packaging the same
  tools independently, leading to wasted effort and inconsistent approaches.
- **Version Lag:** Even when packages exist elsewhere, they may not be
  updated frequently or may lack proper Nix integration.
- **Discovery Issues:** Useful packages scattered across different repositories
  are hard to find and evaluate for production use.

This repository provides a centralized, well-maintained collection that ensures
packages are properly integrated with the Nix ecosystem, regularly updated,
and follow consistent packaging standards.

## Usage

To discover available packages in this repository:

```bash
# List all available packages
nix flake show github:mridang/nixpkgs

# Or explore packages by namespace
nix eval github:mridang/nixpkgs#packages.x86_64-linux --apply builtins.attrNames
```

You can use these packages in several ways depending on your needs:

### Using Flakes (Recommended)

Add this repository as an input to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    extra-packages.url = "github:mridang/nixpkgs";
  };

  outputs = { nixpkgs, extra-packages, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          extra-packages.packages.${system}.package-name
          # or use the namespaced version:
          # extra-packages.packages.${system}.namespace.package-name
        ];
      };
    };
}
```

### Using the Overlay

Apply the overlay to your nixpkgs instance:

```nix
let
  extra-packages = builtins.fetchGit {
    url = "https://github.com/mridang/nixpkgs";
    ref = "main";
  };
  pkgs = import <nixpkgs> {
    overlays = [ (import "${extra-packages}/flake.nix").overlays.default ];
  };
in
  pkgs.package-name
```

### Direct Import

For quick testing or one-off usage:

```nix
let
  extra-packages = builtins.fetchGit {
    url = "https://github.com/mridang/nixpkgs";
    ref = "main";
  };
  packages = import "${extra-packages}/flake.nix";
in
  packages.packages.x86_64-linux.package-name
```

### Running Packages Directly

```bash
# Run a package without installing
nix run github:mridang/nixpkgs#package-name

# Enter a development shell with packages available
nix develop github:mridang/nixpkgs
```



## Contributing

If you have suggestions for how this collection could be improved, or
want to report a bug, open an issue — we'd love all and any
contributions.

## Known Issues

- None currently reported.

## Useful Links

- **[Nix Package Manager](https://nixos.org/):** The purely functional package manager
- **[nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/):** Official packaging guidelines
- **[Nix Flakes](https://nixos.wiki/wiki/Flakes):** Modern Nix workflow documentation

## License

Apache License 2.0 © 2024 Mridang Agarwalla
