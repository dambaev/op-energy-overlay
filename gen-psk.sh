# this script is generating the passwords for op-energy instances. Requires 2
# command-line arguments: output directory and space separated list of bitcoin networks
# Requires:
# - python3 - for running rpcauth.py (from bitcoin)
# - curl / wget - for downloading rpcauth.py

set -ex

declare -A db_users=( ["mainnet"]="op-energy" ["testnet"]="top-energy" ["signet"]="sop-energy")
declare -A db_names=( ["mainnet"]="op-energy" ["testnet"]="top-energy" ["signet"]="sop-energy")

OUT_DIR=$1
NETWORKS="$2"

if [ "$OUT_DIR" == "" ] || [ "$NETWORKS" == "" ]; then
  echo "./$0 <OUTPUT_DIRECTORY> \"<networks_list>\""
  echo "where"
  echo "<networks_list> - space separated list of bitcoin networks, like: \"mainnet testnet signet\""
  exit 1
fi

mkdir -p "$OUT_DIR"

function curlOrWget() {
    local backend=curl
    curl --version >/dev/null 2>/dev/null || {
        backend="wget -O -"
        wget --verion > /dev/null 2>/dev/null || {
            echo "ERROR: there is no curl or wget available"
            exit 1
        }
    }
    $backend $@
}

for NETWORK in $NETWORKS; do
    PSK=$(dd if=/dev/urandom bs=1 count=10 2>/dev/null | sha256sum | awk '{print $1}')
    printf "%s" $PSK > $OUT_DIR/bitcoind-$NETWORK-rpc-psk.txt
    HMAC=$(curlOrWget https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py | python3 - "${db_users[$NETWORK]}" "$PSK" | grep rpcauth | awk 'BEGIN{FS=":"}{print $2}')
    printf "%s" "$HMAC" > $OUT_DIR/bitcoind-$NETWORK-rpc-pskhmac.txt 
    # DB PSK
    PSK=$(dd if=/dev/urandom bs=1 count=10 2>/dev/null | sha256sum | awk '{print $1}')
    printf "%s" "$PSK" > $OUT_DIR/op-energy-db-psk-$NETWORK.txt
done
