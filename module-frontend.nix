{config, pkgs, options, lib, ...}@args:
let
  op-energy-source = ../.;
  op-energy-frontend-nginx-configs-overlay = import ./op-energy-frontend-nginx-configs-overlay.nix; # this overlay contains nginx configs provided by mempool developers, but prepared to be used in nixos
  op-energy-overlay = import ./overlay.nix;

  cfg = config.services.op-energy-frontend;
  frontend_args = {
    testnet_enabled = cfg.testnet_enabled;
    signet_enabled = cfg.signet_enabled;
  };
in
{
  options.services.op-energy-frontend = {
    enable = lib.mkEnableOption "op-energy service";
    testnet_enabled = lib.mkOption {
      type = lib.types.bool;
      example = false;
      default = false;
      description = ''
        If enabled, frontend will have a dropdown list, from which it will be possible to switch to testnet network
      '';
    };
    signet_enabled = lib.mkOption {
      type = lib.types.bool;
      example = false;
      default = false;
      description = ''
        If enabled, frontend will have a dropdown list, from which it will be possible to switch to signet network
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      op-energy-frontend-nginx-configs-overlay # bring nginx-op-energy-configs into the context
      op-energy-overlay # add op-energy-frontend into context
    ];
    environment.systemPackages = with pkgs; [
      op-energy-frontend-nginx-server-config
      op-energy-frontend-nginx-events-config
      op-energy-frontend-nginx-append-config
      op-energy-frontend-nginx-common-config
      op-energy-frontend-nginx-config
      (op-energy-frontend frontend_args)
    ];
    services.nginx =
      let
        testnet_locations =
          if cfg.testnet_enabled
          then ''
            location = /testnet/api {
              try_files $uri $uri/ /en-US/index.html =404;
            }
            location = /testnet/api/ {
              try_files $uri $uri/ /en-US/index.html =404;
            }
            # testnet API
            location /testnet/api/v1/ws {
              proxy_pass http://127.0.0.1:8997/;
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
            }
            location /testnet/api/v1 {
              proxy_pass http://127.0.0.1:8997/api/v1;
            }
            location /testnet/api/ {
              proxy_pass http://127.0.0.1:60001/;
            }
          ''
        else ''
        '';
        signet_locations =
          if cfg.signet_enabled
          then ''
            location = /signet/api {
              try_files $uri $uri/ /en-US/index.html =404;
            }
            location = /signet/api/ {
              try_files $uri $uri/ /en-US/index.html =404;
            }
            # signet API
            location /signet/api/v1/ws {
              proxy_pass http://127.0.0.1:8995/;
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
            }
            location /signet/api/v1 {
              proxy_pass http://127.0.0.1:8995/api/v1;
            }
            location /signet/api/ {
              proxy_pass http://127.0.0.1:60601/;
            }
          ''
        else ''
        '';
      in {
      enable = true;
      appendConfig = "include ${pkgs.op-energy-frontend-nginx-append-config}/nginx.conf;";
      eventsConfig = "include ${pkgs.op-energy-frontend-nginx-events-config}/nginx.conf;";
      serverTokens =
        let
          server_tokens_str = builtins.readFile "${pkgs.op-energy-frontend-nginx-config}/server_tokens.txt";
        in
        if server_tokens_str == "on" then true else false;
      clientMaxBodySize = builtins.readFile "${pkgs.op-energy-frontend-nginx-config}/client_max_body_size.txt";
      commonHttpConfig = "include ${pkgs.op-energy-frontend-nginx-common-config}/nginx.conf;";
      virtualHosts.op-energy = {
        root = "${pkgs.op-energy-frontend frontend_args}";
        extraConfig = ''
          # include the nginx config, which had been adopted to fit nixos-based nginx config
          include ${pkgs.op-energy-frontend-nginx-server-config}/nginx.conf;
          # here we include possible options to route testnet-related requests.
          ${testnet_locations}
          # here we include possible options to route signet-related requests.
          ${signet_locations}
        '';
      };
    };
  };
}