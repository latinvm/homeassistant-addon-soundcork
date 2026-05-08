# SoundCork add-on documentation

This is the long-form reference shown on the **Documentation** tab. The
Configuration tab is light on context; this is where the context lives.

## Which SoundCork this wraps, and why

The original SoundCork lives at
[`deborahgu/soundcork`](https://github.com/deborahgu/soundcork) and has
**no management authentication**: `/webui/`, `/admin/`, and `/mgmt/...`
are open to anyone who can reach the port. On a flat home LAN this is
usually fine; on a network with an IoT VLAN, a reverse proxy, or guest
devices, it is not.

This add-on currently pins the
[`optional-basic-auth-admin-mgmt`](https://github.com/latinvm/soundcork/tree/optional-basic-auth-admin-mgmt)
branch on the [`latinvm/soundcork`](https://github.com/latinvm/soundcork)
fork, which adds **optional** HTTP Basic auth on `/admin` and `/mgmt`
via two env vars (`ADMIN_BASIC_AUTH_USER` / `ADMIN_BASIC_AUTH_PASSWORD`).
Leaving both blank disables auth, matching upstream's open default. A
PR for this change is in flight upstream; once it lands, this add-on
will repoint at upstream's published image and pin a digest. Treat the
current image pin as a moving target until that happens.

For the rest of this document, "upstream" means the latinvm PR branch.

## Option reference

### `base_url` (required, string)

The URL the speaker will be told to call instead of the dead Bose cloud.
Format: `http://<host>:<port>` or `https://<host>:<port>`. Reachable from
the speakers' subnet, not just from your phone. Examples:

- `http://192.168.1.50:8000` if your HA host is at `192.168.1.50` and you
  expose port `8000` (the default).
- `https://soundcork.lan` if you have a reverse proxy with a local
  certificate.

The port in this URL must match the port mapped by the add-on. Default
mapping is host `8000` -> container `8000`. If you change the mapping
on the **Network** tab, change `base_url` to match.

> **Important: keep `base_url` in sync with the host port on the Network tab.**
>
> SoundCork advertises `base_url` to every speaker and uses it for link
> generation in its own web UI. There is no other source of truth for
> "where am I reachable" inside the container, so a wrong value here is
> the most common silent-failure mode.
>
> - The default `ports:` mapping in `config.yaml` is `8000/tcp: 8000`,
>   so the default `base_url` of `http://<HA-IP>:8000` is correct out of
>   the box.
> - The HA **Network** tab lets you remap the host port (the left side
>   of the mapping) to anything you like, or to blank to disable host
>   exposure entirely. The container-internal port stays `8000`.
> - If you change the host port (for example because port `8000` is
>   already taken on the HA host and you remap to `8123`), you **must**
>   update `base_url` to match (`http://<HA-IP>:8123`). The container
>   cannot detect this; the speakers will happily dial the wrong port
>   and fail silently with no error in the add-on log.
> - Do not add a `port` option here. The Network tab is the supported
>   mechanism. Keeping a single source of truth (the Network tab) and
>   one mirror (`base_url`) is the whole contract.

### `ADMIN_BASIC_AUTH_USER` and `ADMIN_BASIC_AUTH_PASSWORD` (optional, strings)

HTTP Basic auth credentials guarding `/admin` and `/mgmt`. The schema
marks the password as `password` so the supervisor masks it in the UI.

These are **optional**. If either is empty the auth shim short-circuits
and the routes are reachable without credentials, matching the open
default of `deborahgu/soundcork`. To turn auth on, set both. To turn it
off, blank both and restart.

The casing of these option keys is uppercase to match how the PR branch
documents the env vars. Upstream's `pydantic-settings` reads env vars
case-insensitively, so this is convention rather than a hard requirement.
Lowercase here would also work; the wrapper exports them uppercase
either way.

Speaker-facing routes (`/marge/...`, `/bmx/...`, account / source /
preset endpoints) are **not** behind this auth. Speakers reach the API
directly with no credentials, by design — adding auth there would
require reflashing every speaker.

### `data_dir` (required, string)

Path inside the container where SoundCork persists state. Must be under
`/data`. The add-on validates this on startup and refuses to run
otherwise: `/data` is the only path the supervisor mounts as a
persistent volume, and anything outside it is wiped on add-on update.

Default: `/data/soundcork`.

## URL paths exposed by SoundCork

| Path | Purpose |
| --- | --- |
| `/webui/` | Main human-facing web UI. Start here. Not gated by `ADMIN_BASIC_AUTH_*` in this build. |
| `/admin/` | Per-device admin actions (switch a device to SoundCork, add device by ID). Trailing slash required. Gated by `ADMIN_BASIC_AUTH_*` when both are set. |
| `/mgmt/...` | JSON management API (accounts, Spotify init/callback). Gated by `ADMIN_BASIC_AUTH_*` when both are set. |
| `/marge/...`, `/bmx/...`, account / source / preset endpoints | Called by the speakers themselves. Do not browse manually. |
| `/` | Trivial landing handler that returns 200 with no UI. By design, not a misconfiguration. |

`/docs` (FastAPI auto-generated Swagger) is **not** exposed by upstream
in this build; do not rely on it for endpoint discovery. Read the source
of `/app/soundcork/main.py` in the running container if you need an
authoritative endpoint list.

## Speaker-side procedure

The add-on serves the API. You still have to point your speakers at it.
This is a one-time per-speaker procedure and the add-on does not
automate it.

You will need:

- SSH access to the speaker (enabled via a USB stick that contains an
  empty `remote_services` file at the root of a FAT-formatted partition).
- The IP or hostname of your Home Assistant host (the value you put in
  `base_url`).

### 1. Enable SSH on the speaker

Format a USB stick as FAT32, create an empty file named `remote_services`
at the root, plug it into the speaker, and reboot the speaker. After
boot, SSH on port `17000` is open.

### 2. Connect

```sh
ssh -p 17000 root@<speaker-ip>
```

The default password is documented in the SoundCork upstream README.
Bose set it; this wrapper has nothing to do with it.

### 3. Override the SDK config

Edit `/mnt/nv/OverrideSdkPrivateCfg.xml` on the speaker. Replace
`<your-ha-host>` with the host your `base_url` resolves to:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<SdkPrivateCfg>
  <ServerEnvironment>
    <ServerName>your-ha-host</ServerName>
    <ServerPort>8000</ServerPort>
    <UseSsl>false</UseSsl>
  </ServerEnvironment>
</SdkPrivateCfg>
```

If you use HTTPS via a reverse proxy, set `UseSsl` to `true` and
`ServerPort` accordingly.

### 4. Reboot the speaker

It now talks to SoundCork instead of the Bose cloud.

For deeper protocol details, recovery if the override is wrong, and
device-discovery quirks, see the
[`deborahgu/soundcork`](https://github.com/deborahgu/soundcork) README
(the upstream of the fork this add-on currently tracks).

## Known limitations

- Only `amd64` and `aarch64` are supported. Upstream does not publish
  other architectures.
- The wrapper runs gunicorn as `root`. Upstream also runs as root in
  the currently-pinned branch image, so this is no longer a divergence,
  but it is worth knowing in case a future upstream change introduces a
  non-root user that the wrapper's `USER root` line would silently
  override.
- Spotify priming, Music Assistant integration, and multi-room features
  are out of scope for this wrapper. Track those upstream.
- The add-on does not configure DNS hijack or speakers. You apply the
  speaker-side procedure manually.

## Manual seeding (fallback)

SoundCork's web UI has a **Configure Account** flow that creates the
account / source / preset XML files on disk for you. Use that first.
The fallback documented in this section only matters when that flow
fails (the speaker rejects the generated config, the upstream import
errors out, you have a working set of files from another instance
you want to graft in, etc).

The add-on grants itself read/write access to the HAOS `share` folder.
On startup it looks at `/share/soundcork/seed/` and, if any files are
present, copies them recursively into `/data/`. The copy uses `cp -rn`,
so any file that already exists in `/data` is left untouched. Seeding
is one-shot insurance, not a sync.

### Layout

The contents of `/share/soundcork/seed/` are merged into `/data/` with
the same relative path. So if your `data_dir` option is the default
`/data/soundcork`, your seed files have to live one level deeper to land
in the right place:

```text
/share/soundcork/seed/soundcork/<accountId>/Sources.xml
  -> /data/soundcork/<accountId>/Sources.xml
```

If you set `data_dir` to plain `/data`, the layout is one-to-one:

```text
/share/soundcork/seed/<accountId>/Sources.xml
  -> /data/<accountId>/Sources.xml
```

Get this wrong and SoundCork will not find the files at the path it
reads from. The add-on does not move them for you and does not validate
that they ended up where SoundCork expects.

### What `<accountId>` is, and where to get it

The directory name is **not** something you choose. Upstream calls the
field "marge account UUID" but the format is a 1-to-20-digit decimal
number (constraint: `^\d{1,20}$`), supplied by the speaker firmware in
its `info.xml`. SoundCork uses the value the speaker reports; if the
seed directory uses a different number, SoundCork will write fresh
files under the speaker's real id and ignore your seed.

Three ways to learn the right number:

1. **From a previous working SoundCork install.** If you are seeding
   from a backup, the directory name on disk *is* the account id. Use
   the same name in `/share/soundcork/seed/`.
2. **Let SoundCork create it once, then re-use the name.** Boot the
   speaker against this add-on (after the speaker-side procedure
   above). On the first request from the speaker, SoundCork calls
   `create_account(...)` with the speaker's reported id and creates
   `<data_dir>/<accountId>/`. Stop the add-on, mirror that directory
   name into `/share/soundcork/seed/...`, and overwrite or extend the
   files there.
3. **From the speaker itself.** SSH onto the speaker (same procedure as
   the override config) and grep for `margeAccountUUID` under
   `/var/volatile/lib/Bose/PersistenceDataRoot/BoseApp-Persistence/1`.
   The numeric value of that element is the account id.

If you have multiple Bose accounts (rare), each has its own id and its
own directory under `data_dir`. Seed each one separately.

### How to use it

1. Stop the add-on.
2. Use the **Samba share** add-on, **Studio Code Server**, the HAOS
   File editor, or `scp` to drop your XMLs under
   `/share/soundcork/seed/...` matching the layout above.
3. Start the add-on. The startup log lists each filename being copied,
   for example:

   ```text
   [soundcork] seeding 3 file(s) from /share/soundcork/seed into /data (existing files preserved)
   [soundcork] seed: soundcork/<accountId>/Accounts.xml
   [soundcork] seed: soundcork/<accountId>/Sources.xml
   [soundcork] seed: soundcork/<accountId>/Recents.xml
   ```

4. Confirm in `/webui/` that the accounts / speakers / presets show up.

### Caveats

- The wrapper does no schema validation. Garbage XML in `/share` becomes
  garbage XML in `/data` and SoundCork will fail to parse it. You are
  responsible for the file contents.
- File contents are never written to the log; only filenames are.
- Existing `/data` files are never overwritten. If you need to replace
  a bad file, delete it from `/data` first (Studio Code Server, the
  Samba add-on, etc.) and then start the add-on so the seed import
  fills the gap.
- It is safe to leave the seed directory in place across restarts. Each
  run re-imports only the files that are missing in `/data`.

## Updating the upstream image

The Dockerfile currently pins a **mutable branch tag** while the basic-
auth feature is in PR review:

```dockerfile
FROM ghcr.io/latinvm/soundcork:optional-basic-auth-admin-mgmt
```

This is deliberate: the PR branch is rebuilt as it iterates, and the
add-on needs to follow. The trade-off is loss of reproducibility — two
installs of the same add-on `version:` can resolve to different image
contents. Acceptable for a preview, not acceptable long-term.

To pull the current branch build into a running install:

1. In the HA add-on UI, three-dot menu on the SoundCork add-on →
   **Rebuild**. This re-resolves the tag and rebuilds the wrapper
   layer. (If your HA frontend doesn't surface Rebuild reliably,
   uninstall and reinstall — slower but unambiguous.)

To follow a brand-new branch image after a `version:` bump:

1. Bump `version:` in `soundcork/config.yaml`.
2. Push to `main`. HA shows an **Update** badge on the installed
   add-on within a few minutes; clicking Update re-resolves the tag.

When the upstream PR lands and the basic-auth feature is in
[`deborahgu/soundcork`](https://github.com/deborahgu/soundcork)'s
published image:

1. Change the `FROM` line to
   `ghcr.io/deborahgu/soundcork@sha256:<index-digest>`. Read the index
   digest with:

   ```sh
   docker buildx imagetools inspect ghcr.io/deborahgu/soundcork:main \
     | head -3
   ```

   Use the multi-arch index digest, not a per-arch sub-digest, so a
   single line resolves on both `amd64` and `aarch64`.
2. Bump `version:` and update the comment block at the top of the
   Dockerfile to drop the "tag-tracking" framing.
3. From that point forward, the bump procedure is "edit digest, bump
   version, push" — the same one-line discipline used by most pinned-
   digest HA add-ons.

## Assumptions

These were verified against the branch image
`ghcr.io/latinvm/soundcork:optional-basic-auth-admin-mgmt` on
2026-05-08:

- `WORKDIR` is `/app/soundcork` and the gunicorn module path is
  `main:app` (not `app:app` as one issue thread suggested). Confirmed.
- `gunicorn_conf.py` lives at the WORKDIR, which is why the `-c
  gunicorn_conf.py` argument resolves.
- Listening port is `8000`. Mapped to host `8000` by default in
  `config.yaml`.
- Env var keys are read case-insensitively by `pydantic-settings`. The
  wrapper exports the casing documented in the PR
  (lowercase `base_url` / `data_dir`, uppercase `ADMIN_BASIC_AUTH_*`).
- The auth shim treats either `ADMIN_BASIC_AUTH_USER` or
  `ADMIN_BASIC_AUTH_PASSWORD` being empty as "auth disabled" — same
  open posture as `deborahgu/soundcork` upstream.
