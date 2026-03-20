{
  description = "pi-mono";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
    }:
    let
      current = builtins.fromJSON (builtins.readFile ./VERSION.json);
      inherit (current) rev hash;
      inherit (current.projects.coding-agent) npmDepsHash;
      version = nixpkgs.lib.removePrefix "v" rev;

      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          src = pkgs.fetchFromGitHub {
            owner = "badlogic";
            repo = "pi-mono";
            inherit rev hash;
          };

        in
        rec {
          default = coding-agent;
          coding-agent = pkgs.callPackage ./nix/coding-agent.nix {
            inherit src version npmDepsHash;
          };
        }
      );
    };
}
