#!/usr/bin/with-contenv bash
set -euo pipefail
umask 077

CONFIG_DIR="${CHATGPT_CONFIG_DIR:-/config}"
DEFAULTS_DIR="${CHATGPT_DEFAULTS_DIR:-/defaults}"
APP_USER="${CHATGPT_APP_USER:-abc}"
APP_GROUP="${CHATGPT_APP_GROUP:-abc}"
UNRAID_HOST="${UNRAID_HOST:-192.168.1.6}"
[[ "$UNRAID_HOST" =~ ^[a-zA-Z0-9._:-]+$ ]] || {
    echo '[chatgpt-community] Invalid UNRAID_HOST.' >&2
    exit 1
}

SSH_DIR="$CONFIG_DIR/.ssh"
SSH_KEY="$SSH_DIR/id_ed25519"
WORKSPACE="$CONFIG_DIR/workspace/unraid"
BACKUP="$CONFIG_DIR/.local/state/chatgpt-community/migration-single-app-v1"
mkdir -p "$SSH_DIR" "$WORKSPACE" "$BACKUP"
chmod 0700 "$SSH_DIR" "$BACKUP"
# Newly created parent directories must be traversable by the session user.
mkdir -p "$CONFIG_DIR/.config"
chown "$APP_USER:$APP_GROUP" "$CONFIG_DIR/.config" "$CONFIG_DIR/workspace" \
    "$CONFIG_DIR/.local" "$CONFIG_DIR/.local/state" \
    "$CONFIG_DIR/.local/state/chatgpt-community" "$BACKUP"

# Do not rotate an existing SSH identity or overwrite custom host aliases.
if [ ! -f "$SSH_KEY" ]; then
    ssh-keygen -q -t ed25519 -N '' -C chatgpt-community@unraid -f "$SSH_KEY"
fi
if [ ! -s "$SSH_KEY.pub" ]; then
    ssh-keygen -y -P '' -f "$SSH_KEY" > "$SSH_KEY.pub"
fi
if [ ! -e "$SSH_DIR/config" ]; then
    cat > "$SSH_DIR/config" <<EOF
Host unraid
    HostName $UNRAID_HOST
    User root
    IdentityFile $SSH_KEY
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
    ServerAliveCountMax 3
EOF
fi
chmod 0600 "$SSH_KEY" "$SSH_DIR/config"
chmod 0644 "$SSH_KEY.pub"
chown "$APP_USER:$APP_GROUP" "$SSH_DIR" "$SSH_KEY" "$SSH_KEY.pub" "$SSH_DIR/config"

if [ ! -e "$WORKSPACE/AGENTS.md" ]; then
    cat > "$WORKSPACE/AGENTS.md" <<'EOF'
# Unraid Server Workspace

The local shell belongs to the ChatGPT container, not the Unraid host.
Run host commands through the existing root SSH alias, for example:

```bash
ssh unraid 'hostname; id; docker ps'
```

Root access is available. Inspect before changing anything. Obtain explicit
approval before deleting data, formatting storage, changing boot/network/SSH
configuration, or stopping this container. Never expose tokens or private keys.
Persistent host configuration: /boot/config. User shares: /mnt/user.
EOF
    chown "$APP_USER:$APP_GROUP" "$WORKSPACE/AGENTS.md"
fi
chown "$APP_USER:$APP_GROUP" "$WORKSPACE"

# Selkies only seeds autostart files on first use. Migrate old Webtop copies
# explicitly, keeping originals for rollback. Never touch .codex or Codex.
for wm in labwc openbox; do
    dir="$CONFIG_DIR/.config/$wm"
    mkdir -p "$dir"
    source="$DEFAULTS_DIR/autostart"
    [ "$wm" != labwc ] || source="$DEFAULTS_DIR/autostart_wayland"
    if ! cmp -s "$source" "$dir/autostart"; then
        if [ -e "$dir/autostart" ] && [ ! -e "$BACKUP/$wm-autostart" ]; then
            cp -p "$dir/autostart" "$BACKUP/$wm-autostart"
        fi
        install -m 0755 "$source" "$dir/autostart"
    fi
    chown "$APP_USER:$APP_GROUP" "$dir" "$dir/autostart"
done
legacy="$CONFIG_DIR/.config/autostart/chatgpt-community.desktop"
if [ -f "$legacy" ]; then
    if [ ! -f "$BACKUP/chatgpt-community.desktop" ]; then
        cp -p "$legacy" "$BACKUP/chatgpt-community.desktop"
    fi
    rm -- "$legacy"
fi

echo '[chatgpt-community] Single-application session configured; existing credentials preserved.'
echo '[chatgpt-community] SSH public key:'
cat "$SSH_KEY.pub"
if [ -z "${PASSWORD:-}" ]; then
    echo '[chatgpt-community] WARNING: set PASSWORD for WebUI authentication; keep access on LAN/VPN.' >&2
fi
