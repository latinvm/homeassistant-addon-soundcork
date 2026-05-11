# SoundCork add-on documentation

This is the long-form reference shown on the **Documentation** tab. The
Configuration tab is light on context; this is where the context lives.

## Which SoundCork this wraps

This add-on pins `ghcr.io/deborahgu/soundcork:main`, the image
published from the [`deborahgu/soundcork`](https://github.com/deborahgu/soundcork)
default branch. There is **no management authentication**: `/miniapp`,
`/admin/`, and `/mgmt/...` are open to anyone who can reach the port.

That is intentional, not an oversight. The destructive `/admin`
actions (switch a device to SoundCork, add device by id) work by
SSH-ing into the speaker as `root` over the password-less root shell
that the one-time `remote_services` USB unlock leaves open. Anyone who
can reach `/admin` can also reach the speaker on port 22 and run the
same commands directly, so HTTP auth on top would be defence in depth
rather than a real boundary. Treat the SoundCork port as you treat
speaker port 22 — only expose it to networks you trust.

For the rest of this document, "upstream" means
[`deborahgu/soundcork`](https://github.com/deborahgu/soundcork).

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
>   with no error from the container itself. The wrapper logs the
>   resolved `base_url` once on startup (`[soundcork] base_url=... data_dir=...`)
>   so you can eyeball it against the Network tab.
> - Do not add a `port` option here. The Network tab is the supported
>   mechanism. Keeping a single source of truth (the Network tab) and
>   one mirror (`base_url`) is the whole contract.

### `data_dir` (required, string)

Path inside the container where SoundCork persists state. Must be under
`/data`. The add-on validates this on startup and refuses to run
otherwise: `/data` is the only path the supervisor mounts as a
persistent volume, and anything outside it is wiped on add-on update.

Default: `/data/soundcork`.

## URL paths exposed by SoundCork

| Path | Purpose |
| --- | --- |
| `/` | 303 redirect. Lands on `/admin/` while any speaker still needs to be switched to SoundCork, and on `/miniapp` once they all are. |
| `/miniapp`, `/miniapp/dashboard`, `/miniapp/login`, `/miniapp/play`, `/miniapp/stop`, etc. | Human-facing console for play / stop / presets / device selection once speakers are configured. `/miniapp/dashboard` is the main page. |
| `/admin/` | Per-device admin actions (switch a device to SoundCork, add device by ID). Trailing slash required. |
| `/mgmt/spotify/init`, `/mgmt/spotify/callback`, `/mgmt/spotify/confirm`, `/mgmt/spotify/accounts` | Spotify account JSON management endpoints. |
| `/scan`, `/scan_recents`, `/add_device/{id}`, `/marge/...`, `/bmx/...`, `/media/...`, `/updates/soundtouch`, `/v1/scmudc/...`, `/v1/stapp/...` | Called by the speakers themselves (and a couple of setup helpers `/admin` calls into). Do not browse manually. |

This add-on deliberately does **not** add a sidebar link to
`/miniapp/dashboard`. The dashboard is useful for setup and the
occasional manual play / stop, but it is not a daily-driver UI;
day-to-day playback should run through the Bose app or whatever
SoundTouch integration you use, not through the miniapp.

None of these routes are authenticated. See "Which SoundCork this
wraps" above for why HTTP auth is not the right boundary here.

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
boot, SSH on port `22` is open as `root` with no password. SoundCork's
admin actions (`/admin/switchToSoundcork/{id}` and
`/admin/addDevice/{id}`) connect on the same port; the `Reachable`
column in `/admin/` is literally a port-22 TCP probe.

### 2. Connect

```sh
ssh root@<speaker-ip>
```

No password. This is set by Bose firmware; the wrapper has nothing to
do with it. If you see `Permission denied` instead of being dropped at
a shell, the USB-stick unlock did not take — re-check the file is
named exactly `remote_services` (no extension, no leading dot) and
sits at the root of the FAT32 partition.

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
[`deborahgu/soundcork`](https://github.com/deborahgu/soundcork) README.

## Known limitations

- Only `amd64` and `aarch64` are supported. Upstream does not publish
  other architectures.
- The wrapper runs gunicorn as `root`. Upstream also runs as root in
  the currently-pinned image, so this is no longer a divergence, but
  it is worth knowing in case a future upstream change introduces a
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

The Dockerfile pins the upstream moving tag:

```dockerfile
FROM ghcr.io/deborahgu/soundcork:main
```

`:main` is mutable: each push to `main` in `deborahgu/soundcork`
republishes the image under the same tag.

To pull a freshly-rebuilt image into a running install without a
`version:` bump:

1. In the HA add-on UI, three-dot menu on the SoundCork add-on →
   **Rebuild**. Re-resolves the tag and rebuilds the wrapper layer.
   If Rebuild misbehaves on your HA frontend version, uninstall and
   reinstall — slower but unambiguous.

To ship a wrapper change (config schema, run.sh, Dockerfile) and have
HA show an **Update** badge:

1. Bump `version:` in `soundcork/config.yaml`.
2. Add a `CHANGELOG.md` entry describing what changed (the visible
   shape of the user contract: option keys, defaults, wrapper
   behaviour). Bumps that exist only to re-pull a moving tag don't
   need a changelog entry.
3. Push to `main`. HA shows the Update badge on the installed add-on
   within a few minutes.

To switch to a digest pin when you want reproducible installs, read
the index digest with:

```sh
docker buildx imagetools inspect \
  ghcr.io/deborahgu/soundcork:main | head -3
```

Use the multi-arch index digest, not a per-arch sub-digest. Replace
the `:tag` portion of `FROM` with `@sha256:...`, bump `version:`, and
update the comment block at the top of the Dockerfile. Upstream also
publishes immutable `sha-<short>` tags per commit if you want a
human-readable pin instead of a digest.

## Assumptions

These were verified against the upstream image
`ghcr.io/deborahgu/soundcork:main` on 2026-05-11:

- `WORKDIR` is `/app/soundcork` and the gunicorn module path is
  `main:app` (not `app:app` as one issue thread suggested). Confirmed.
- `gunicorn_conf.py` lives at the WORKDIR, which is why the `-c
  gunicorn_conf.py` argument resolves.
- Listening port is `8000`. Mapped to host `8000` by default in
  `config.yaml`.
- Env var keys are read case-insensitively by `pydantic-settings`. The
  wrapper exports lowercase `base_url` and `data_dir`.
