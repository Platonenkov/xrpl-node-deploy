# XRPL Node Deploy

Configuration profiles, compose files and scripts for running an XRP Ledger node — from a local
standalone chain to full history in the cloud.

- Networks: mainnet, testnet, devnet, standalone
- Profiles: light, api, extended, full-history, validator
- Docker and bare metal
- Providers: AWS, DigitalOcean, Hetzner

## Where the packages come from

The node is installed from the **XRP Ledger Foundation** repository at `packages.xrplf.org`,
channel `deb-stable`.

> **If you already run a node, check where it installs from.** Packaging moved off
> `repos.ripple.com` in August 2026 and the binary was renamed from `rippled` to `xrpld`. The old
> repository still answers, but its stable channel stopped at 3.3.0 and never received 3.4.0. A
> node installed from it is a release behind and will never be told, because `apt upgrade` has
> nothing to offer from a frozen index. Such a host needs its source list replaced, not upgraded.
> `/usr/local/bin/rippled` survives as a symlink to the new binary.

Paths the package installs: binary `/usr/bin/xrpld`, config `/etc/xrpld/xrpld.cfg`, validators
`/etc/xrpld/validators.txt`, unit `xrpld.service`, data `/var/lib/xrpld/db`, log
`/var/log/xrpld/debug.log`.

## Layout

| Directory | Contents |
| --- | --- |
| `configs/` | `xrpld.cfg` profiles by how much history you keep |
| `docker/` | `Dockerfile` and one compose file per network |
| `providers/` | cloud-init and user-data for AWS, DigitalOcean, Hetzner |
| `scripts/` | bare-metal install, and the amendment list generator |

## Quick start

### Standalone in Docker

```bash
cd docker
docker compose -f docker-compose.standalone.yml up -d --build
```

Check it:

```bash
curl -s -H 'Content-Type: application/json' -d '{"method":"server_info","params":[{}]}' http://127.0.0.1:5005/
```

`server_state` should reach `proposing` or `validating`.

The node is built from the official packages rather than pulled as a prebuilt image. The one
third-party image this repository used still served 3.3.0 under `latest` four days after 3.4.0 was
released. The version is pinned in `docker/Dockerfile` (`ARG XRPLD_VERSION`), so a rebuild gives
you the same node rather than whatever the channel holds that day.

### Mainnet in Docker

```bash
cd docker
docker compose -f docker-compose.mainnet.yml up -d --build
```

On mainnet `server_state` reaches `full` once the node has synced.

### Mainnet on bare metal

```bash
sudo bash scripts/setup-mainnet.sh
```

### Restart after a config change

```bash
docker compose -f docker-compose.standalone.yml down
docker compose -f docker-compose.standalone.yml up -d --build --force-recreate
```

## Configuration profiles

| Profile | History | For |
| --- | --- | --- |
| `rippled-light.cfg` | 256 ledgers | wallets, backends |
| `rippled-api.cfg` | ~2–3 hours | API servers |
| `rippled-extended.cfg` | ~1 day | analytics over a short window |
| `rippled-standalone.cfg` | its own chain | local development |
| `rippled-validator.cfg` | recent ledgers | validator, needs a `validator_token` |
| `rippled-full.cfg` | complete | 12+ TB, only if you genuinely need it |

Applying one on bare metal:

```bash
sudo cp configs/rippled-light.cfg /etc/xrpld/xrpld.cfg
sudo systemctl restart xrpld
```

## The amendment list in the standalone profile

`rippled-standalone.cfg` lists amendments explicitly, because nothing enables them on a chain of
your own. **Do not maintain that list by hand.** rippled refuses to start on an amendment name it
does not know, and every release retires more names. This pack stopped starting for exactly that
reason once, on `Unknown feature: NonFungibleTokensV1`.

Generate it from the version you run instead:

```bash
bash scripts/generate-amendments.sh 3.4.0
```

The version you pass should match the one pinned in `docker/Dockerfile`.

## What is checked automatically

`.github/workflows/check-channel.yml`, weekly and on every pull request:

1. compares the pinned version against the newest in `deb-stable`, and looks at when the channel
   index last changed at all — a channel that has stopped shows up as an age that keeps growing;
2. starts a standalone node from these very files and waits for a usable `server_state`.

The second step exists because reading a diff does not catch a config carrying a retired amendment
name, and starting the node catches it immediately.

## Validator

`rippled-validator.cfg` carries an empty `[validator_token]` stanza with a placeholder. The token
comes from the `validator-keys` tool and does not belong in a repository.

## A note on language

The top-level documentation is English. Several files under `configs/`, `providers/` and
`scripts/` still carry Russian notes from before this pack was published; they are accurate, just
not translated yet.
