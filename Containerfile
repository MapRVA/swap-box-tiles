FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        osm2pgsql \
        osmium-tool \
        postgresql-client \
        curl \
        ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY filter.lua /etc/osm2pgsql/filter.lua
COPY sql/schema.sql /etc/osm2pgsql/schema.sql
COPY bootstrap.sh /usr/local/bin/bootstrap.sh
COPY replicate.sh /usr/local/bin/replicate.sh
RUN chmod +x /usr/local/bin/bootstrap.sh /usr/local/bin/replicate.sh

USER nobody
WORKDIR /work
