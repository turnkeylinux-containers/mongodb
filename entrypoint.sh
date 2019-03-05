MY=(
    [ROLE]=db
    [RUN_AS]=self

    [DB_NAME]="${DB_NAME:-test}"
    [DB_USER]="${DB_USER:-}"
    [DB_PASS]="${DB_PASS:-}"

    [MONGO_ROOT_USER]="${MONGO_ROOT_USER:-admin}"
    [MONGO_ROOT_PASS]="${MONGO_ROOT_PASS:-}"
)

passthrough_unless "mongod" "$@"

carefully "$@" --logpath /proc/self/fd/2 --fork
declare -ar mongo=( carefully mongo --host 127.0.0.1 --port 27017 --quiet )
poll "${mongo[@]}" 'admin' --eval 'quit(0)' || fatal "mongodb failed to start, exit code $?"

random_if_empty MONGO_ROOT_PASS
"${mongo[@]}" 'admin' <<<"db.createUser({
    user: \"${MY[MONGO_ROOT_USER]}\",
    pwd: \"${MY[MONGO_ROOT_PASS]}\",
    roles: [{role: 'root', db: 'admin'}]
})"

for f in "${OUR[INITDBS]}"/*; do
    case "$f" in
        *.sh) echo "running $f"; . "$f" ;;
        *.js) echo "running $f"; "${mongo[@]}" "${MY[DB_NAME]}" "$f"; echo ;;
        *)    echo "ignoring $f" ;;
    esac
done

carefully "$@" --shutdown
! am_root || chown -R mongodb:mongodb /data/db

echo 'MongoDB init process complete.'
run "$@" --bind_ip_all --auth
