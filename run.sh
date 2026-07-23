#!/usr/bin/env bash
#
# Ping a set of monitors and push "up" to Uptime Kuma for each healthy one.
#
#   PUSH_URL  base URL of the Uptime Kuma push endpoint, e.g. https://kuma/api/push
#   MONITORS  comma-separated list of "name|url|token" entries

: "${PUSH_URL:?Missing PUSH_URL}"
: "${MONITORS:?Missing MONITORS}"

push_url="${PUSH_URL%/}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

log "Using PUSH_URL: $push_url"

# Parse "name|url|token,..." into parallel arrays.
names=() urls=() tokens=()
IFS=',' read -ra entries <<< "$MONITORS"
for entry in "${entries[@]}"; do
    IFS='|' read -r name url token <<< "$entry"
    if [[ -z "$name" || -z "$url" || -z "$token" ]]; then
        log 'Invalid MONITORS format. Expected "name|url|token[,name|url|token,...]"'
        exit 1
    fi
    names+=("$name"); urls+=("$url"); tokens+=("$token")
    log "Loaded monitor: name=$name url=$url token=$token"
done

# Ping one monitor; push "up" only when it answers with a 2xx.
check() {
    local name="$1" url="$2" token="$3"
    if curl -sSkf --max-time 5 -o /dev/null "$url"; then
        if curl -sSk --retry 5 --max-time 5 -o /dev/null "$push_url/$token?status=up&msg=OK"; then
            log "'$name' OK, ping sent"
        else
            log "'$name' OK, but failed to send ping"
        fi
    else
        log "'$name' with URL '$url' is down, not sending ping"
    fi
}

while true; do
    start=$SECONDS
    for i in "${!names[@]}"; do
        check "${names[i]}" "${urls[i]}" "${tokens[i]}" &
    done
    wait

    sleep_for=$(( 60 - (SECONDS - start) ))
    (( sleep_for < 10 )) && sleep_for=10
    log "Sleeping for: $sleep_for"
    sleep "$sleep_for"
done
