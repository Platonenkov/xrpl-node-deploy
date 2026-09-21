# Configuration profiles

Each profile in `configs/` is a complete `xrpld.cfg`. They differ in how much ledger history the
node keeps, which decides almost everything else: disk, memory, and how long a fresh node takes to
become useful.

Pick by the oldest data you need to answer a request. Keeping more history than that costs storage
and buys nothing.

## The profiles

| Profile | History kept | Disk | RAM | Use it for |
| --- | --- | --- | --- | --- |
| `rippled-light.cfg` | 5–10 minutes | 6–12 GB | 2–4 GB | wallets, services that only submit and watch |
| `rippled-api.cfg` | 2–3 hours | 50–150 GB | 4–8 GB | backends and public APIs |
| `rippled-extended.cfg` | 24 hours | 400–800 GB | 8–16 GB | analytics over a recent window |
| `rippled-validator.cfg` | 30–60 minutes | 20–50 GB | 16–32 GB | validators |
| `rippled-full.cfg` | complete | 12–20 TB | 64–128 GB | archives and explorers |
| `rippled-standalone.cfg` | its own chain | under 1 GB | 2 GB | local development |

Disk and memory figures are planning estimates, not measurements. Full history grows continuously:
size it for where the ledger will be, not where it is.

## Apply a profile

The node reads one config file. Replacing it and restarting is the whole procedure.

1. Copy the profile into place:

   ```bash
   sudo cp configs/rippled-light.cfg /etc/xrpld/xrpld.cfg
   ```

2. Restart the service:

   ```bash
   sudo systemctl restart xrpld
   ```

3. Confirm the node came back:

   ```bash
   xrpld server_info
   ```

   On a network node `server_state` reaches `full` after it syncs, which takes minutes on `light`
   and far longer on `full`.

## The validator profile needs a token

`rippled-validator.cfg` carries an empty `[validator_token]` stanza. Generate the token with the
`validator-keys` tool that ships alongside the node, and keep it out of version control — it is the
identity of your validator.

## Amendments in the standalone profile

`rippled-standalone.cfg` lists amendments explicitly. Nothing enables them on a chain of your own,
so a standalone node without the list behaves like a node from before those amendments existed.

**Do not edit the list by hand.** The node refuses to start on an amendment name it does not know,
and every release retires more names. Generate the list for the version you run:

```bash
bash scripts/generate-amendments.sh 3.4.0
```

Pass the same version pinned in `docker/Dockerfile`. See
[the amendment list](standalone-amendments.md) for what the two config sections do and why the
version has to match.

## Changing amendments on a running standalone chain

Amendments in `[amendments]` are applied once, at genesis. Adding a name to a chain that already
exists does nothing. Start over instead:

```bash
cd docker
docker compose -f docker-compose.standalone.yml down
rm -rf ./data-standalone
docker compose -f docker-compose.standalone.yml up -d --build
```

This destroys the local chain, which is the point — a standalone chain is disposable.
