# Run in container 
DIRK_INSTANCE=dirk1 # go from 1 to 5
WALLET_NAME=LydiaDistributedWallet
ACCOUNT_NAME=${WALLET_NAME}/val-2
FORK_VERSION=0x00001020
WITHDRAWAL_ADDRESS=0x2fF53aeC1Ac58b9691B22Be6cD8bad338b2F6ce8

/app/ethdo --base-dir=/data/wallets/${DIRK_INSTANCE} wallet create \
         --type=distributed --wallet=${WALLET_NAME} --wallet-passphrase="hoainam96" --passphrase="hoainam96"

cp -r /data/wallets/${DIRK_INSTANCE}/* /data/wallets/dirk2/
cp -r /data/wallets/${DIRK_INSTANCE}/* /data/wallets/dirk3/
cp -r /data/wallets/${DIRK_INSTANCE}/* /data/wallets/dirk4/
cp -r /data/wallets/${DIRK_INSTANCE}/* /data/wallets/dirk5/

# Restart so that all dirks load this wallet
# From this moment on, only need to connect to 1 dirk

/app/ethdo --base-dir=/data/wallets/${DIRK_INSTANCE} account create \
         --remote=dirk1:13141 --server-ca-cert /config/certs/dirk_authority.crt \
         --client-cert /config/certs/vouch1.crt --client-key /config/certs/vouch1.key \
        --account="${ACCOUNT_NAME}" --signing-threshold=3 --participants=5

/app/ethdo account info \
    --base-dir=/data/wallets/${DIRK_INSTANCE} \
    --remote=dirk1:13141 \
    --server-ca-cert /config/certs/dirk_authority.crt \
    --client-cert /config/certs/vouch1.crt \
    --client-key /config/certs/vouch1.key \
    --account="$ACCOUNT_NAME" \
    --verbose

/app/ethdo signature sign \
    --remote=dirk1:13141 \
    --server-ca-cert /config/certs/dirk_authority.crt \
    --client-cert /config/certs/vouch1.crt \
    --client-key /config/certs/vouch1.key \
    --account="$ACCOUNT_NAME" \
  --data=0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  --domain=0xf000000000000000000000000000000000000000000000000000000000000000 \
  --verbose

/app/ethdo validator depositdata \
  --depositvalue 32Ether \
  --remote=dirk1:13141 \
  --server-ca-cert /config/certs/dirk_authority.crt \
  --client-cert /config/certs/vouch1.crt \
  --client-key /config/certs/vouch1.key \
  --validatoraccount $ACCOUNT_NAME \
  --launchpad \
  --forkversion ${FORK_VERSION} \
  --withdrawaladdress ${WITHDRAWAL_ADDRESS} > /config/depositdata/deposit-val-2.json

# Run in host
jq -n '[inputs|add]' config/depositdata/deposit-val-{1..3}.json > config/depositdata/deposits.json


    "network_name": "goerli",
    "deposit_cli_version": "2.5.1"