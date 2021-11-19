NOTE: if you need table of contents in github, hit a button "=" in the left upper corner of the region, where this file is being displayed.

# Brief

This document describes deployment procedure of Op-energy toy exchange.

Currently, we only provide support for deployment to DigitalOcean using terraform.

There is a manual installation procedure, described at https://github.com/dambaev/mempool-overlay/blob/services-based-build/README.md, which walks you step-by-step in a procedure of getting NixOS on DigitalOcean and deploying op-energy toy exchange.

## Preparations

Scripts expect to use DigitalOcean API token to perform a deploy. If you don't have any:
1 navigate to https://cloud.digitalocean.com/account/api/tokens;
2 hit 'Generate New Token';
3 enter token's name, ensure, that 'write' access is selected and hit 'Generate Token';
4 copy-patse token into some file so it can be reused later for scripts. In this tutorial, this file will be located at<repo>/nix/DO_TOKEN. This path is excluded from git tracking, so you can keep it there as well.

## Development

Development of op-energy toy exchange is supposed to consist of those steps:

1 fork the repo, checkout branch op-energy-master and create new branch with your new feature:

```
git clone https://github.com/<your account here>/op-energy
git checkout -b op-energy-new-feature
```

2 commit and push your changes, navigate to <repo>/nix/development and issue:

2.1 install Terraform (on NixOS):

```
nix-shell ../shell.nix
```

2.2 install Terraform (no your OS);

3 perform deploy with script `deploy_dev.sh`. This scripts requires at least DO_TOKEN and any of SSH_KEYS_BY_NAMES or SSH_KEYS_IDS to be set:

```
DO_TOKEN=$(cat ../DO_TOKEN) SSH_KEYS_BY_NAMES="user1@domain1 user2@domaine2" ./deploy_dev.sh
```

In this example, new droplet will allow access to user root for SSH keys "user1@domain1" and "user2@domain2". By default, script will add droplet with name "op-energy-dev" in the "nyc1" DO region. You can run `./deploy_dev.sh` script without any variables set to get the usage reference with other variables that it can be used with.

This script will deploy new small droplet and 2 volumes for signet network. As there will be build process running during deployment, script will take sometime. It will report progress.
At the end, script will show you an IP address of the new droplet to which you will be able to connect either with SSH or with browser.

4 ssh into new droplet and switch op-energy repo to your branch:

```
ssh -A root@<dropletIP>
cd /etc/nixos
git pull && git submodule update --remote
git checkout -b op-energy-new-feature # set parent repo into a new branch, which will not be pushed into repo and exist only to keep op-energy overlay with non-standard branch
git submodule set-branch -b op-energy-new-feature overlays/op-energy # now switch to new branch
git commit overlays/op-energy -m "overlays/op-energy: switch to op-energy-new-feature"
```

5 rebuild config with your new branch:

```
nixos-rebuild switch
```

6 test your changes by navigating with your browser to http://dropletIP/signet

7 when you will be ready, create pull request to merge your changes into op-energy-master branch. After the merge, production instances will switch to the new version.

Development instances will perform periodical fetching of configurations from git repo and will try to apply them. So `nixos-rebuild switch` happen automatically within 10 minutes period.

## Production deployment

In order to get a production setup of op-energy toy exchange, you need to:

1 clone the repo, checkout branch op-energy-master 

```
git clone --branch op-energy-master https://github.com/dambaev/op-energy.git
```

2.1 install Terraform (on NixOS):

```
nix-shell ../shell.nix
```

2.2 install Terraform (no your OS);

3 navigate to op-energy/nix/production and perform deploy with script `deploy.sh`. This scripts requires at least DO_TOKEN and any of SSH_KEYS_BY_NAMES or SSH_KEYS_IDS to be set:

```
DO_TOKEN=$(cat ../DO_TOKEN) SSH_KEYS_BY_NAMES="user1@domain1 user2@domaine2" ./deploy.sh
```

In this example, new droplet will allow access to user root for SSH keys "user1@domain1" and "user2@domain2". By default, script will add droplet with name "op-energy" in the "nyc1" DO region. You can run `./deploy.sh` script without any variables set to get the usage reference with other variables that it can be used with.

This script will deploy new 4 vCPU and 8GB of RAM droplet and 2 volumes for mainnet network. As there will be build process running during deployment, script will take sometime. It will report progress.
At the end, script will show you an IP address of the new droplet to which you will be able to connect either with SSH or with browser.

After the initial deployment, bitcoind and electrs will need time to fetch blockchain and compute it's index. 

Production instance will fetch updates from op-energy-master branch periodically and will switch to new commits if there will be any.

You can force update with:

```
ssh -A root@dropletIP
systemctl start nixos-apply & journal -f | grep -E "(nixos-apply|nixos-upgrade|op-energy-backend-build|op-energy-frontend-build)"
```
