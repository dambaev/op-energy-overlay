
set -e # fail on error and echo commands

DEFAULT_DROPLET_NAME="op-energy"
DEFAULT_SSH_KEYS_IDS=""
DEFAULT_DO_REGION="nyc1"

usage(){
    echo "DO_TOKEN=<DO_API_TOKEN_HERE> [DROPLET_NAME=<DROPLET_NAME_HERE>] SSH_KEYS_IDS=<> SSH_KEYS_BY_NAMES=<> [DO_REGION=<>] ./$0
  where
  required variables
    DO_TOKEN - token from DigitalOcean API with write access
    SSH_KEYS_IDS - COMMA-separated list of ssh-keys ids, which should be added to droplet. If you don't have such ids, use SSH_KEYS_BY_NAMES.
    SSH_KEYS_BY_NAMES - SPACE-separated list of user-names, which ssh-keys should be added to droplet
  optional variables:
    DO_REGION - region for droplet. Default is 'nyc1'
    DROPLET_NAME - name of the droplet to use
"
}

if [ "$DO_TOKEN" == "" ]; then
  echo "DO_TOKEN variable is empty"
  usage
  exit 1
fi

if [ "$SSH_KEYS_IDS" == "" ] && [ "$SSH_KEYS_BY_NAMES" == "" ]; then
  echo "SSH_KEYS_IDS and SSH_KEYS_BY_NAMES variables are empty, need at least one of them"
  usage
  exit 1
fi

if [ "$DROPLET_NAME" == "" ]; then
  echo "DROPLET_NAME undefined, using $DEFAULT_DROPLET_NAME"
  DROPLET_NAME=$DEFAULT_DROPLET_NAME
fi

if [ "$DO_REGION" == "" ]; then
  echo "DO_REGION undefined, using $DEFAULT_DO_REGION"
  DO_REGION=$DEFAULT_DO_REGION
fi



if [ "$SSH_KEYS_BY_NAMES" != "" ]; then
    # we need to query ssh keys with their ids from DO account API
    ACCOUNT_KEYS=$(curl -s -H "Authorization: Bearer $DO_TOKEN" 'https://api.digitalocean.com/v2/account/keys' | jq -c '.ssh_keys[] | "\(.id),\(.name)"'| tr -d \")
    
    for KEY in $SSH_KEYS_BY_NAMES; do
        echo $ACCOUNT_KEYS | grep "$KEY" > /dev/null || {
            echo "ERROR: $KEY is missing from ssh keys in your account"
            exit 1
        }
        for ACCOUNT_KEY in $ACCOUNT_KEYS; do
            echo $ACCOUNT_KEY | grep "$KEY" > /dev/null && {
                if [ "$SSH_KEYS_IDS" == "" ]; then
                    SSH_KEYS_IDS="${ACCOUNT_KEY%,*}"
                else
                    SSH_KEYS_IDS="$SSH_KEYS_IDS, ${ACCOUNT_KEY%,*}"
                fi
            } || true
        done
    done
fi

if [ "$SSH_KEYS_IDS" == "" ]; then
    echo "SSH_KEYS_IDS is empty. You need to provide at least 1 existing SSH key from DO account either by using SSH_KEYS_IDS or SSH_KEYS_BY_NAMES"
    exit 1
fi

echo "creating .state"
mkdir -p .state

# terraform needs this in the .state
ln -svf ../main.tf .state/
ln -svf ../versions.tf .state/

pushd .state
terraform init
TF_VAR_DROPLET_NAME="$DROPLET_NAME" \
    TF_VAR_SSH_KEYS_IDS="[ $SSH_KEYS_IDS ]" \
    TF_VAR_DO_REGION="$DO_REGION" \
    TF_VAR_DO_TOKEN="$DO_TOKEN" \
    terraform apply -auto-approve
terraform show -json > show.json
popd

# now wait until droplet will reboot and become NixOS
DROPLET_IP=$(jq -r '.values.root_module.resources[].values.ipv4_address' .state/show.json | grep -v null)

# wait for SSH to start
while [ "$(nc $DROPLET_IP 22 -w 1 || echo "")" == "" ]; do
    echo "INFO: SSH is not available yet, waiting..."
    sleep 10s
done

echo "probe SSH keys"
ssh-keyscan "$DROPLET_IP" >> ~/.ssh/known_hosts

echo "waiting for droplet to become NixOS..."
ssh -A "root@$DROPLET_IP" 'while [ "$(cat /etc/os-release | grep NixOS || echo "")" == "" ]; do tail -f /tmp/infect.log || echo "still not NixOS, waiting..."; sleep 10s; done;' || true # ssh can return non-zero code on reboot

echo "removing old SSH public key"
ssh-keygen -R "$DROPLET_IP"

# wait for SSH to start
while [ "$(nc $DROPLET_IP 22 -w 1 || echo "")" == "" ]; do
    echo "INFO: SSH is not available yet, waiting..."
    sleep 10s
done

echo "probe SSH keys"
ssh-keyscan "$DROPLET_IP" >> ~/.ssh/known_hosts

echo "droplet IP: $DROPLET_IP, now you can ssh into it with \"ssh -A root@$DROPLET_IP\" or access with browser with \"http://$DROPLET_IP/signet\" "

