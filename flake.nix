{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {

          buildInputs = with pkgs; [ godot ];

          shellHook = "";

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs;
            [
              # Add libraries here
            ]);

        };
      });
}
