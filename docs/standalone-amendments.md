# Amendments on a standalone chain

A standalone node runs a chain with no other validators, so the usual amendment process — validators
voting over two weeks — never happens. Whatever you want active has to be stated in the config
before the chain exists.

This page explains the two config sections that do that, and why the version you generate them for
has to match the binary you run.

## The two sections do different jobs

`xrpld.cfg` can carry both `[amendments]` and `[features]`. They are not alternatives.

`[amendments]` takes lines of `<hash> <name>`, where the hash is the SHA-512Half of the name. At
`--start` these register as genesis votes, so the amendments become **enabled on the ledger**: they
appear in the `Amendments` ledger object and the `feature` command reports them as enabled. This is
what any code that introspects amendment state will see. Only amendments the binary supports can be
enabled this way; it skips the rest.

`[features]` does not vote. It feeds the rules preset the transactors consult, so a listed amendment
is treated as active **while transactions are processed**, even though the ledger says it is
disabled. This is the only way to reach code behind an amendment the binary marks as unsupported.

The practical consequence: a node with `[features]` alone will execute the new behaviour while
reporting the amendment as disabled. If anything you run checks amendment state before deciding what
to send, it needs `[amendments]`.

## Generate the lists

```bash
bash scripts/generate-amendments.sh 3.4.0
```

The script reads `features.macro` from that tag of the rippled source and rewrites both sections of
`configs/rippled-standalone.cfg`. Pass a second argument to write somewhere else:

```bash
bash scripts/generate-amendments.sh 3.4.0 /etc/xrpld/xrpld.cfg
```

The version can also be a commit, which is what you want when the node is a development build rather
than a release.

## The version has to match the binary

The node refuses to start on an amendment name it does not recognise, and it exits rather than
warning:

```text
terminate called after throwing an instance of 'std::runtime_error'
  what():  Unknown feature: NonFungibleTokensV1  in config file.
```

There are two ways to produce that:

- **Generating for a newer version than the binary.** The newer source declares amendments the older
  binary has never heard of.
- **Leaving an old list in place across an upgrade.** Amendments that become permanent are *retired*
  from the source, and a retired name is as unknown to the binary as a future one. This pack stopped
  starting on exactly that, on `NonFungibleTokensV1` after the node moved to 3.4.0.

So the argument to the script and the `ARG XRPLD_VERSION` pin in `docker/Dockerfile` are one
decision, not two. Change them together.

## Amendments only take effect at genesis

`[amendments]` is read when the chain is created. Adding a name to a chain that already has ledgers
does nothing, and the `feature` admin command cannot activate one on a running standalone node
either — with no voting there is nothing for it to influence.

To change the set, throw the chain away:

```bash
cd docker
docker compose -f docker-compose.standalone.yml down
rm -rf ./data-standalone
docker compose -f docker-compose.standalone.yml up -d --build
```

## Check what actually ended up enabled

Read the `Amendments` ledger object rather than trusting the config:

```bash
curl -s -H 'Content-Type: application/json' \
  -d '{"method":"ledger_entry","params":[{"index":"7DB0788C020F02780A673DC74757F23823FA3014C1866E72CC4CD8B226CD6EF4","ledger_index":"validated"}]}' \
  http://127.0.0.1:5005/
```

That index is the fixed key of the `Amendments` entry. The response lists the enabled amendment
hashes; an amendment that is only in `[features]` will not be among them, which is the distinction
this page opens with.
