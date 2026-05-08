# SoundCork add-on for Home Assistant

A thin Home Assistant add-on that runs [SoundCork](https://github.com/latinvm/soundcork)
on Home Assistant OS so Bose SoundTouch 10 / 20 / 30 speakers keep
working after Bose shut down the SoundTouch cloud on 6 May 2026. The
fork adds optional HTTP Basic auth on `/admin` and `/mgmt`.

## Quick install

[![Open your Home Assistant instance and show the dialog to add an add-on repository.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Flatinvm%2Fhomeassistant-addon-soundcork)

Click the badge to open the add-repository dialog with this repo's URL
pre-filled, then **Add**, then install **SoundCork** from the store.

> **Known issue on Home Assistant frontend `20260429.x` and similar.**
> The `Add-ons` panel was renamed to `Apps` and moved under
> `/config/apps`. The `my.home-assistant.io` redirect target the badge
> uses still points at the legacy `/hassio/store` route, so on these
> frontend versions the click lands on the Apps page without opening
> the add-repository dialog. Use the manual steps below until upstream
> ships a fix; the wrapper itself is unaffected.

### Manual install (always works)

1. **Settings -> Apps** (called **Settings -> Add-ons** on Home Assistant
   frontend versions older than 2026.04). Open the **Add-on store** tab.
2. Three-dot menu in the top right -> **Repositories**.
3. Paste `https://github.com/latinvm/homeassistant-addon-soundcork` and click **Add**.

After the repository is added, open **SoundCork**, click **Install**,
fill in `base_url` on the **Configuration** tab, optionally set
`ADMIN_BASIC_AUTH_USER` and `ADMIN_BASIC_AUTH_PASSWORD` to gate `/admin`
and `/mgmt` (leave both blank to disable auth), and start the add-on.

## What this is, and what it is not

This repository contains the **add-on wrapper only**. It does not
contain SoundCork. At install time the supervisor pulls
`ghcr.io/latinvm/soundcork:optional-basic-auth-admin-mgmt` (a fork of
[`deborahgu/soundcork`](https://github.com/deborahgu/soundcork) that
adds optional HTTP Basic auth on `/admin` and `/mgmt`) and runs it
under the supervisor's process and volume management.

- SoundCork itself: bug reports, feature requests, protocol questions
  go to [latinvm/soundcork](https://github.com/latinvm/soundcork) or
  upstream
  [deborahgu/soundcork](https://github.com/deborahgu/soundcork).
- This add-on wrapper: install issues, option schema bugs, supervisor
  integration problems, image pin bumps go here.

The HTTP API is served on port `8000` of the Home Assistant host by
default. See `soundcork/DOCS.md` if you need to remap it.

## What you still have to do on the speakers

The add-on only runs the SoundCork server. It does not configure the
speakers. The speaker-side procedure (USB stick with `remote_services`,
SSH onto the speaker, edit `/mnt/nv/OverrideSdkPrivateCfg.xml` to point at
the add-on) is documented in [`soundcork/DOCS.md`](soundcork/DOCS.md).

## Architectures

`amd64` and `aarch64` only, matching the upstream image.

## Versioning

Add-on version (in `soundcork/config.yaml`) is independent from the
upstream SoundCork release. The upstream image is pinned to a branch
tag on the [`latinvm/soundcork`](https://github.com/latinvm/soundcork)
fork. See `soundcork/DOCS.md` for the update procedure.

## License

MIT, matching upstream SoundCork.
