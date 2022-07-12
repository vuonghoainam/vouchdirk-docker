# vouchdirk-docker

Attestant's Vouch &amp; Dirk in docker compose, to be used with eth-docker

This repo assumes a 2 vouch and 5 dirk setup with 3/5 threshold signing, and 3 Ethereum CL:EL full nodes.

## Initial setup

`cp default.env .env`, edit it to choose whether to run vouch and dirk or just dirk or just vouch, set the instance ID for dirk/vouch, and adjust
host and domain names to fit your environment.

`./create-dirk-config.sh` is meant to be run just once. It has no sanity checks and creates the CA, certs, and config yml files. The `config` directory
would then be copied to each server where a vouch or dirk instance runs. The script gets names from `.env`, which must exist.

`docker-compose up -d` to start Vouch/Dirk services.

On each of the Dirk instances, run `docker-compose run --rm create-wallet` once.

## Key generation

To create keys, adjust start and stop index in `.env` and then run `docker-compose run --rm create-accounts`.

To verify the first of these keys for correctness, run `docker-compose run --rm verify-account`

To create deposit data, using the same start and stop index in `.env`, run `docker-compose run --rm create-depositdata`. Adjust `FORK_VERSION` in
`.env` if you are going to generate for a testnet.

You can then create a single deposit.json with: `jq -n '[inputs|add]' config/depositdata/deposit-val-* > ./deposits.json`

## Architecture; redundancy and slashing considerations

2 Vouch and a 3/5 Dirk (3 threshold, 5 total) were chosen carefully. With 2 Vouch and 2/4 Dirk there would be a risk of slashing; 3 Vouch and 3/5 Dirk, Vouch might not get to threshold
and never be able to sign duties. 

1 Vouch and 2/3 Dirk would also work just as well.

This repository was created for a cross-region setup, with five hosts for Vouch/Dirk and 3 separate hosts for the CL:EL Ethereum nodes. It'd need some adjustment to be more flexible
in these numbers.

An alternate setup could run 1 Vouch and a 2/3 Dirk threshold setup inside a single k8s cluster. This repo does not aim to support that use case.

## Adding and removing keys

The recommendation by attestant.io is to restart dirk instances after adding or removing keys, because of the way caching works.

## Backup and restore

ethdo can back up the distributed wallet; the docker volume that holds the wallets on each dirk host could also be backed up

## Acknowledgements

Huge THANK YOU to Jeff Schroeder at Jump Crypto for generously sharing his knowledge of this setup, and to Jim McDonald at attestant.io for creating these tools
in the first place, and always having patience and time to troubleshoot.

## Resources

[Distributed key generation guide](https://github.com/attestantio/dirk/blob/master/docs/distributed_key_generation.md)
[Ethstaker Discord](https://discord.io/ethstaker)
[Attestant Discord](https://discord.gg/U5GNUuQQr3)
