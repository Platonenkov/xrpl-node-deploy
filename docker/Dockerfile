# Builds xrpld from the XRP Ledger Foundation apt repository.
#
# The compose files used to pull xrpllabsofficial/xrpld:latest. That is a third-party image,
# and as of 2026-09-21 its "latest" tag still carried 3.3.0 - four days after 3.4.0 was
# released - with no official XRPLF image to switch to. Building from the packages the project
# publishes itself removes the dependency and makes the version visible in one place.
FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://packages.xrplf.org/xrplf.asc -o /etc/apt/keyrings/xrplf.asc

# Pin it: an unpinned image rebuilds into a different node whenever the channel moves, and a
# node that changed under you is the hardest kind of incident to read. check-channel.yml says
# when a newer version is out.
ARG XRPLD_VERSION=3.4.0-1
RUN echo "deb [signed-by=/etc/apt/keyrings/xrplf.asc] https://packages.xrplf.org/repository/deb-stable any main" > /etc/apt/sources.list.d/xrplf.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "xrpld=${XRPLD_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

# setpriv comes from util-linux, already in the base image; the entrypoint uses it to drop
# privileges after fixing the data directory.
RUN id -u xrpld >/dev/null 2>&1 || useradd --system --home-dir /var/lib/xrpld --shell /usr/sbin/nologin xrpld

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

EXPOSE 5005 5006 6006 51235

# Runs as root only long enough to chown the mounted data directory; the node itself runs
# as xrpld. See entrypoint.sh.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
