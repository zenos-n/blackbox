{
  description = "Black Box Next — a native GNOME terminal";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          blackbox-next = pkgs.callPackage ./package.nix { };
        in
        {
          inherit blackbox-next;
          default = blackbox-next;
        });

      checks = forAllSystems (system: {
        default = self.packages.${system}.blackbox-next;
      });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          inputsFrom = [ self.packages.${system}.blackbox-next ];
        };
      });
    };
}
