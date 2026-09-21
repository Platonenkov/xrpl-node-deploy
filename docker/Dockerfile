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

EXPOSE 5005 6006 51235

USER xrpld
ENTRYPOINT ["/usr/bin/xrpld", "--conf", "/etc/xrpld/xrpld.cfg"]
