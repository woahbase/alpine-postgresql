#!/usr/bin/with-contenv bash
# reference: https://github.com/docker-library/postgres/blob/master/16/alpine3.21/docker-entrypoint.sh

if [ -n "${DEBUG}" ]; then set -ex; fi;
vecho () { if [ "${S6_VERBOSITY:-1}" -gt 0 ]; then echo "[$0] $@"; fi; }

PGSQL_HOME="${PGSQL_HOME:-/var/lib/postgresql}";
PGDATA="${PGDATA:-${PGSQL_HOME}/data}"; # only created during initializing, not after
PGSQL_BACKUPDIR="${PGSQL_BACKUPDIR:-${PGSQL_HOME}/backups}"; # for backups
PGSQL_INITDIR="${PGSQL_INITDIR:-/initdb.d}"; # for initializer files

if [ "X${EUID}" = "X0" ]; then vecho "must be run as a non-root postgresql user."; exit 1; fi;

CMD="$1"; # required to select task to run

# usage: process_init_file FILENAME PSQL_ARGS...
#    ie: process_init_file foo.sh
# (process a single initializer file, based on its extension. we define this
# function here, so that initializer scripts (*.sh) can use the same logic,
# potentially recursively, or override the logic used in subsequent calls)
process_init_file() {
    local f="$1"; shift;
    # default args for psql
    local PSQL_ARGS="${PSQL_ARGS:- -v ON_ERROR_STOP=1 --username ${POSTGRES_USER:-$S6_USER} }";
    if [[ $# -gt 0 ]]; then PSQL_ARGS="$@"; fi;

    case "$f" in
        *.sh|*.bash)
            if [ -x "$f" ];
            then
                vecho "Running $f";
                "$f";
            else
                vecho "Sourcing $f";
                . "$f";
            fi
        ;;
        *.sql)
            vecho "Loading $f";
            psql ${PSQL_ARGS[@]} < "$f";
        ;;
        *.sql.gz)
            vecho "Extracting/loading $f";
            gunzip -c "$f" | psql ${PSQL_ARGS[@]};
        ;;
        *.sql.xz)
            vecho "Extracting/loading $f";
            xzcat "$f" | psql ${PSQL_ARGS[@]};
        ;;
        *.sql.zst)
            vecho "Extracting/loading $f";
            zstd -dc "$f" | psql ${PSQL_ARGS[@]};
        ;;
        *)  vecho "Ignoring $f" ;;
    esac
}

if [ "${CMD^^}" == 'INITDB' ];
then # process initial db state and/or configurations (used by s6-init scripts)
    if [ -n "${PGSQL_INITDIR}" ] && [ -d "${PGSQL_INITDIR}" ];
    then
        vecho "Checking for initializer files in ${PGSQL_INITDIR}...";
        for f in $(find "${PGSQL_INITDIR}" -maxdepth 1 -type f 2>/dev/null | sort -u);
        do
            process_init_file "$f" ${@:2};
        done;
        vecho "Done.";
    fi;

elif [ "${CMD^^}" == 'BACKUP' ]; # backup single db
then
    DB="$2"; # required db name
    OPTS="${@:3}";
    if [ -z "${OPTS}" ]; then OPTS="-F c"; fi; # by default use format acceptable by pg_restore
    pg_dump \
        ${OPTS[@]} \
        "${DB}" > "${PGSQL_BACKUPDIR}/${DB}.pgdump";

elif [ "${CMD^^}" == 'RESTORE' ]; # restore single db
then
    DB="$2"; # required db name
    OPTS="${@:3}";
    pg_restore \
        ${OPTS[@]} \
        -d "${DB}" \
        "${PGSQL_BACKUPDIR}/${DB}.pgdump"; # backup must already exist

elif [ "${CMD^^}" == 'HEALTHCHECK' ]; # used in Dockerfile
then
    pg_isready -d  ${POSTGRES_DB:-postgres};

elif [ "${CMD^^}" == 'TEMP-SERVER-START' ]; # and wait until started
then
    vecho "PostgreSQL temporary server starting.";
    pg_ctl \
        -D "${PGDATA}" \
        -o "$(printf '%q ' "-p "${PGPORT:-5432}" ${PGSQL_ARGS}")" \
        -w start \
    ;
    vecho "PostgreSQL temporary server started.";

elif [ "${CMD^^}" == 'TEMP-SERVER-STOP' ]; # runs as non-root user by default
then
    vecho "Stopping PostgreSQL temporary server.";
    pg_ctl \
        -D "${PGDATA}" \
        -m fast \
        -w stop \
    ;
    vecho "PostgreSQL temporary server stopped.";

else
    echo "Usage: $0 <cmd> <additional args>";
    echo "cmd:";
    echo "  initdb <additional args>";
    echo "    load initializer files from ${PGSQL_INITDIR}";
    echo "  backup <dbname>";
    echo "    backup single db to ${PGSQL_BACKUPDIR}/<dbname>.pgdump";
    echo "  restore <dbname>";
    echo "    restore single db from ${PGSQL_BACKUPDIR}/<dbname>.pgdump";
    echo "  healthcheck";
    echo "    run healthcheck as \$POSTGRES_USER";
    echo "  temp-server-start <additional args>";
    echo "    start a temporary-server";
    echo "  temp-server-stop";
    echo "    stop temporary-server";
fi;
