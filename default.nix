let
  pkgs = import <nixpkgs> {
    config = {};
    overlays = [
      (import ./overlay.nix)
    ];
  };

in {
  op-energy-backend = pkgs.op-energy-backend;
  op-energy-frontend = pkgs.op-energy-frontend;
}
