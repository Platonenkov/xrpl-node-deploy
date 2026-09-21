#!/bin/sh
# A bind-mounted data directory arrives owned by root: Docker creates the host path before the
# container starts, and the node runs unprivileged, so it cannot create its own db subdirectory
# inside it. This is invisible on Docker Desktop, which does not enforce ownership on bind
# mounts, and fails immediately on Linux - so it reaches an operator rather than the author.
#
# Fix the ownership as root, then drop to the service user for the node itself.
set -eu

for d in /var/lib/xrpld /var/lib/xrpld/db /var/log/xrpld; do
  mkdir -p "$d"
done
chown -R xrpld:xrpld /var/lib/xrpld /var/log/xrpld

exec setpriv --reuid=xrpld --regid=xrpld --clear-groups /usr/bin/xrpld --conf /etc/xrpld/xrpld.cfg "$@"
