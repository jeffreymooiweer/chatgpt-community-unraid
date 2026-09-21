#!/usr/bin/with-contenv bash

set -euo pipefail

UNRAID_HOST="${UNRAID_HOST:-192.168.1.6}"

SSH_DIR="/config/.ssh"
SSH_KEY="${SSH_DIR}/id_ed25519"
SSH_CONFIG="${SSH_DIR}/config"
WORKSPACE="/config/workspace/unraid"

mkdir -p "${SSH_DIR}"
mkdir -p "${WORKSPACE}"

chmod 0700 "${SSH_DIR}"

if [ ! -f "${SSH_KEY}" ]; then
    ssh-keygen \
        -q \
        -t ed25519 \
        -N "" \
        -C "chatgpt-community@unraid" \
        -f "${SSH_KEY}"
fi

cat > "${SSH_CONFIG}" <<EOF
Host unraid
    HostName ${UNRAID_HOST}
    User root
    IdentityFile /config/.ssh/id_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
    ServerAliveCountMax 3
EOF

chmod 0600 "${SSH_KEY}"
chmod 0644 "${SSH_KEY}.pub"
chmod 0600 "${SSH_CONFIG}"

cat > "${WORKSPACE}/AGENTS.md" <<EOF
# Unraid Server Workspace

This workspace manages the Unraid host.

## Host

SSH alias:

\`\`\`bash
ssh unraid
\`\`\`

Unraid address:

\`\`\`text
${UNRAID_HOST}
\`\`\`

The SSH account is root.

## Important execution rule

The ChatGPT Community application itself runs inside a Docker container.

Commands intended for the Unraid server must therefore be executed through SSH.

For example:

\`\`\`bash
ssh unraid 'docker ps'
\`\`\`

or:

\`\`\`bash
ssh unraid 'uname -a'
\`\`\`

Do not assume the local container shell is the Unraid host.

## Server administration

Root access to the Unraid host is authorized.

Use SSH for:

- Docker management
- Unraid configuration
- filesystem administration
- logs
- networking
- processes
- storage inspection
- system diagnostics
- scripts and automation

Inspect the current state before destructive storage, filesystem, boot, network, or Docker operations.

Persistent Unraid configuration lives under /boot/config.

User shares live under /mnt/user.
EOF

chown -R abc:abc "${SSH_DIR}"
chown -R abc:abc "${WORKSPACE}"

echo "[chatgpt-community] Unraid SSH host: ${UNRAID_HOST}"
echo "[chatgpt-community] SSH public key:"
cat "${SSH_KEY}.pub"
