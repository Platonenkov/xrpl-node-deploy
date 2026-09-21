# Run a mainnet node on bare metal

This guide takes a fresh Debian or Ubuntu server to a synced XRP Ledger mainnet node, and then
optionally to one that serves public WebSocket traffic over TLS.

The node itself is the first six sections. Everything from [Serve public WSS](#serve-public-wss)
onward is only needed if clients outside the machine will connect.

> **Verification status.** The package source, the key fingerprint and the installed paths in this
> guide were checked against the current packages. The end-to-end procedure — certificate issuance,
> nginx, and the TLS listener — is written from a working deployment but has not been re-run against
> a clean server for this revision. Treat those sections as a tested recipe rather than a proof.

## Before you start

You need:

- Debian 11+ or Ubuntu 22.04+ with root or `sudo`
- disk sized for the profile you intend to run — see [configuration profiles](profiles.md)
- a domain name pointing at the server, if you want public WSS

Throughout, replace `node.example.org` with your own hostname.

## Give the machine swap

The node is memory-hungry during sync, and an out-of-memory kill mid-sync costs you the whole
download. Eight gigabytes of swap is a cheap insurance policy.

1. Create and enable the swap file:

   ```bash
   sudo swapoff -a
   sudo rm -f /swapfile
   sudo fallocate -l 8G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

2. Confirm it is in use:

   ```bash
   free -h
   ```

3. Make it survive a reboot by adding this line to `/etc/fstab`:

   ```text
   /swapfile none swap sw 0 0
   ```

## Add the package repository

Packages come from the XRP Ledger Foundation at `packages.xrplf.org`.

> Packaging moved here from `repos.ripple.com` in August 2026, and the binary was renamed from
> `rippled` to `xrpld`. The old repository still answers but its stable channel stopped at 3.3.0, so
> a machine still pointing there installs a node a release behind and never learns of it. If you are
> fixing such a host, replace `/etc/apt/sources.list.d/`, do not just upgrade.

1. Install what fetches and checks the key:

   ```bash
   sudo apt update
   sudo apt install -y ca-certificates curl gnupg
   ```

2. Download the key. It is armoured, so apt reads it as it is — do not run `gpg --dearmor` on it:

   ```bash
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsS https://packages.xrplf.org/xrplf.asc -o /etc/apt/keyrings/xrplf.asc
   ```

3. Check the key before trusting it. A key added without checking defeats the point of signing the
   repository:

   ```bash
   gpg --show-keys /etc/apt/keyrings/xrplf.asc
   ```

   The fingerprint must read:

   ```text
   pub   rsa4096 2026-08-18 [SC]
         B655 4167 4122 1F78 0FBC  FBC9 AA84 D41A 11D2 9FA9
   ```

   Stop here if it differs.

4. Add the repository. The channel uses one suite, `any main`, for every distribution — there is no
   codename to substitute:

   ```bash
   echo "deb [signed-by=/etc/apt/keyrings/xrplf.asc] https://packages.xrplf.org/repository/deb-stable any main" \
     | sudo tee /etc/apt/sources.list.d/xrplf.list
   ```

## Install the node

```bash
sudo apt update
sudo apt install -y xrpld
```

The package installs a systemd unit and starts it. It puts files here:

| Path | Contents |
| --- | --- |
| `/usr/bin/xrpld` | the binary; `/usr/local/bin/rippled` is a symlink to it |
| `/etc/xrpld/xrpld.cfg` | configuration |
| `/etc/xrpld/validators.txt` | the trusted validator list |
| `/var/lib/xrpld/db` | ledger databases |
| `/var/log/xrpld/debug.log` | log |

Check the service:

```bash
systemctl status xrpld
```

## Choose a profile

The shipped config keeps more history than most deployments need. Copy in the profile that matches
your use — see [configuration profiles](profiles.md) for the sizing table:

```bash
sudo cp configs/rippled-api.cfg /etc/xrpld/xrpld.cfg
sudo systemctl restart xrpld
```

## Wait for the node to sync

Give it 15–20 minutes on a light profile, considerably longer on the larger ones, then:

```bash
xrpld server_info
```

You are looking for:

```text
"server_state": "full"
```

Before that it passes through `connected` and `syncing`. A node that sits in `connected` for a long
time usually cannot reach peers — check that outbound port 51235 is open.

Watch progress with:

```bash
journalctl -u xrpld -f
```

## Serve public WSS

Everything below is optional. Skip it if only processes on this machine talk to the node.

### Issue a certificate

1. Install nginx and certbot:

   ```bash
   sudo apt install -y nginx python3-certbot-nginx
   ```

2. Give nginx a server block for the hostname so certbot can validate it. In
   `/etc/nginx/sites-enabled/default`:

   ```nginx
   server {
       listen 80;
       server_name node.example.org;

       root /var/www/html/;
       index index.html;
   }
   ```

3. Issue the certificate:

   ```bash
   sudo certbot --nginx -d node.example.org
   ```

   The files land in `/etc/letsencrypt/live/node.example.org/`.

### Let the node read the certificate

Let's Encrypt keys are readable by root only, and the node does not run as root. Grant a group
rather than loosening the whole tree.

1. Create a group and put the service user in it:

   ```bash
   sudo groupadd -f xrpld-certs
   sudo usermod -aG xrpld-certs xrpld
   ```

2. Give that group read access to the certificate directories only:

   ```bash
   sudo chgrp -R xrpld-certs /etc/letsencrypt/live /etc/letsencrypt/archive
   sudo chmod -R g+rX /etc/letsencrypt/live /etc/letsencrypt/archive
   ```

   Do not `chmod -R 770 /etc/letsencrypt`. That makes every private key on the machine group-writable,
   including certificates that have nothing to do with this node.

3. Renewal replaces the files and resets their ownership, so re-apply the two commands above from a
   certbot deploy hook — `/etc/letsencrypt/renewal-hooks/deploy/` — or the listener starts failing
   roughly every ninety days for no visible reason.

### Configure the listener

Edit `/etc/xrpld/xrpld.cfg`. Add the port to the `[server]` list and define it:

```ini
[server]
port_rpc_admin_local
port_peer
port_ws_public

[port_ws_public]
port = 6005
ip = 0.0.0.0
protocol = wss
send_queue_limit = 500

ssl_key = /etc/letsencrypt/live/node.example.org/privkey.pem
ssl_chain = /etc/letsencrypt/live/node.example.org/fullchain.pem
```

Bind to `0.0.0.0` rather than the public address: the machine's address can change, and
`0.0.0.0` keeps working when it does.

### Restart and verify

```bash
sudo systemctl restart xrpld
sudo systemctl restart nginx
```

Check from another machine with any WebSocket client:

```bash
wscat -c wss://node.example.org:6005
```

Then send `{"command":"ping"}`. A healthy node answers with `"status":"success"`.

## Harden the deployment

**Keep the admin port local.** The admin role can stop the node, change its peers, and set a
validation seed. It must never be reachable from outside:

```ini
[port_rpc_admin_local]
port = 5005
ip = 127.0.0.1
protocol = http
```

**Open only the ports you serve.** The peer port has to be reachable for the node to sync:

```bash
sudo ufw allow 6005/tcp     # public WSS, only if you serve it
sudo ufw allow 51235/tcp    # peer protocol, required
sudo ufw allow OpenSSH
sudo ufw enable
```

A published Docker port is not covered by this: Docker's NAT rules sit ahead of the chains ufw
manages, so a container port stays reachable with ufw enabled. Bind container ports to `127.0.0.1`
instead.

## Everyday commands

| Task | Command |
| --- | --- |
| Restart | `sudo systemctl restart xrpld` |
| Follow the log | `journalctl -u xrpld -f` |
| Server state | `xrpld server_info` |
| Current ledger | `xrpld ledger current` |
| Upgrade | `sudo apt update && sudo apt install --only-upgrade xrpld` |
| Hold a version | `sudo apt-mark hold xrpld` |

An upgrade restarts the node. It re-syncs to the current ledger quickly because it does not replay
history, so the outage is minutes. Configuration files are not overwritten; compare yours against
the shipped example after a major version.
