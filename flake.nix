{
  description = "rookery - the @rookery family of Typst packages for Rheo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            just
            nodejs
            playwright-driver.browsers
            pnpm
            typst
          ];
          # Playwright downloads its own browser binaries by default and those
          # downloads are dynamically linked against libraries NixOS does not
          # provide. Both halves come from nixpkgs instead, from one derivation
          # each, so the driver protocol and the browser builds cannot drift
          # apart the way a pinned npm dependency eventually would.
          # `playwright-driver` IS the playwright-core package — its own
          # package.json declares that name.
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          PLAYWRIGHT_CORE = "${pkgs.playwright-driver}";
        };
      });
}
