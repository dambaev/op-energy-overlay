self: super:
let
  op-energy-frontend-nginx-configs = self.callPackage ./op-energy-frontend-nginx-configs.nix {};
in
{
  op-energy-frontend-nginx-common-config = op-energy-frontend-nginx-configs.op-energy-frontend-nginx-common-config;
  op-energy-frontend-nginx-append-config = op-energy-frontend-nginx-configs.op-energy-frontend-nginx-append-config;
  op-energy-frontend-nginx-events-config = op-energy-frontend-nginx-configs.op-energy-frontend-nginx-events-config;
  op-energy-frontend-nginx-server-config = op-energy-frontend-nginx-configs.op-energy-frontend-nginx-server-config;
  op-energy-frontend-nginx-config = op-energy-frontend-nginx-configs.op-energy-frontend-nginx-config;
}

