# Deploy from a provider template

`providers/` holds first-boot templates that install and start a node without anyone logging in:
cloud-init for DigitalOcean and Hetzner, user-data for AWS.

They all do the same three things: add the XRPL Foundation repository, install `xrpld`, and start
the service. What they cannot do is read this repository — a template runs on a machine that has
never heard of it.

## Give the template a config to fetch

Each template takes the node configuration from a URL. Host one of the files from `configs/`
somewhere the new machine can reach, then set `CONFIG_URL` to it.

The URL must serve the file as plain text. A link that returns an HTML preview page produces a node
that refuses to start on a config full of markup.

1. Publish a profile — object storage, a static site, or any HTTPS endpoint:

   ```text
   https://files.example.org/xrpl/rippled-light.cfg
   ```

2. Point the template at it. In the AWS user-data script, `CONFIG_URL` is an environment variable
   read near the end:

   ```bash
   CONFIG_URL="https://files.example.org/xrpl/rippled-light.cfg"
   ```

   In the cloud-init files it appears in the `runcmd` block; replace the URL there.

If you leave `CONFIG_URL` empty, the AWS template installs the node and leaves the packaged
configuration in place. That is a working node — it simply keeps more history than most deployments
want.

Embedding the configuration inline in the template instead of fetching it works and removes the
hosting requirement. It also makes the template large and awkward to diff, which is why these use a
URL.

## The templates

| File | Platform | Mechanism |
| --- | --- | --- |
| `providers/aws/userdata-mainnet.sh` | AWS EC2 | user-data, handles both apt and rpm hosts |
| `providers/digitalocean/cloud-init-mainnet.yaml` | DigitalOcean | cloud-init |
| `providers/hetzner/cloud-init-mainnet.yaml` | Hetzner | cloud-init |

The AWS script detects the package manager, so it works on Amazon Linux as well as Ubuntu. The
cloud-init files are apt-only.

## Install on an existing machine instead

`scripts/setup-mainnet.sh` does the same work on a server you already have:

```bash
sudo bash scripts/setup-mainnet.sh
```

It is the same sequence as [the bare-metal guide](mainnet-bare-metal.md), without the optional TLS
and nginx sections. Read that guide if you want to understand what the script does, or if it fails
part-way and you need to continue by hand.

## After first boot

A template gives you a node, not a finished deployment. Once the machine is up:

1. Confirm the node is running and syncing:

   ```bash
   xrpld server_info
   ```

   `server_state` reaches `full` after it syncs.

2. Close the admin port if the template left it open, and put a firewall in front of the machine.
   See [harden the deployment](mainnet-bare-metal.md#harden-the-deployment).

3. Decide whether this node serves traffic from outside. If it does, it needs TLS — see
   [serve public WSS](mainnet-bare-metal.md#serve-public-wss).

> **Verification status.** These templates are adapted from working deployments, and their package
> and path handling matches the current packages. They have not been re-run on a fresh instance at
> each provider for this revision.
