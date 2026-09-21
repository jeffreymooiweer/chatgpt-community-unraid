#!/usr/bin/env bash
set -euo pipefail
IMAGE="${1:?Supply the candidate image tag}"
mkdir -p test-results
name=''
collect() {
    [ -n "$name" ] || return 0
    docker logs "$name" > "test-results/$name-container.log" 2>&1 || true
    docker port "$name" > "test-results/$name-ports.log" 2>&1 || true
    docker cp "$name:/config/.cache/chatgpt-community/startup.log" \
        "test-results/$name-app.log" >/dev/null 2>&1 || true
}
cleanup() {
    collect
    [ -z "$name" ] || docker rm -fv "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_ready() {
    local minimum_initializations="${1:-1}"
    local attempt port initializations
    for attempt in $(seq 1 90); do
        # Docker may assign a different ephemeral host port after a restart.
        port="$(docker port "$name" 3001/tcp 2>/dev/null | sed -n '1s/.*://p' || true)"
        initializations="$(docker exec "$name" grep -c 'Codex CLI initialized' \
            /config/.cache/chatgpt-community/startup.log 2>/dev/null || true)"
        if [[ "$port" =~ ^[0-9]+$ ]] \
            && [[ "$initializations" =~ ^[0-9]+$ ]] \
            && [ "$initializations" -ge "$minimum_initializations" ] \
            && docker exec "$name" pgrep -x ChatGPT >/dev/null 2>&1 \
            && docker exec "$name" pgrep -x codex >/dev/null 2>&1 \
            && curl -kfsS --max-time 5 -u "abc:$password" \
                "https://127.0.0.1:$port/" >/dev/null 2>&1; then
            echo "Ready: $name on HTTPS port $port (initializations=$initializations)"
            return 0
        fi
        sleep 2
    done
    echo "Application did not become ready: $name" >&2
    collect
    cat "test-results/$name-ports.log" >&2
    tail -n 120 "test-results/$name-container.log" >&2
    [ ! -f "test-results/$name-app.log" ] || tail -n 120 "test-results/$name-app.log" >&2
    return 1
}

for wayland in false true; do
    name="chatgpt-smoke-$wayland"
    password="$(openssl rand -hex 24)"
    docker run -d --name "$name" --shm-size=1g \
        -p 127.0.0.1::3001 -e PUID=1000 -e PGID=1000 \
        -e "PIXELFLUX_WAYLAND=$wayland" -e "PASSWORD=$password" \
        -e UNRAID_HOST=192.0.2.1 "$IMAGE" >/dev/null
    wait_ready
    docker exec "$name" bash -c '! command -v xfce4-session && ! pgrep -x xfce4-panel'
    backend=x11
    [ "$wayland" != true ] || backend=wayland
    docker exec "$name" grep -q "Starting ChatGPT Community:.*backend=$backend" \
        /config/.cache/chatgpt-community/startup.log
    before="$(docker exec "$name" sha256sum /config/.ssh/id_ed25519)"
    # There has been no streaming WebSocket client. The application must stay alive.
    sleep 5
    docker exec "$name" pgrep -x ChatGPT >/dev/null
    initializations="$(docker exec "$name" grep -c 'Codex CLI initialized' \
        /config/.cache/chatgpt-community/startup.log)"
    docker restart "$name" >/dev/null
    # Require a new handshake, not a matching line from the previous process.
    wait_ready "$((initializations + 1))"
    after="$(docker exec "$name" sha256sum /config/.ssh/id_ed25519)"
    [ "$before" = "$after" ]
    echo "PASS: backend wayland=$wayland; application, HTTPS and SSH-key persistence"
    cleanup
    name=''
done
