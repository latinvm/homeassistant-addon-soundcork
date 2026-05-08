# SoundCork add-on documentation

This is the long-form reference shown on the **Documentation** tab. The
Configuration tab is light on context; this is where the context lives.

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

### `MGMT_USERNAME` and `MGMT_PASSWORD` (required, strings)

Credentials for SoundCork's management UI. The schema marks the password
as `password` so the supervisor masks it in the UI. The default password
is empty; the add-on refuses to start until you set one.

The casing of these option keys is uppercase to match how the upstream
README documents them. Upstream's `pydantic-settings` reads env vars
case-insensitively, so this is convention rather than a hard requirement.
Lowercase here would also work; the wrapper exports them uppercase
either way.

### `data_dir` (required, string)

Path inside the container where SoundCork persists state. Must be under
`/data`. The add-on validates this on startup and refuses to run
otherwise: `/data` is the only path the supervisor mounts as a
persistent volume, and anything outside it is wiped on add-on update.

Default: `/data/soundcork`.

### `OIDC_ISSUER_URL`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` (optional)

OIDC fields are all-or-nothing. Leave all three blank to keep
SoundCork's built-in `MGMT_USERNAME`/`MGMT_PASSWORD` auth, or set all
three to delegate auth to your IdP. The add-on refuses to start with
some-but-not-all set: upstream's enable check is a boolean AND across the
three values, which means a half-configured OIDC silently runs as
unauthenticated, which is worse than a clear startup failure.

## URL paths exposed by SoundCork

| Path | Purpose |
| --- | --- |
| `/webui/` | Main human-facing web UI. Start here. Login uses `MGMT_USERNAME` / `MGMT_PASSWORD`. |
| `/admin/` | Per-device admin actions (switch a device to SoundCork, add device by ID). Trailing slash required. |
| `/mgmt/...` | JSON management API (accounts, Spotify init/callback). |
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
device-discovery quirks, see the upstream
[`timvw/soundcork`](https://github.com/timvw/soundcork) README.

## Known limitations

- Only `amd64` and `aarch64` are supported. Upstream does not publish
  other architectures.
- The wrapper runs gunicorn as `root`, not as upstream's `appuser`. The
  alternative (`gosu`/`setpriv` to drop privileges in `run.sh` after
  `chown`-ing `/data`) added complexity without buying real isolation
  inside an HA add-on. Documented here so it is not surprising.
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

## Bumping the pinned upstream image

The Dockerfile pins `ghcr.io/timvw/soundcork` by digest:

```dockerfile
FROM ghcr.io/timvw/soundcork@sha256:78f0b45cf1bc4cbad97b4b96c177c4bc3c8fe30f228514767be3c4393cfba4d7
```

The `:main` tag is unstable on purpose: upstream pushes it on every
merge. Pinning the digest is what makes a given add-on version
reproducible.

To bump:

1. Pull the current `:main`:

   ```sh
   docker pull ghcr.io/timvw/soundcork:main
   ```

2. Read its multi-arch index digest:

   ```sh
   docker buildx imagetools inspect ghcr.io/timvw/soundcork:main \
     | head -3
   ```

   The first line ends with `Digest: sha256:...`. That is the value to
   paste into the Dockerfile. Use the index digest (not a per-arch
   sub-digest) so a single line still resolves on both `amd64` and
   `aarch64`.

3. Edit `soundcork/Dockerfile` and replace the `@sha256:...` portion.

4. Bump `version:` in `soundcork/config.yaml`. Add a `CHANGELOG.md`
   entry that includes the new digest and a one-line summary of why
   you bumped (security fix, feature you wanted, drift sync).

5. Open a PR. CI runs hadolint + shellcheck only; the supervisor builds
   the image at install time on the user's host.

## Assumptions

These were verified by inspecting the pinned image with `docker inspect`
on 2026-05-08:

- Upstream user is `appuser` (uid 1000); this wrapper runs as root
  instead. See "Known limitations".
- `WORKDIR` is `/app/soundcork` and the gunicorn module path is
  `main:app` (not `app:app` as one issue thread suggested). Confirmed.
- `gunicorn_conf.py` lives at the WORKDIR, which is why the `-c
  gunicorn_conf.py` argument resolves.
- Listening port is `8000`. Mapped to host `8000` by default in
  `config.yaml`.
- Env var keys are read case-insensitively by `pydantic-settings`. The
  wrapper exports the casing documented upstream
  (lowercase `base_url` / `data_dir`, uppercase `MGMT_*` and `OIDC_*`).
