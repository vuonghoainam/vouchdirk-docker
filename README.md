# vouchdirk-docker

Attestant's Vouch &amp; Dirk in docker compose, to be used with eth-docker

This repo assumes a 2 vouch and 5 dirk setup with 3/5 threshold signing, and 3 Ethereum CL:EL full nodes.

## Initial setup

`cp default.env .env`, edit it to choose whether to run vouch and dirk or just dirk or just vouch, set the instance ID for dirk/vouch, and adjust
host and domain names to fit your environment.

`./create-dirk-config.sh` is meant to be run just once. It has no sanity checks and creates the CA, certs, and config yml files. The `config` directory
would then be copied to each server where a vouch or dirk instance runs. The script gets names from `.env`, which must exist.

`docker compose up -d` to start Vouch/Dirk services.

On each of the Dirk instances, run `docker compose run --rm create-wallet` once.

Run `docker compose down && docker compose up -d` to ensure Dirk loads this new wallet correctly.

## Key generation

To create keys, adjust start and stop index in `.env` and then run `docker compose run --rm create-accounts`.

To verify the first of these keys for correctness, run `docker compose run --rm verify-account`

To create deposit data, using the same start and stop index in `.env`, run `docker compose run --rm create-depositdata`. Adjust `FORK_VERSION` in
`.env` if you are going to generate for a testnet.

You can then create a single deposit.json with: `jq -n '[inputs|add]' config/depositdata/deposit-val-{1..10}.json > ~/deposits.json`, adjusting for the
range you want to have in the file.

## Architecture; redundancy and slashing considerations

2 Vouch (one warm standby) and a 3/5 Dirk (3 threshold, 5 total) were chosen carefully. With 2 Vouch and 2/4 Dirk there would be a risk of slashing; 3 Vouch and 3/5 Dirk, Vouch might not get to threshold
and never be able to sign duties. 

1 Vouch and 2/3 Dirk would also work just as well.

This repository was created for a cross-region setup, with five hosts for Vouch/Dirk and 3 separate hosts for the CL:EL Ethereum nodes. It'd need some adjustment to be more flexible
in these numbers.

An alternate setup could run 1 Vouch and a 2/3 Dirk threshold setup inside a single k8s cluster. This repo does not aim to support that use case.

The reason a cross-region setup was chosen is that while region outages are rare, they do occur. It is desirable for a staking node operator to be able to regain liveness even when an entire region fails.

With multiple Vouch instances, a degradation in the number of Dirk instances can result in the inability to sign. At its simplest, if there are 2 Vouch and 4 Dirk (out of originally 5) with a threshold of 3, then it is possible for one Vouch instance to obtain 2 signatures and the second Vouch instance to obtain 2 signatures, with neither reaching the threshold and no signature generated. If MEV is in use, the CL needs to "point back to" Vouch, and this as well requires the use of a single Vouch instance.

For this reason, it is recommended to run Vouch in container orchestration with cross-AZ failover, and have the second Vouch instance ready in case there is an outage for an entire region. Vouch is stateless and will start in seconds.

Slashing protection works like this:
- Vouch will ask Dirk for a threshold signature
- A Dirk that has already participated in one will refuse to do so again because slashing protection DB. That means if both Vouch are running simultaneously, one will get to at least 3/5, the other at most 2/5 and won't get a full signature
- The slashing protection DB is kept locally by each Dirk

## Adding and removing keys

The recommendation by attestant.io is to restart Dirk instances after adding or removing keys, because of the way caching works.

## Backup and restore

To back up the wallet on each local Dirk instance, run `docker compose run --rm export-keys` and then save the resulting file and the passphrase you used.

You will need to run this on all five (5) Dirk instances individually.

Each Dirk instance is its own entity. If a Dirk instance fails, the backup of that instance can be restored and once it is rebuilt it will continue in the cluster.

## Prometheus

By adding `prometheus.yml:ext-network.yml` you can run a Prometheus that can remote-write to your Mimir or Thanos, with the remote-write section in `prometheus/custom-prom.yml`.

## Acknowledgements

Huge THANK YOU to Jeff Schroeder at Jump Crypto for generously sharing his knowledge of this setup, and to Jim McDonald at attestant.io for creating these tools
in the first place, and always having patience and time for explanations.

## Resources

- [Distributed key generation guide](https://github.com/attestantio/dirk/blob/master/docs/distributed_key_generation.md)
- [Ethstaker Discord](https://discord.io/ethstaker)
- [Attestant Discord](https://discord.gg/U5GNUuQQr3)


```bash
WALLET_NAME=DistributedWallet
DIRK_INSTANCE=dirk1 # go from 1 to 5
root@77451040715d:/app# /app/ethdo --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets wallet create \
         --type=distributed --wallet=${WALLET_NAME}
Error: failed to process: wallet "DistributedWallet" already exists
root@77451040715d:/app# /app/ethdo --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets account create \
         --remote=dirk1:13141 --server-ca-cert /config/certs/dirk_authority.crt \
         --client-cert /config/certs/vouch1.crt --client-key /config/certs/vouch1.key \
        --account="${WALLET_NAME}/val-1" --signing-threshold=3 --participants=5

root@77451040715d:/app# DIRK_INSTANCE=dirk2
root@77451040715d:/app# /app/ethdo --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets account create          --remote=dirk1:13141 --server-ca-cert /config/certs/dirk_authority.crt          --client-cert /config/certs/vouch1.crt --client-key /config/certs/vouch1.key         --account="${WALLET_NAME}/val-1" --signing-threshold=3 --participants=5
Error: failed to process: failed to create account: generate request failed: account already exists

root@77451040715d:/app# DIRK_INSTANCE=dirk1
root@77451040715d:/app# /app/ethdo --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets account create \
         --remote=dirk1:13141 --server-ca-cert /config/certs/dirk_authority.crt \
         --client-cert /config/certs/vouch1.crt --client-key /config/certs/vouch1.key \
        --account="${WALLET_NAME}/val-2" --signing-threshold=3 --participants=5
root@77451040715d:/app# /app/ethdo --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets account create \
         --remote=dirk1:13141 --server-ca-cert /config/certs/dirk_authority.crt \
         --client-cert /config/certs/vouch1.crt --client-key /config/certs/vouch1.key \
        --account="${WALLET_NAME}/val-3" --signing-threshold=3 --participants=5

root@77451040715d:/app# ACCOUNT_NAME=${WALLET_NAME}/val-3

root@77451040715d:/app# /app/ethdo account info     --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets     --remote=dirk1:13141     --server-ca-cert /config/certs/dirk_authority.crt     --client-cert /config/certs/vouch1.crt     --client-key /config/certs/vouch1.key     --account="$ACCOUNT_NAME"     --verbose
UUID: 8b79a1cd-e81d-4d88-a802-589c44ad5d70
Public key: 0xb19fb1019bcf04de12bd95c96d4498633ac499ed8b9ea8ee7465835d626f2f23bc3ed183bfc6ee2c533d5c1f4e4df8a4
Composite public key: 0xb74f6532a836bed12337e52316ad26df898c509342f7a6abf997c3e7912980c88cc8677642692d60cd9d7c983d8a7fe2
Signing threshold: 3/5
Participants:
 45212209: dirk5:13141
 20362446: dirk1:13141
 37474837: dirk2:13141
 52717854: dirk3:13141
 29504835: dirk4:13141
Withdrawal credentials: 0x0081fc2bcf8876d6aa3059b577c081e0373f351fa07345e6ab2212bfc271f583

root@77451040715d:/app# ACCOUNT_NAME=${WALLET_NAME}/val-1
root@77451040715d:/app# /app/ethdo account info     --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets     --remote=dirk1:13141     --server-ca-cert /config/certs/dirk_authority.crt     --client-cert /config/certs/vouch1.crt     --client-key /config/certs/vouch1.key     --account="$ACCOUNT_NAME"     --verbose
UUID: 6abdb91b-d831-42ba-be95-325d4c69e3ef
Public key: 0x8408600b7be17923157903dbd2acb537aef9464058c5218b646104b2697857e7c0e4a668ac5b7297b7e258a500e38148
Composite public key: 0x916f19d800788ef07ea6003852f149b8dfaccf219f16aff6fce9e729371fda1e46dd93ccdb7ce126f8a0d84e4f327a26
Signing threshold: 3/5
Participants:
 45212209: dirk5:13141
 20362446: dirk1:13141
 37474837: dirk2:13141
 52717854: dirk3:13141
 29504835: dirk4:13141
Withdrawal credentials: 0x007da9f2c4deeae891b7da7d627fdd496f7fa26332e849cd55db5a95245a013d


root@77451040715d:/app# ACCOUNT_NAME=${WALLET_NAME}/val-2
root@77451040715d:/app# /app/ethdo account info     --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets     --remote=dirk1:13141     --server-ca-cert /config/certs/dirk_authority.crt     --client-cert /config/certs/vouch1.crt     --client-key /config/certs/vouch1.key     --account="$ACCOUNT_NAME"     --verbose
UUID: 6aa13b34-4a51-4f99-8975-06932ef77bcf
Public key: 0x820261a30381306bacc6d6cc43df438291b0da6ac9ef1db3c0b34e51a0879479e123612394f596ef2f60c2de9efb4f3b
Composite public key: 0x9019370fc97b4c8627a0c4365a683936bfd44419969eac8addfff4c644b33ca4d8c17a798baa2ce302fa821486548578
Signing threshold: 3/5
Participants:
 20362446: dirk1:13141
 37474837: dirk2:13141
 52717854: dirk3:13141
 29504835: dirk4:13141
 45212209: dirk5:13141
Withdrawal credentials: 0x001c348e58a359a86b27db258d1f83a9954ae0e81a47f5d842de8b31f13acef3


root@77451040715d:/app# ACCOUNT_NAME=${WALLET_NAME}/val-4
root@77451040715d:/app# /app/ethdo account info     --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets     --remote=dirk1:13141     --server-ca-cert /config/certs/dirk_authority.crt     --client-cert /config/certs/vouch1.crt     --client-key /config/certs/vouch1.key     --account="$ACCOUNT_NAME"     --verbose
Failed to obtain account: failed to obtain account: not found

root@77451040715d:/app# /app/ethdo signature sign \
    --remote=dirk1:13141 \
    --server-ca-cert /config/certs/dirk_authority.crt \
    --client-cert /config/certs/vouch1.crt \
    --client-key /config/certs/vouch1.key \
    --account="$ACCOUNT_NAME" \
  --data=0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  --domain=0xf000000000000000000000000000000000000000000000000000000000000000 \
  --verbose
Failed to obtain account: unable to obtain account: failed to obtain account: not found


root@77451040715d:/app# DIRK_INSTANCE=dirk1 # go from 1 to 5
WALLET_NAME=DistributedWallet
ACCOUNT_NAME=${WALLET_NAME}/val-1
root@77451040715d:/app# /app/ethdo signature sign \
    --remote=dirk1:13141 \
    --server-ca-cert /config/certs/dirk_authority.crt \
    --client-cert /config/certs/vouch1.crt \
    --client-key /config/certs/vouch1.key \
    --account="$ACCOUNT_NAME" \
  --data=0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  --domain=0xf000000000000000000000000000000000000000000000000000000000000000 \
  --verbose
Signing 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f with domain 0xf000000000000000000000000000000000000000000000000000000000000000 by public key 0x8408600b7be17923157903dbd2acb537aef9464058c5218b646104b2697857e7c0e4a668ac5b7297b7e258a500e38148
0xb63fd76b43b2fb7c6734cd8666c23dd8f86527e334f668df2e4564fb84fd05d88a9d33c5c6714dacbbf64bd5b0b5109e09e8363d28326620acb5e863c215fd138b8d469ea73b65a83cdac697c71efbc6f6cc8fb4d82ddc236ceb56682629f8e7


root@77451040715d:/app# /app/ethdo account info     --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets     --remote=dirk1:13141     --server-ca-cert /config/certs/dirk_authority.crt     --client-cert /config/certs/vouch1.crt     --client-key /config/certs/vouch1.key     --account="$ACCOUNT_NAME"     --verbose
UUID: 6abdb91b-d831-42ba-be95-325d4c69e3ef
Public key: 0x8408600b7be17923157903dbd2acb537aef9464058c5218b646104b2697857e7c0e4a668ac5b7297b7e258a500e38148
Composite public key: 0x916f19d800788ef07ea6003852f149b8dfaccf219f16aff6fce9e729371fda1e46dd93ccdb7ce126f8a0d84e4f327a26
Signing threshold: 3/5
Participants:
 52717854: dirk3:13141
 29504835: dirk4:13141
 45212209: dirk5:13141
 20362446: dirk1:13141
 37474837: dirk2:13141
Withdrawal credentials: 0x007da9f2c4deeae891b7da7d627fdd496f7fa26332e849cd55db5a95245a013d


root@77451040715d:/app# /app/ethdo account info     --base-dir=/data/wallets/${DIRK_INSTANCE}/wallets     --remote=dirk1:13141     --server-ca-cert /config/certs/dirk_authority.crt     --client-cert /config/certs/vouch1.crt     --client-key /config/certs/vouch1.key     --account="$ACCOUNT_NAME"     --verbose
UUID: 6abdb91b-d831-42ba-be95-325d4c69e3ef
Public key: 0x8408600b7be17923157903dbd2acb537aef9464058c5218b646104b2697857e7c0e4a668ac5b7297b7e258a500e38148
Composite public key: 0x916f19d800788ef07ea6003852f149b8dfaccf219f16aff6fce9e729371fda1e46dd93ccdb7ce126f8a0d84e4f327a26
Signing threshold: 3/5
Participants:
 37474837: dirk2:13141
 52717854: dirk3:13141
 29504835: dirk4:13141
 45212209: dirk5:13141
 20362446: dirk1:13141
Withdrawal credentials: 0x007da9f2c4deeae891b7da7d627fdd496f7fa26332e849cd55db5a95245a013d


root@77451040715d:/app# /app/ethdo signature sign     --remote=dirk1:13141     --server-ca-cert /config/certs/dirk_authority.crt     --client-cert /config/certs/vouch1.crt     --client-key /config/certs/vouch1.key     --account="$ACCOUNT_NAME"   --data=0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f   --domain=0xf000000000000000000000000000000000000000000000000000000000000000   --verbose
Signing 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f with domain 0xf000000000000000000000000000000000000000000000000000000000000000 by public key 0x8408600b7be17923157903dbd2acb537aef9464058c5218b646104b2697857e7c0e4a668ac5b7297b7e258a500e38148
0xb63fd76b43b2fb7c6734cd8666c23dd8f86527e334f668df2e4564fb84fd05d88a9d33c5c6714dacbbf64bd5b0b5109e09e8363d28326620acb5e863c215fd138b8d469ea73b65a83cdac697c71efbc6f6cc8fb4d82ddc236ceb56682629f8e7


root@77451040715d:/app# /app/ethdo signature sign     --remote=dirk1:13141     --server-ca-cert /config/certs/dirk_authority.crt     --client-cert /config/certs/vouch1.crt     --client-key /config/certs/vouch1.key     --account="$ACCOUNT_NAME"   --data=0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f   --domain=0xf000000000000000000000000000000000000000000000000000000000000000   --verbose
Signing 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f with domain 0xf000000000000000000000000000000000000000000000000000000000000000 by public key 0x8408600b7be17923157903dbd2acb537aef9464058c5218b646104b2697857e7c0e4a668ac5b7297b7e258a500e38148
Failed to sign: failed to obtain signature: not enough signatures: 2 signed, 0 denied, 0 failed, 3 errored

root@77451040715d:/app# /app/ethdo signature sign     --remote=dirk1:13141     --server-ca-cert /config/certs/dirk_authority.crt     --client-cert /config/certs/vouch1.crt     --client-key /config/certs/vouch1.key     --account="$ACCOUNT_NAME"   --data=0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f   --domain=0xf000000000000000000000000000000000000000000000000000000000000000   --verbose
Signing 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f with domain 0xf000000000000000000000000000000000000000000000000000000000000000 by public key 0x8408600b7be17923157903dbd2acb537aef9464058c5218b646104b2697857e7c0e4a668ac5b7297b7e258a500e38148
0xb63fd76b43b2fb7c6734cd8666c23dd8f86527e334f668df2e4564fb84fd05d88a9d33c5c6714dacbbf64bd5b0b5109e09e8363d28326620acb5e863c215fd138b8d469ea73b65a83cdac697c71efbc6f6cc8fb4d82ddc236ceb56682629f8e7



root@77451040715d:/app# /app/ethdo signature sign \
    --remote=dirk1:13141 \
    --server-ca-cert /config/certs/dirk_authority.crt \
    --client-cert /config/certs/vouch1.crt \
    --client-key /config/certs/vouch1.key \
    --account="$ACCOUNT_NAME" \
  --data=0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  --domain=0xf000000000000000000000000000000000000000000000000000000000000000 \
  --verbose
Signing 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f with domain 0xf000000000000000000000000000000000000000000000000000000000000000 by public key 0x8569c7077a917bee013b4c6acdb7fd090e89a260316a68ce839825b8c876210b2eca4ae5c8eb9766ff1105e6f00c2bd9
Failed to sign: failed to obtain signature: not enough signatures: 1 signed, 4 denied, 0 failed, 0 errored

-------
docker compose up -d
docker compose run —rm create-wallet
Update .env for start and end account index
docker compose restart dirk{1-5}
docker compose run —rm create-accounts
docker compose restart dirk{1-5}
docker compose run --rm verify-account
docker compose run --rm create-depositdata

Test sign:
/app/ethdo signature sign \
    --remote=dirk1:13141 \
    --server-ca-cert /config/certs/dirk_authority.crt \
    --client-cert /config/certs/vouch1.crt \
    --client-key /config/certs/vouch1.key \
    --account="$ACCOUNT_NAME" \
  --data=0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  --domain=0xf000000000000000000000000000000000000000000000000000000000000000 \
  --verbose


jq -n '[inputs|add]' config/depositdata/deposit-val-1.json > config/depositdata/deposits.json

/app/ethdo deposit verify --data=/config/depositdata/deposit-val-1.json 
Withdrawal public key or address not supplied; withdrawal credentials NOT checked
Amount verified
Validator public key not suppled; NOT checked
Deposit data root verified
Fork version incorrect
Deposit failed verification

```