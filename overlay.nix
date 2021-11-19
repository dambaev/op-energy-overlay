self: super: {
  op-energy-backend = (self.callPackage ./derivation.nix {}).op-energy-backend;
  op-energy-frontend = (self.callPackage ./derivation.nix {}).op-energy-frontend;
}
