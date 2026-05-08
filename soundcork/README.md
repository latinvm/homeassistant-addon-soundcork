# SoundCork

Self-hosted replacement for the Bose SoundTouch cloud, packaged as a
Home Assistant add-on. Wraps
[`ghcr.io/latinvm/soundcork`](https://github.com/latinvm/soundcork) (a
fork of [`deborahgu/soundcork`](https://github.com/deborahgu/soundcork)
that adds optional HTTP Basic auth on `/admin` and `/mgmt`).

## What it does

Bose shut down the SoundTouch cloud on 6 May 2026. SoundCork emulates
the endpoints the speakers used to call so SoundTouch 10 / 20 / 30
keep working. This add-on runs that server inside Home Assistant OS so
you do not need a separate Docker host.

The add-on does **not** reconfigure speakers. The one-time speaker-side
procedure (USB stick, SSH, override config) is in the
**Documentation** tab.

## Configure

| Option | Required | Notes |
| --- | --- | --- |
| `base_url` | yes | URL the speakers will use to reach SoundCork. Usually `http://<your-ha-ip>:8000`. If you remap the host port on the **Network** tab, update `base_url` to match. See the Documentation tab for why. |
| `ADMIN_BASIC_AUTH_USER` | optional | HTTP Basic auth user for `/admin` and `/mgmt`. Leave blank with the password to disable auth on those routes. |
| `ADMIN_BASIC_AUTH_PASSWORD` | optional | Matching password. Masked in the UI. Set both to enable auth; leave both blank to disable. |
| `data_dir` | yes | Persistent path inside the container. Must be under `/data`. Default `/data/soundcork`. |

After **Save**, click **Start**. Logs appear on the **Log** tab.

## Open the UI

Once the add-on is running, open `http://<your-ha-ip>:8000/webui/` in a
browser. That is the human-facing console for managing accounts,
presets, and speakers. `/webui/` is **not** behind
`ADMIN_BASIC_AUTH_*`; only `/admin` and `/mgmt` are.

The bare `/` path returns a trivial 200 with no UI; that is by design,
not a misconfiguration. Other useful paths:

- `/webui/` -> main web UI (start here).
- `/admin/` -> per-device admin actions (switch a device to SoundCork,
  add device by id). Trailing slash required. Behind
  `ADMIN_BASIC_AUTH_*` when both are set.
- `/mgmt/...` -> JSON management API. Behind `ADMIN_BASIC_AUTH_*` when
  both are set.

`/docs`, `/redoc`, and `/openapi.json` are disabled by upstream and will
404. The Bose speakers themselves call other paths (`/marge/...`,
`/bmx/...`, account / source / preset endpoints). You do not browse
those manually.

## Where to file what

- A speaker behaves wrong, an endpoint returns the wrong shape, a
  protocol question: that is SoundCork itself, file at
  [latinvm/soundcork](https://github.com/latinvm/soundcork/issues) (or
  upstream at
  [deborahgu/soundcork](https://github.com/deborahgu/soundcork/issues)
  if the bug also reproduces there).
- The add-on will not install, the option schema rejects something it
  should accept, the upstream image needs bumping: file at
  [latinvm/homeassistant-addon-soundcork](https://github.com/latinvm/homeassistant-addon-soundcork/issues).

## License

MIT. Upstream SoundCork is also MIT.
