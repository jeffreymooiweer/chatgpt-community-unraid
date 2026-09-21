# ChatGPT Community for Unraid

Run ChatGPT Community as a single application in your browser, with experimental
Remote Mobile Control and an existing SSH connection to your Unraid host.

## Interface

**Unraid → Docker → ChatGPT-Community → WebUI** opens the ChatGPT application.
There is no XFCE desktop, taskbar or start menu. The image uses the LinuxServer
Selkies single-app base, labwc/Wayland, and an X11/Openbox fallback. Linux libraries
and a compositor remain necessary; this is not a native HTML version of ChatGPT.
An auxiliary Chromium browser is included for sign-in and external links.

Defaults: 30 fps, no Selkies sidebar, no sharing links, no gamepad, and no window
manager decorations. Closing the browser does not stop the application or its
Remote app-server. Closing ChatGPT relaunches it after five seconds.

## Upgrade an existing Webtop installation

1. Finish any active agent task. Back up `/mnt/user/appdata/chatgpt-community`
   while the container is stopped. The backup contains private credentials:
   restrict access and do not upload it to GitHub.
2. Keep the container name, hostname, `/config` mapping, PUID and PGID unchanged.
   Keep using `ghcr.io/jeffreymooiweer/chatgpt-community-unraid:latest`.
3. Under **Docker → Edit → Advanced View → Extra Parameters**, append
   `--device=/dev/dri:/dev/dri` to the existing parameters for an Intel/AMD GPU.
   Do not enable Privileged or mount the Docker socket. On a host without
   `/dev/dri`, omit the device mapping.
4. Add a **Variable** with key `PASSWORD` and a strong, unique WebUI password.
   The default WebUI username is `abc`; set `CUSTOM_USER` to change it. This is
   separate from your ChatGPT login. Use only LAN/VPN access.
5. Apply the configuration and update the image in the Docker tab once the
   main-branch build has completed successfully. Open the existing WebUI.

Refreshing a Private Apps template does **not** add new device mappings or
variables to an already installed container; step 3 is still necessary.

The migration replaces the two managed window-manager autostart scripts and
archives the old ones in:

```text
/config/.local/state/chatgpt-community/migration-single-app-v1/
```

It disables the old ChatGPT XFCE autostart entry. It does not delete `.codex`,
`.config/Codex`, Remote device keys, keyring files, SSH keys, `known_hosts`, existing
SSH configuration or your edited workspace `AGENTS.md`. The launch-time sandbox
workaround is now part of the image, not a modification inside a running container.
No new account enrollment is intentionally requested by the migration; upstream
and account-side changes remain outside the wrapper's control.

## Fresh installation / Private Apps

Publish the image through the repository workflow and make the GHCR package
accessible to your Unraid server. To register the template locally:

```bash
mkdir -p /boot/config/plugins/community.applications/private/ChatGPT-Community
curl --fail --location --retry 3 \
  https://raw.githubusercontent.com/jeffreymooiweer/chatgpt-community-unraid/main/unraid/chatgpt-community.xml \
  -o /boot/config/plugins/community.applications/private/ChatGPT-Community/chatgpt-community.xml
```

Install from Private Apps, set a WebUI password and use the existing appdata path
when migrating. The first initialization creates an SSH identity, but does not
modify Unraid's `authorized_keys`. Existing authorized identities remain valid.

For a new identity, append the **public** key as a separate line on Unraid:

```bash
bash <<'SCRIPT'
set -euo pipefail
pub="$(docker exec -u abc ChatGPT-Community cat /config/.ssh/id_ed25519.pub)"
printf '%s\n' "$pub" | ssh-keygen -lf - >/dev/null
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
if ! grep -qxF "$pub" /root/.ssh/authorized_keys; then
    printf '\n%s\n' "$pub" >> /root/.ssh/authorized_keys
fi
SCRIPT
```

## GPU and fallback

Mounting `/dev/dri` allows the baseimage to detect the rendering and encoding GPU.
`DRINODE` is the render device; `DRI_NODE` is the encode device. Normally leave both
unset for automatic selection. Hardware availability is not proof of actual
hardware encoding: inspect the runtime diagnostics during an active WebUI stream.

Intel/AMD FullColor 4:4:4 is disabled by default to avoid a software-encoding
fallback. Static-scene paint-over remains available for text clarity. No measured
CPU reduction is claimed until tested on the target hardware.

Useful settings in the Unraid editor:

| Variable | Default | Use |
| --- | --- | --- |
| `PIXELFLUX_WAYLAND` | `true` | Set `false` for the single-app X11 fallback |
| `AUTO_GPU` | `true` | Set `false` to disable automatic GPU selection |
| `SELKIES_FRAMERATE` | `30` | Stream frame-rate cap |
| `SELKIES_UI_SHOW_SIDEBAR` | `false` | Set `true` for stream settings/diagnostics |
| `PASSWORD` | unset | Required for authenticated WebUI access |
| `CUSTOM_USER` | `abc` | WebUI username |
| `UNRAID_HOST` | `192.168.1.6` | Only used when creating a new SSH configuration |

## Updates and tests

GitHub Actions checks upstream every six hours and rebuilds weekly for baseimage
updates. Pull requests test the last recorded official payload. Builds validate
the package checksum, run migration regression tests, start the actual image in
both X11 and Wayland CPU modes, test HTTPS and restart persistence, and only then
publish the **tested image** to `:latest` plus a unique `build-...` rollback tag.
The recorded upstream state advances only after successful publication, so a
failed candidate is retried on the next scheduled check.

Tests do not sign in to an OpenAI account, exercise Remote enrollment, access
Unraid or verify Intel hardware. Those require the real installation. Build logs
are retained as Actions artifacts for seven days.

## Diagnostics

```bash
docker logs --tail 100 ChatGPT-Community
docker exec ChatGPT-Community tail -n 100 /config/.cache/chatgpt-community/startup.log
docker exec -u abc ChatGPT-Community vainfo --display drm --device /dev/dri/renderD128
docker exec -u abc ChatGPT-Community ssh unraid 'hostname; id'
```

For rollback, stop the container, restore the pre-upgrade appdata backup, and set
the Repository field to the previous image tag or digest. Keep credentials in
backups private. Do not run two instances against the same `/config`.

## Security and upstream status

`--no-sandbox` disables Chromium's sandbox; it does not relax Codex's approval
settings. An application with a root SSH key can control the host, so Docker
is **not** an adequate security boundary against abuse of that key. Protect the
WebUI, the account, the private key and backups. Never publish port 33443 directly
to the internet. Retain approval for destructive operations.

This is an unofficial wrapper around
[ChatGPT Community](https://github.com/ilysenko/codex-desktop-linux).
Linux Remote Control remains experimental; successful local tests cannot
guarantee server-side enrollment or continued compatibility.

Implementation references:
[LinuxServer single-app images](https://docs.linuxserver.io/selkies/developer-guide/building-images/),
[configuration](https://docs.linuxserver.io/selkies/user-guide/configuration/),
[GPU acceleration](https://docs.linuxserver.io/selkies/user-guide/gpu/),
[upstream Remote extension](https://github.com/ilysenko/codex-desktop-linux/tree/main/linux-features/remote-mobile-control).
