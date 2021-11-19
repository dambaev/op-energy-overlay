let
  pkgs = import
    (builtins.fetchGit {
        name = "nixos-21.05-small-2021-10-30";
        url = "https://github.com/nixos/nixpkgs";
        ref = "refs/heads/nixos-21.05-small";
        rev = "6c0c30146347188ce908838fd2b50c1b7db47c0c";
    })
    { };
  myTerraform = pkgs.terraform_0_15.withPlugins (tp: [ tp.digitalocean ]);
in
pkgs.mkShell {
  buildInputs = with pkgs; [ curl jq myTerraform python3 ];
}
