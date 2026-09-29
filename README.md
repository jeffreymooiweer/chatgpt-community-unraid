# ChatGPT Community — Docker Image

Run [ChatGPT Community for Linux](https://github.com/ilysenko/codex-desktop-linux)
in Docker and access it from your browser.

A single-app experience with no full desktop, taskbar, or start menu. The
application runs inside the container; your browser displays its interface.

> An unofficial community project, not affiliated with OpenAI, Unraid, or
> LinuxServer.io. This is not a locally hosted AI model. An account and internet
> access are required for online features; account limits still apply.

## Features

- Browser-based access over HTTPS.
- Persistent settings, sign-in data, and workspaces.
- Optional Intel/AMD GPU acceleration for rendering and streaming.
- Experimental Remote Mobile Control support.
- Optional SSH access for server-management tasks, authorized separately.
- Automated image builds with checks before publication.

## Image

```text
ghcr.io/jeffreymooiweer/chatgpt-community-unraid:latest
```

**Architecture:** `linux/amd64` (64-bit Intel/AMD).

[Available image tags](https://github.com/jeffreymooiweer/chatgpt-community-unraid/pkgs/container/chatgpt-community-unraid)
· [Build status](https://github.com/jeffreymooiweer/chatgpt-community-unraid/actions/workflows/build.yml)
· [Report an issue](https://github.com/jeffreymooiweer/chatgpt-community-unraid/issues)

An [Unraid container template](unraid/chatgpt-community.xml) is included.

## Configuration

| Setting | Purpose |
| --- | --- |
| `3001/tcp` | Container HTTPS port. Map to an available host port. |
| `/config` | Persistent storage for settings, credentials, and workspaces. |
| `PASSWORD` | WebUI password. **Set a strong, unique password.** |
| `CUSTOM_USER` | WebUI username; defaults to `abc`. |
| `PUID` / `PGID` | User/group IDs for access to the persistent folder. |
| `TZ` | Your timezone. |
| `/dev/dri` | Optional Intel/AMD GPU device mapping; omit if unavailable. |
| `UNRAID_HOST` | Host address used when creating the initial SSH configuration. Does not rewrite an existing configuration. |

Use `--shm-size=1g`. Privileged mode and Docker socket access are not required.

The WebUI login is separate from your application account. HTTPS uses a
self-signed certificate by default.

GPU acceleration is optional and helps stream the interface—not run cloud AI
models locally. Without a GPU mapping, CPU rendering is available. If you
encounter display problems, `PIXELFLUX_WAYLAND=false` selects the X11 fallback.

## Updates and data

The build workflow checks upstream every six hours and also runs a weekly
refresh. New images are published as `latest` only after the required build and
automated tests succeed. Unique `build-...` tags identify previous builds.

Upstream changes can still require maintenance. A failed candidate does not
replace the previous `latest` image, and tests cannot guarantee every account,
GPU, or experimental feature will work.

New images do not automatically update running containers. Finish active tasks
before updating, and back up the complete folder mapped to `/config`, including
hidden files. Keep the same mapping when recreating the container. Never share
one `/config` folder between running instances.

Closing a browser tab leaves the application running. Stopping or updating the
container interrupts active sessions.

## Security and experimental features

- Keep the WebUI on a trusted LAN or VPN; do not expose it directly to the internet.
- Protect `/config` and its backups: they can contain credentials and private keys.
- SSH keys are generated on first use, but host access is **not automatically authorized**. Authorizing the supplied root SSH configuration grants full host control.
- The application uses `--no-sandbox`, disabling Chromium's internal sandbox. Agent approval settings remain separate; do not treat the container as a strong security boundary.

Remote Mobile Control is experimental and depends on upstream compatibility
and account availability. See the [upstream feature documentation](https://github.com/ilysenko/codex-desktop-linux/tree/main/linux-features/remote-mobile-control).

## Credits

- [ChatGPT Community for Linux](https://github.com/ilysenko/codex-desktop-linux) — upstream application wrapper.
- [LinuxServer.io Selkies](https://docs.linuxserver.io/selkies/) — browser-based application streaming.

This repository provides the Docker packaging, build workflow, and Unraid
template. Third-party software and assets remain subject to their respective
licenses and terms.
