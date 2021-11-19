# derivations for node.js-based applications in NixOS are supposed to be generated by node2nix
{ stdenv, pkgs, fetchurl, fetchzip
}:
let
  source = fetchzip {
    url = "https://github.com/dambaev/mempool/archive/bdcb1df0f4f7e156b49839505e8725ae3592e3fe.zip";
    sha256 = "0mvazaldfiwdr0h395ybvb9d10pj9p3y29isnmxqg3lv1fslg6zq";
  };

  backend_derivation =
  let
    nodeDependencies = ( pkgs.callPackage ./backend/op-energy-backend.nix {}).shell.nodeDependencies;
    initial_script = pkgs.writeText "initial_script.sql" ''
      CREATE USER IF NOT EXISTS mempool@localhost IDENTIFIED BY 'mempool';
      ALTER USER mempool@localhost IDENTIFIED BY 'mempool';
      flush privileges;
    '';
  in stdenv.mkDerivation {
    name = "op-energy-backend";

    src = source;
    buildInputs = with pkgs;
    [ nodejs
      python
    ];
    preConfigure = "cd backend";
    buildPhase = ''
      export PATH="${nodeDependencies}/bin:$PATH"
      # if there is no HOME var, then npm will try to write to root dir, for which it has no write permissions to, so we provide HOME var
      export HOME=./home

      # and create this dir as well
      mkdir $HOME

      # copy contents of the node_modules, following symlinks, such that current build/install will be able to modify local copies
      cp -r ${nodeDependencies}/lib/node_modules ./node_modules
      # allow user to write. the build will try to write into ./node_modules/@types/node
      chmod -R u+w ./node_modules
      # we already have populated node_modules dir, so we don't need to run `npm install`
      npm run build
    '';
    installPhase = ''
      mkdir -p $out/backend
      cp -r ./node_modules $out/backend
      cp -r dist $out/backend
      cp package.json $out/backend/ # needed for `npm run start`
      cp ../mariadb-structure.sql $out/backend # this schema will be useful for a module.nix file, which will populate the db from it.
      cp ${initial_script} $out/backend/initial_script.sql # script, which should setup DB user
    '';
    patches = [
      ./start_with_config_argument.patch # this patch adds support for '-c'/'--config' argument, so we can run `npm run start -- -c /path/to/config` later.
    ];
  };
  # frontend_derivation is a function, because it needs 2 variables, which affect the build result.
  frontend_derivation = { testnet_enabled ? false, signet_enabled ? false}:
  let
    # those repos are required for frontend's step which tries to download some assets during build.
    poolsJsonUrl = fetchzip {
      url = "https://github.com/btccom/Blockchain-Known-Pools/archive/349c8d907ad9293661c804684782696dcb48d3b4.zip";
      sha256 = "1sqragdf7wbzmrwqz82j9306v9czj6xxpfg6x8c1zy0a6yhzf2fl";
    };
    assetsJsonUrl = fetchzip {
      url = "https://github.com/mempool/asset_registry_db/archive/689456ad4d653055eb690dca282b9f8faab1e873.zip";
      sha256 = "0lk377a9kdciwj1w6aik3307zmp64i0sc8g26fmqzm4wfn198n8j";
    };

    nodeDependencies = ( pkgs.callPackage ./frontend/op-energy-frontend.nix {}).shell.nodeDependencies;
    testnet_enabled_str =
      if testnet_enabled
      then "true"
      else "false";
    signet_enabled_str =
      if signet_enabled
      then "true"
      else "false";
    # this is a frontend build-time config: basically, we are either enable or disable parts of frontend
    frontend_config = pkgs.writeText "mempool-frontend-config.json" ''
      {
        "TESTNET_ENABLED": ${testnet_enabled_str},
        "SIGNET_ENABLED": ${signet_enabled_str}
      }
    '';
  in
    stdenv.mkDerivation {
    name = "op-energy-frontend";

    src = source;
    buildInputs = with pkgs;
    [ nodejs
      python
      poolsJsonUrl
      assetsJsonUrl
      rsync
    ];
    preConfigure = ''
      cd frontend
      # deploy frontend build config
      cp ${frontend_config} mempool-frontend-config.json
      # deploying predownloaded assets, so install will not attemp to download them
      mkdir -p dist/mempool/browser/en-US/resources/
      mkdir -p src/resources
      cp ${poolsJsonUrl}/pools.json dist/mempool/browser/en-US/resources/
      cp ${assetsJsonUrl}/index.json dist/mempool/browser/en-US/resources/assets.json
      cp ${assetsJsonUrl}/index.minimal.json dist/mempool/browser/en-US/resources/assets.minimal.json
      cp ${poolsJsonUrl}/pools.json src/resources
      cp ${assetsJsonUrl}/index.json src/resources/assets.json
      cp ${assetsJsonUrl}/index.minimal.json src/resources/assets.minimal.json
    '';
    buildPhase = ''
      export PATH="${nodeDependencies}/bin:$PATH"
      # if there is no HOME var, then npm will try to write to root dir, for which it has no write permissions to, so we provide HOME var
      export HOME=./home

      # and create this dir as well
      mkdir $HOME

      # without overriding this env var, build will try to ask for some input.
      export NG_CLI_ANALYTICS=off
      # copy contents of the node_modules, following symlinks, such that current build/install will be able to modify local copies
      cp -r ${nodeDependencies}/lib/node_modules ./node_modules
      # allow user to write
      chmod -R u+w ./node_modules
      # we already have populated node_modules dir, so we don't need to run `npm install`
      npm run build
    '';
    installPhase = ''
      mkdir -p $out
      cp -r dist/mempool/browser/* $out
    '';
    patches = [
      ./sync-assets.patch # support offline build
    ];
  };
in
{ op-energy-backend = backend_derivation;
  op-energy-frontend = frontend_derivation;
}
