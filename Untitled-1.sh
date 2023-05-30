
DIRK_INSTANCE=dirk1 # go from 1 to 5
WALLET_NAME=DistributedWallet
#WALLET_NAME=LydiaDistributedWallet
ACCOUNT_NAME=${WALLET_NAME}/val-1

FORK_VERSION=0x00001020
FORK_VERSION=0x00000000

WITHDRAWAL_ADDRESS=0x2fF53aeC1Ac58b9691B22Be6cD8bad338b2F6ce8

/app/ethdo --base-dir=/data/wallets wallet create \
         --type=distributed --wallet=${WALLET_NAME} --wallet-passphrase="hoainam96" --passphrase="hoainam96"

/app/ethdo --base-dir=/data/wallets account create \
         --remote=dirk1:13141 --server-ca-cert /config/certs/dirk_authority.crt \
         --client-cert /config/certs/vouch1.crt --client-key /config/certs/vouch1.key \
        --account="${WALLET_NAME}/val-1" --signing-threshold=3 --participants=5

/app/ethdo account info \
    --base-dir=/data/wallets \
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

/app/ethdo account key \
--base-dir=/data/wallets/${DIRK_INSTANCE}/wallets \
--remote=dirk1:13141 \
--server-ca-cert /config/certs/dirk_authority.crt \
--client-cert /config/certs/vouch1.crt \
--client-key /config/certs/vouch1.key \
--account="$ACCOUNT_NAME" \
--passphrase=hoainam96 \
--verbose

/app/ethdo validator depositdata \
  --depositvalue 32Ether \
  --remote=dirk1:13141 \
  --server-ca-cert /config/certs/dirk_authority.crt \
  --client-cert /config/certs/vouch1.crt \
  --client-key /config/certs/vouch1.key \
  --validatoraccount DistributedWallet/val-1 \
  --launchpad \
  --forkversion ${FORK_VERSION} \
  --withdrawaladdress ${WITHDRAWAL_ADDRESS} > /config/depositdata/deposit-val-1.json
