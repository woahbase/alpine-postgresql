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
    && case "${PGMAJOR}" in \
        "17") { \
                echo "http://dl-cdn.alpinelinux.org/alpine/v3.21/main"; \
                echo "http://dl-cdn.alpinelinux.org/alpine/v3.21/community"; \
            } > /tmp/repo3.21 \
            && apk add --no-cache --repositories-file "/tmp/repo3.21" \
                # pg-gvm \
                # pgpool \
                # postgis \
                postgresql-age \
                postgresql-bdr-extension \
                postgresql-hypopg \
                postgresql-mysql_fdw \
                postgresql-orafce \
                postgresql-pg_cron \
                postgresql-pg_roaringbitmap \
                postgresql-pgvector \
                postgresql-rum \
                postgresql-sequential-uuids \
                postgresql-shared_ispell \
                postgresql-temporal_tables \
                postgresql-timescaledb \
                postgresql-topn \
                postgresql-uint \
                postgresql-url_encode \
                # repmgr \
        ;; \
        "16") { \
                echo "http://dl-cdn.alpinelinux.org/alpine/v3.20/main"; \
                echo "http://dl-cdn.alpinelinux.org/alpine/v3.20/community"; \
            } > /tmp/repo3.20 \
            && apk add --no-cache --repositories-file "/tmp/repo3.20" \
                # pg-gvm \
                # pgpool \
                # postgis \
                postgresql-age \
                postgresql-bdr-extension \
                postgresql-citus \
                postgresql-hypopg \
                postgresql-mysql_fdw \
                postgresql-orafce \
                postgresql-pg_cron \
                postgresql-pg_roaringbitmap \
                postgresql-pgvector \
                postgresql-rum \
                postgresql-sequential-uuids \
                postgresql-shared_ispell \
                postgresql-temporal_tables \
                postgresql-timescaledb \
                postgresql-topn \
                postgresql-uint \
                postgresql-url_encode \
                # repmgr \
        ;; \
        "15") { \
                echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/main"; \
                echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/community"; \
            } > /tmp/repo3.18 \
            && apk add --no-cache --repositories-file "/tmp/repo3.18" \
                # pg-gvm \
                # pgpool \
                # postgis \
                postgresql-bdr-extension \
                postgresql-citus \
                postgresql-hypopg \
                postgresql-mysql_fdw \
                postgresql-orafce \
                postgresql-pg_cron \
                postgresql-rum \
                postgresql-sequential-uuids \
                postgresql-shared_ispell \
                postgresql-temporal_tables \
                postgresql-timescaledb \
                postgresql-uint \
                postgresql-url_encode \
                # repmgr \
        ;; \
       esac \
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
