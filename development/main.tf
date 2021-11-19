variable "DO_TOKEN" {
  type = string
  validation {
    condition = length( var.DO_TOKEN) > 0
    error_message = "DO_TOKEN should not be empty."
  }
}

provider "digitalocean" {
  token = var.DO_TOKEN
}

variable "DO_REGION" {
  type = string
  validation {
    condition = length( var.DO_REGION) > 0
    error_message = "DO_REGION should not be empty."
  }
}
variable "DROPLET_NAME" {
  type = string
  validation {
    condition = length( var.DROPLET_NAME) > 0
    error_message = "DROPLET_NAME should not be empty."
  }
}
variable "SSH_KEYS_IDS" {
  type = list( string)
}

resource "digitalocean_droplet" "dev_droplet_instance" {
  name   = var.DROPLET_NAME
  size   = "s-1vcpu-2gb"
  image  = "centos-8-x64"
  region = var.DO_REGION
  ssh_keys = var.SSH_KEYS_IDS
  volume_ids = [ ]
  user_data = <<-EOT
    #cloud-config
          write_files:
          - path: /etc/nixos/droplet.nix
            permissions: '0644'
            content: |
              {pkgs, lib, ...}:
              {
                imports = [
                  ./host.nix # this file is part of op-energy-development repo
                ];
                networking.hostName = "${var.DROPLET_NAME}";
                # hardware related part
                # those mount points' options belong to hardware-configuration.nix, but patching it is much harder, than just importing another module
                fileSystems."/" = { device = "/dev/vda1"; options = [ "noatime" "discard"]; };
                swapDevices = [
                  { device = "/tmp/swap";
                    size = 2048;
                  }
                ];
              }
          runcmd:
            - mkdir -p /etc/nixos/
            - dnf install -y git python3
            - git clone --recursive https://github.com/dambaev/op-energy-development.git
            - mv op-energy-development/* /etc/nixos/
            - mv op-energy-development/.git* /etc/nixos/
            - /etc/nixos/overlays/op-energy/nix/gen-psk.sh /etc/nixos/private/ signet
            - dd if=/dev/zero of=/tmp/swap bs=1M count=2048
            - mkswap /tmp/swap
            - swapon /tmp/swap
            - curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | PROVIDER=digitalocean NIXOS_IMPORT=./droplet.nix NIX_CHANNEL=nixos-21.05 bash 2>&1 | tee /tmp/infect.log
  EOT

  count = 1
}