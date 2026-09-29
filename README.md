# ChatGPT Community for Unraid

**Run ChatGPT Community on your Unraid server and use it from a web browser.**

Open one application instead of a full remote desktop. Your settings and local
application data are stored in your Unraid appdata folder, so they can survive
container updates.

> **Unofficial community project.** This is not an official OpenAI, Unraid, or
> LinuxServer.io product. It packages
> [ChatGPT Community for Linux](https://github.com/ilysenko/codex-desktop-linux)
> for use on Unraid.

[Installation](#installation) · [Updates](#updates) ·
[Backups](#backups-and-rollback) · [Troubleshooting](#troubleshooting) ·
[Security](#security)

## What does it do?

- Opens ChatGPT Community directly in your browser, without a desktop taskbar or start menu.
- Keeps local settings, sign-in data, workspaces, and SSH keys in persistent storage.
- Supports optional Intel/AMD GPU acceleration for the browser stream.
- Includes experimental Remote Mobile Control support.
- Can optionally connect to your Unraid server over SSH for server-management tasks.
- Builds and tests new container images automatically when upstream updates are detected.

**This is a desktop application streamed to your browser**, not a replacement
for the ChatGPT website or a locally hosted AI model. Running the container does
not make AI processing offline or provide free access to paid services. Account
requirements, usage limits, and feature availability still apply.

The default installation does **not** automatically grant access to your
Unraid host. SSH access requires a separate authorization step.

## Before you begin

You will need:

- An Unraid server with Docker enabled and Community Applications available in the **Apps** tab.
- A 64-bit Intel or AMD system. This repository publishes `linux/amd64` images, not ARM images.
- An internet connection to download the image and use online services.
- An account that can use the application features you want.
- Available space in both Docker storage and your appdata storage.

A dedicated graphics card is **not required**. A compatible Intel or AMD GPU is
optional. Resource use depends on your screen resolution, streaming settings,
open projects, and active tasks; this project does not claim a measured minimum
RAM requirement.

> **Keep access on your home network or a trusted VPN. Set a WebUI password
> before using the container. Do not forward its port directly to the internet.**

## Installation

You do not need to clone the repository, compile the application, or create
your own GitHub workflow.

### 1. Add the installation template

The template is an installation form that tells Unraid which image, settings,
and folders to use.

Open the **Unraid web interface**, then open its **Terminal**. Paste this block:

```bash
mkdir -p /boot/config/plugins/community.applications/private/ChatGPT-Community
curl --fail --location --retry 3 \
  https://raw.githubusercontent.com/jeffreymooiweer/chatgpt-community-unraid/main/unraid/chatgpt-community.xml \
  -o /boot/config/plugins/community.applications/private/ChatGPT-Community/chatgpt-community.xml
```

This downloads the template to your Unraid flash drive. It does not install or
start the container, authorize SSH access, or change your storage configuration.
Running it again replaces the downloaded template.

Return to **Apps**, refresh the page, and look under **Private Apps** for
**ChatGPT-Community**. Choose **Install**.

“Private Apps” describes how the template is registered on your server. It does
not mean the application is automatically secure or that a GitHub account is
required. This installation method does not depend on a public Apps listing.

See the [Community Applications maintainer's explanation of private templates](https://forums.unraid.net/topic/112170-allow-template-repositories-to-be-hosted-from-other-sources/)
if the template does not appear.

### 2. Review the settings

Change these fields **before** clicking Apply:

| Setting | What to enter |
| --- | --- |
| WebUI password | A strong, unique password. **Do not leave it blank.** |
| WebUI username | Leave `abc`, or choose a different WebUI username. |
| Appdata | Usually `/mnt/user/appdata/chatgpt-community`. Existing users must keep their current path. |
| WebUI HTTPS port | Leave `33443` unless another container already uses it. |
| Unraid Host | Your own server's local IP address. The template's `192.168.1.6` is an example, not necessarily your address. |
| Timezone | Your timezone. The template defaults to `Europe/Amsterdam`; this may be under Advanced View. |
| GPU | Keep `/dev/dri` only if your server has this device. Otherwise remove this device entry. |

Keep these defaults unless you know why you need to change them:

- **Repository:** `ghcr.io/jeffreymooiweer/chatgpt-community-unraid:latest`
- **Network:** Bridge
- **Privileged:** Off
- **PUID / PGID:** `99` / `100`
- **Container path for appdata:** `/config`

The template also includes `--shm-size=1g` and a container hostname in **Extra
Parameters**. Keep the shared-memory setting. New users may choose their own
container hostname; existing users should keep theirs unchanged.

Do not add the Docker socket or mount your whole server filesystem just to make
the app work.

### 3. Start the app

Click **Apply** and allow Unraid to download and start the container.

Go to **Docker**, click the **ChatGPT-Community** icon, then select **WebUI**.
The default address is:

```text
https://YOUR-SERVER-IP:33443
```

Replace `YOUR-SERVER-IP` with your Unraid server's address. If you changed the
host port, use that port instead.

The default HTTPS setup uses a self-signed certificate, so your browser may show
a certificate warning. Only proceed after confirming that the address is your
own server on your trusted network. Do not ignore unexpected certificate
warnings on unrelated sites. See the [Selkies base-image documentation](https://docs.linuxserver.io/images/docker-baseimage-selkies/).

There are **two separate sign-ins**:

1. **WebUI login:** the username and password you entered in the Unraid template.
2. **Application login:** your account inside ChatGPT Community.

An included Chromium browser may open for sign-in or external links.

### 4. Check that everything works

- The WebUI asks for your configured password.
- The application opens and you can sign in.
- Your appdata folder is mapped to `/config`.
- Reopening the WebUI returns to the running application.

Closing your browser tab does **not** stop the container or its background
tasks. Updating, restarting, or stopping the container **does** interrupt the
application and any active session.

## Optional: let the app manage your Unraid server

**Skip this section if you only want to use the application.**

SSH is a way to run commands on another computer. Here, it lets the application
connect from its container to the Unraid host.

> **Important:** the provided SSH configuration uses `root`, which has full
> control over Unraid. Once authorized, this connection can change settings,
> stop containers, and delete data. Treat it as administrator access—not as a
> harmless chat feature. Agent instructions are not a technical security boundary.

At first startup, the container creates an SSH key pair in `/config/.ssh` if
one does not already exist. It does **not** add that key to Unraid's authorized
keys automatically.

<details>
<summary>Advanced setup: authorize and test SSH access</summary>

Make sure SSH is enabled on the Unraid host and that **Unraid Host** was set
correctly before the container's first start.

In the **Unraid Terminal**, display the container's public key:

```bash
docker exec -u abc ChatGPT-Community cat /config/.ssh/id_ed25519.pub
```

Only the file ending in **`.pub`** is the public key. Never share or upload
`id_ed25519`, which is the private key.

If you deliberately want to grant root access, append the public key as its own
line in the host's `/root/.ssh/authorized_keys`. Preserve any existing keys and
restrict permissions to `700` for `/root/.ssh` and `600` for the file.

Unraid recreates parts of its system filesystem at boot. A change to
`/root/.ssh/authorized_keys` alone should not be assumed to survive a reboot.
Use a persistence method appropriate to your Unraid version and verify access
again after rebooting. This image does not configure host-side persistence.

Test the connection from the Unraid Terminal:

```bash
docker exec -u abc ChatGPT-Community ssh unraid 'hostname; id'
```

The expected result is your Unraid hostname and a user identity containing
`uid=0(root)`. This command only reads the hostname and current user identity.

The `unraid` alias is stored in `/config/.ssh/config`. Changing the
`UNRAID_HOST` variable later does **not** rewrite an existing SSH configuration;
inspect the `HostName` entry if your server address changes. Do not delete the
whole appdata folder to fix an address.

The generated configuration accepts a previously unknown host key on first
connection. Confirm the host identity through a trusted channel; do not
automatically remove a stored host key when SSH warns that it has changed.

A starter workspace is available at `/config/workspace/unraid`, with an
`AGENTS.md` file reminding the agent to inspect before changing the server.

**Never ask an agent running inside this container to stop or update its own
container.** Finish its work first, then perform maintenance from the Unraid UI.

</details>

## Updates

There are two separate parts to updating:

### Automatic image builds

The [GitHub workflow](.github/workflows/build.yml) is scheduled to:

1. Check the Community Linux project and the official application package every six hours.
2. Build a candidate image when either has changed.
3. Validate the package and run automated tests.
4. Publish the tested image as `latest` only after the required checks pass.
5. Record the successfully published upstream versions in the repository.

A separate weekly build refreshes the image even when those versions have not
changed. Scheduled runs are not an instant notification service; allow time for
GitHub scheduling, building, and testing.

An upstream update is **not guaranteed to remain compatible**. If a build or
test fails, that candidate is not published as `latest`; the previous published
image remains available. Some failures require a maintainer to update the code.

Tests cover migration, application startup in X11 and Wayland CPU modes, HTTPS,
and selected data surviving a restart. They do not prove that every account,
GPU, sign-in flow, or Remote Mobile Control feature will work.

### Installing an update on Unraid

Publication does not automatically replace your running container.

1. Finish active tasks.
2. Make a current appdata backup.
3. Use the Docker tab's update check.
4. Apply the available update for **ChatGPT-Community**.
5. Reopen the WebUI and check your login, settings, and any SSH connection.

A separately configured Unraid auto-update plugin may install updates for you,
but that is **not configured by this repository**. Consider the risk of
interrupting an active task before enabling unattended restarts.

Use container image updates for this installation, rather than installing
packages or an application updater inside the running container.

## Backups and rollback

Your persistent data lives in the host folder mapped to `/config`:

```text
/mnt/user/appdata/chatgpt-community
```

Use your actual path if you changed it. This folder can contain application
settings, account credentials, local task data, workspaces, SSH keys, and remote
device information.

For a consistent backup:

1. Finish active work and stop this container from Unraid.
2. Back up the **entire appdata folder, including hidden files**, to a separate protected location.
3. Save the container template/settings and note the installed image version or digest.
4. Start the container again.

These are maintenance instructions—not actions performed automatically by the
image. Backing up this folder does not back up your entire Unraid server,
external projects, or all cloud-side account data.

**Treat backups as sensitive. Never upload them to GitHub or attach them to an issue.**

Each successful build publishes a unique `build-...` tag alongside `latest`.
If an update causes trouble, a previous available tag can be selected in the
Unraid **Repository** field:

```text
ghcr.io/jeffreymooiweer/chatgpt-community-unraid:build-REPLACE-WITH-AN-ACTUAL-TAG
```

Find actual tags on the [container package page](https://github.com/jeffreymooiweer/chatgpt-community-unraid/pkgs/container/chatgpt-community-unraid).
Do not paste the placeholder above as a real tag.

Stop the container before restoring data. Preserve a copy of the current
appdata first, then restore a matching pre-update backup if needed: an older
image may not understand data changed by a newer version.

Never run two containers against the same appdata folder.

## GPU acceleration

A compatible Intel/AMD GPU can help render and encode the browser stream.
It does **not** make OpenAI's cloud models run on your GPU.

- Map `/dev/dri` into the container when it exists on the host.
- Leave automatic GPU selection enabled initially.
- Without that device, remove the mapping and use CPU rendering.
- Actual acceleration depends on the host driver, device access, and supported codecs.

The template does not configure NVIDIA GPU support. Do not assume an NVIDIA
card will work through the Intel/AMD device mapping.

<details>
<summary>Advanced display settings</summary>

These variables can be added or edited in the Unraid container settings:

| Variable | Default | Purpose |
| --- | --- | --- |
| `PIXELFLUX_WAYLAND` | `true` | Set `false` to try the alternative X11 display backend. |
| `AUTO_GPU` | `true` | Automatic GPU selection; set `false` to disable selection. |
| `SELKIES_FRAMERATE` | `30` | Browser-stream frame-rate cap. |
| `SELKIES_UI_SHOW_SIDEBAR` | `false` | Set `true` to show streaming settings and diagnostics. |
| `DRINODE` | Unset | Override the rendering device only when needed. |
| `DRI_NODE` | Unset | Override the encoding device only when needed. |

Applying container settings restarts the container. Finish active work first.

Intel/AMD FullColor 4:4:4 is disabled by default to avoid an unsupported
hardware-encoding path falling back to software. A GPU being visible is not
proof that the stream is being hardware-encoded.

</details>

## Experimental Remote Mobile Control

This image enables the upstream `remote-mobile-control` feature. Availability
still depends on the application version, your account, and upstream services.

It is separate from opening this container's WebUI in a phone browser, and
separate from granting SSH access to Unraid. Successful image tests do not
guarantee pairing or account-side access.

See the [upstream feature documentation](https://github.com/ilysenko/codex-desktop-linux/tree/main/linux-features/remote-mobile-control)
for its current requirements and limitations. Do not open extra router ports
just because a feature is missing.

## Upgrading an older Webtop-based installation

<details>
<summary>Migration notes for existing users</summary>

Back up first and finish any active agent task.

Keep the existing container name, hostname, appdata-to-`/config` mapping,
PUID, and PGID. Add a strong `PASSWORD` if one is not already configured.
Add `/dev/dri` only when appropriate for your host.

Updating the downloaded template does **not** automatically add new variables
or device mappings to an already installed container. Review its settings under
**Docker → Edit**.

The migration replaces managed window-manager autostart files and archives the
old files under:

```text
/config/.local/state/chatgpt-community/migration-single-app-v1/
```

It removes the old ChatGPT XFCE autostart entry after archiving it. It does not
delete the existing `.codex` or `.config/Codex` profiles, SSH identity,
`known_hosts`, keyring data, Remote device keys, existing SSH configuration,
or your edited workspace `AGENTS.md`.

Preserving those files cannot guarantee that upstream or account-side changes
will never require a new sign-in or pairing.

</details>

## Troubleshooting

| Problem | Start here |
| --- | --- |
| The template is not visible | Confirm the download succeeded, then refresh Apps and check Private Apps. |
| Image download says denied or unauthorized | Check the image name and whether the GHCR package is accessible. A public source repository alone does not guarantee a public container package. |
| The WebUI will not open | Use `https://`, confirm the host port, check that the container is running, and try from the same local network. |
| No WebUI password prompt | Check that `PASSWORD` is set. A browser may reuse an existing login; test in a private window. |
| Container fails because `/dev/dri` is missing | Remove the GPU device entry if the host does not have it. |
| Blank screen or display trouble | Read the startup log. After finishing active tasks, try `PIXELFLUX_WAYLAND=false`. |
| SSH says “Permission denied” | SSH authorization is optional and separate from installation. Verify the public key on the host. |
| SSH uses the wrong server address | Inspect the saved `/config/.ssh/config`; changing the variable does not overwrite it. |
| Settings or login disappeared | Check that the original appdata folder is still mapped to `/config`. Do not delete it. |
| CPU/GPU activity continues after closing the tab | The application and background tasks keep running while the container runs. |
| No update appears in Unraid | Check the Actions result and run Unraid's update check. A failed candidate is not published. |

For recent logs, run these commands in the **Unraid Terminal**. Replace the
container name if you changed it:

```bash
docker logs --tail 100 ChatGPT-Community
docker exec ChatGPT-Community tail -n 100 /config/.cache/chatgpt-community/startup.log
```

For an advanced Intel/AMD device check, if `renderD128` exists:

```bash
docker exec -u abc ChatGPT-Community vainfo --display drm --device /dev/dri/renderD128
```

Before [opening an issue](https://github.com/jeffreymooiweer/chatgpt-community-unraid/issues),
include your Unraid version, image tag/digest, GPU if applicable, what you
expected, and the relevant error. Remove passwords, tokens, private keys, and
personal information from logs and screenshots.

## Security

- Keep the WebUI on a trusted LAN or VPN. Its built-in password is not a reason to expose it directly to the internet.
- Anyone who can use your logged-in WebUI may be able to act through your account and connected tools.
- Do not enable Privileged mode or mount `/var/run/docker.sock` for normal use.
- Only authorize root SSH if you understand and need it. A container holding a root SSH key can control the host.
- Keep approval requirements for destructive actions. Written instructions alone cannot prevent misuse.
- Keep appdata and backups private, and review third-party integrations before granting access.

This image starts the application with `--no-sandbox`, which disables
Chromium's internal sandbox. It does not disable the agent's approval settings,
but it is a security trade-off. Do not treat the container as a strong isolation
boundary, particularly after granting host SSH access.

## Credits and project status

Built on:

- [ChatGPT Community for Linux](https://github.com/ilysenko/codex-desktop-linux) — the upstream community application wrapper.
- [LinuxServer.io Selkies](https://docs.linuxserver.io/selkies/) — browser-based application streaming.
- [Unraid](https://unraid.net/) — the target server platform.

This repository provides the Unraid packaging, template, persistent-data setup,
and build workflow. It includes a narrow compatibility patch for Remote Mobile
Control bundle discovery; the access checks and critical-patch validation remain
in place.

Third-party software, names, and assets remain subject to their respective
licenses and terms. This project does not grant rights to OpenAI software or
services and does not promise compatibility with every future upstream release.

