# syntax=docker/dockerfile:1
#
ARG IMAGEBASE=frommakefile
#
FROM ${IMAGEBASE}
#
ARG PGMAJOR=14
#
ENV \
    PGDATA=/var/lib/postgresql/data \
    PGSQL_BACKUPDIR=/var/lib/postgresql/backups \
    PGPORT=5432 \
    S6_USER=postgres \
    S6_USERHOME=/var/lib/postgresql
#
RUN set -xe \
#
    && userdel -rf alpine \
    && addgroup -g ${PGID} -S ${S6_USER} \
    && adduser -u ${PUID} -G ${S6_USER} -h ${S6_USERHOME} -s /bin/false -D ${S6_USER} \
#
    && apk add --no-cache --purge -uU \
        bash \
        bzip2 \
        gzip \
        openssl \
        tzdata \
        xz \
        zstd \
#
        postgresql${PGMAJOR} \
        postgresql${PGMAJOR}-contrib \
        postgresql${PGMAJOR}-jit \
#
        pg_top \
        # pgbackrest \
#
        # postgresql-age \
        # postgresql-bdr-extension \
        # postgresql-pgvector \
        # postgresql-rum \
        # postgresql-timescaledb \
#
    && if [ ! -e "/usr/bin/postgres" ]; then ln -sf $(which postgres${PGMAJOR}) /usr/bin/postgres; fi \
#
    && rm -rf /var/cache/apk/* /tmp/*
#
COPY root/ /
#
VOLUME  ["${S6_USERHOME}"]
#
STOPSIGNAL SIGINT
#
EXPOSE ${PGPORT} 5433
#
HEALTHCHECK \
    --interval=2m \
    --retries=5 \
    --start-period=5m \
    --timeout=10s \
    CMD \
        s6-setuidgid ${POSTGRES_USER:-$S6_USER} /scripts/run.sh healthcheck \
    || exit 1
#
ENTRYPOINT ["/init"]
