# SoundCork

Self-hosted replacement for the Bose SoundTouch cloud, packaged as a
Home Assistant add-on. Wraps the upstream image
[`ghcr.io/timvw/soundcork`](https://github.com/timvw/soundcork) without
modification.

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
| `MGMT_USERNAME` | yes | Admin user for SoundCork's management UI. |
| `MGMT_PASSWORD` | yes | Admin password. Masked in the UI. Default is empty; you must set one. |
| `data_dir` | yes | Persistent path inside the container. Must be under `/data`. Default `/data/soundcork`. |
| `OIDC_ISSUER_URL` | optional | If you set any OIDC field, you must set all three. |
| `OIDC_CLIENT_ID` | optional | See above. |
| `OIDC_CLIENT_SECRET` | optional | Masked. See above. |

After **Save**, click **Start**. Logs appear on the **Log** tab.

## Where to file what

- A speaker behaves wrong, an endpoint returns the wrong shape, a feature
  is missing: that is SoundCork itself, file at
  [timvw/soundcork](https://github.com/timvw/soundcork/issues).
- The add-on will not install, the option schema rejects something it
  should accept, the upstream image needs bumping: file at
  [latinvm/homeassistant-addon-soundcork](https://github.com/latinvm/homeassistant-addon-soundcork/issues).

## License

MIT. Upstream SoundCork is also MIT.
