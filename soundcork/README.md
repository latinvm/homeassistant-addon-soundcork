# SoundCork

Self-hosted replacement for the Bose SoundTouch cloud, packaged as a
Home Assistant add-on. Wraps
[`ghcr.io/deborahgu/soundcork`](https://github.com/deborahgu/soundcork).

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
| `data_dir` | yes | Persistent path inside the container. Must be under `/data`. Default `/data/soundcork`. |

After **Save**, click **Start**. Logs appear on the **Log** tab.

## Open the UI

Once the add-on is running, open `http://<your-ha-ip>:8000/webui/` in a
browser. That is the human-facing console for managing accounts,
presets, and speakers.

The bare `/` path returns a trivial 200 with no UI; that is by design,
not a misconfiguration. Other useful paths:

- `/webui/` -> main web UI (start here).
- `/admin/` -> per-device admin actions (switch a device to SoundCork,
  add device by id). Trailing slash required.
- `/mgmt/...` -> JSON management API (Spotify init / callback).

`/docs`, `/redoc`, and `/openapi.json` are disabled by upstream and will
404. The Bose speakers themselves call other paths (`/marge/...`,
`/bmx/...`, account / source / preset endpoints). You do not browse
those manually.

None of these routes are authenticated. SoundCork ships open by
design: the destructive `/admin` actions only work against speakers
that already permit password-less root SSH from anywhere on the same
LAN (the one-time `remote_services` USB unlock documented in the
Documentation tab), so HTTP auth on top would not change the security
boundary. Treat the SoundCork port as you treat speaker port 22 — only
expose it to networks you trust.

## Where to file what

- A speaker behaves wrong, an endpoint returns the wrong shape, a
  protocol question: that is SoundCork itself, file at
  [deborahgu/soundcork](https://github.com/deborahgu/soundcork/issues).
- The add-on will not install, the option schema rejects something it
  should accept, the upstream image needs bumping: file at
  [latinvm/homeassistant-addon-soundcork](https://github.com/latinvm/homeassistant-addon-soundcork/issues).

## License

MIT. Upstream SoundCork is also MIT.
