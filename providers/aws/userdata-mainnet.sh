#!/bin/bash
# EC2 user-data: install xrpld from the XRP Ledger Foundation packages and start it.
#
# Packaging moved from repos.ripple.com to packages.xrplf.org in August 2026. The old host
# still answers but its stable channel stopped at 3.3.0, so anything still pointing there
# installs a node a release behind and never learns about it.
set -euo pipefail

if command -v dnf >/dev/null 2>&1; then PKG=dnf
elif command -v yum >/dev/null 2>&1; then PKG=yum
else PKG=apt; fi

if [ "$PKG" = "apt" ]; then
  apt update -y
  apt install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsS https://packages.xrplf.org/xrplf.asc -o /etc/apt/keyrings/xrplf.asc
  # One suite for every distribution: the channel is not split by codename.
  echo "deb [signed-by=/etc/apt/keyrings/xrplf.asc] https://packages.xrplf.org/repository/deb-stable any main" > /etc/apt/sources.list.d/xrplf.list
  apt update -y
  apt install -y xrpld
else
  "$PKG" install -y ca-certificates curl
  rpm --import https://packages.xrplf.org/xrplf.asc
  cat > /etc/yum.repos.d/xrplf.repo <<REPO
[xrplf-stable]
name=XRPL Foundation stable
enabled=1
baseurl=https://packages.xrplf.org/repository/rpm-stable/$basearch/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.xrplf.org/xrplf.asc
REPO
  "$PKG" install -y xrpld
fi

# The packages enable and start the service themselves; stop it while the config is replaced.
systemctl stop xrpld || true

# Point CONFIG_URL at your own copy of one of the profiles in configs/, or drop the file in
# by another route - user-data has no access to this repository.
CONFIG_URL="${CONFIG_URL:-}"
if [ -n "$CONFIG_URL" ]; then
  install -m 0755 -d /etc/xrpld
  curl -fsS -o /etc/xrpld/xrpld.cfg "$CONFIG_URL"
fi

install -m 0755 -d -o xrpld -g xrpld /var/log/xrpld /var/lib/xrpld

systemctl enable --now xrpld
systemctl status --no-pager xrpld || true
