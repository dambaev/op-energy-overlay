{config, pkgs, options, lib, ...}@args:
let
  op-energy-source = ../.;
  op-energy-overlay = import ./overlay.nix;
  initial_script = cfg:
    pkgs.writeText "initial_script.sql" ''
    CREATE USER IF NOT EXISTS ${cfg.db_user}@localhost IDENTIFIED BY '${cfg.db_psk}';
    ALTER USER ${cfg.db_user}@localhost IDENTIFIED BY '${cfg.db_psk}';
    flush privileges;
  '';

  eachInstance = config.services.op-energy-backend;
  instanceOpts = args: {
    options = {
      db_name = lib.mkOption {
        default = null;
        type = lib.types.str;
        example = "mempool";
        description = "Database name of the instance";
      };
      db_user = lib.mkOption {
        default = null;
        type = lib.types.str;
        example = "mempool";
        description = "Username to access instance's database";
      };
      db_psk = lib.mkOption {
        type = lib.types.str;
        default = null;
        example = "your-secret-from-out-of-git-store";
        description = ''
          This value defines a password for database user, which will be used by op-energy backend instance to access database.
        '';
      };
      config = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = ''
          {
            "ELECTRUM": {
              "HOST": "127.0.0.1",
              "PORT": 50002,
              "TLS_ENABLED": true,
            }
          }
        '';
      };
    };
  };
in
{
  options.services.op-energy-backend = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule instanceOpts);
    default = {};
    description = "One or more op-energy-backends";
    example = {
      mainnet = {
        config = ''
          {
            "ELECTRUM": {
              "HOST": "127.0.0.1",
              "PORT": 50002,
              "TLS_ENABLED": true,
            }
        '';
      };
    };
  };

  config = lib.mkIf (eachInstance != {}) {
    nixpkgs.overlays = [
      op-energy-overlay # add op-energy-backend into context
    ];
    environment.systemPackages = [ pkgs.op-energy-backend ];
    # enable mysql and declare op-energy DB
    services.mysql = {
      enable = true;
      package = pkgs.mariadb; # there is no default value for this option, so we define one
      initialDatabases = lib.mapAttrsToList (name: cfg:
        { name = "${cfg.db_name}";
          schema = "${op-energy-source}/mariadb-structure.sql";
        }
      ) eachInstance;
      ensureUsers = lib.mapAttrsToList (name: cfg:
        { name = "${cfg.db_user}";
          ensurePermissions = {
            "${cfg.db_name}.*" = "ALL PRIVILEGES";
          };
        }
      ) eachInstance;
    };
    systemd.services = {
      mysql-op-energy-users = {
        wantedBy = [ "multi-user.target" ];
        after = [
          "mysql.service"
        ];
        requires = [
          "mysql.service"
        ];
        serviceConfig = {
          Type = "simple";
        };
        path = with pkgs; [
          mariadb
        ];
        script = lib.foldl' (acc: i: acc + i) '''' ( lib.mapAttrsToList (name: cfg: ''
          # create database if not exist. we can't use services.mysql.ensureDatabase/initialDatase here the latter
          # will not use schema and the former will only affects the very first start of mariadb service, which is not idemponent
          if [ ! -d "${config.services.mysql.dataDir}/${cfg.db_name}" ]; then
            ( echo 'CREATE DATABASE `${cfg.db_name}`;'
              echo 'use `${cfg.db_name}`;'
              cat "${op-energy-source}/mariadb-structure.sql"
            ) | mysql -uroot
          fi
          cat "${initial_script cfg}" | mysql -uroot
        '') eachInstance);
      };
    } // ( lib.mapAttrs' (name: cfg: lib.nameValuePair "op-energy-backend-${name}" (
      let
        mempool_config = pkgs.writeText "mempool-backend.json" cfg.config; # this renders config and stores in /nix/store
      in {
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-setup.service"
        ];
        requires = [ "network-setup.service" ];
        serviceConfig = {
          Type = "simple";
        };
        path = with pkgs; [
          nodejs
          bashInteractive
        ];
        script = ''
          set -ex
          cd ${pkgs.op-energy-backend}/backend
          npm run start-production -- -c "${mempool_config}"
        '';
      })) eachInstance);
  };
}