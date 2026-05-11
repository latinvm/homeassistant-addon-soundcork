# Changelog

## 0.3.1 - 2026-05-11

- Logs the resolved `base_url` and `data_dir` once on startup so the
  most common silent-failure mode (wrong `base_url` after remapping
  the host port on the Network tab) is visible in the add-on log.
- Rejects a `base_url` that does not start with `http://` or
  `https://` at startup, rather than letting a scheme-less value
  propagate to every speaker.
- Documentation corrections: `/webui/` does not exist on upstream
  `deborahgu/soundcork`; it was a route name from the now-removed
  `latinvm` fork that leaked into our docs. The real human-facing
  paths are `/miniapp` / `/miniapp/dashboard` (post-setup) and
  `/admin/` (setup). The bare `/` is a 303 redirect to one of the
  two, not a 200-no-body. No sidebar link is added: the miniapp
  dashboard is a setup-and-occasional-use tool, not a daily UI.

## 0.3.0 - 2026-05-11

- **Breaking.** Drops the `latinvm/soundcork` fork and pins
  `ghcr.io/deborahgu/soundcork:main` directly. The fork only existed
  to add optional HTTP Basic auth on `/admin` and `/mgmt`; the auth
  was defence in depth at best (the destructive `/admin` actions SSH
  into speakers that already permit password-less root from anywhere
  on the same LAN), so the wrapper now matches upstream's open
  posture.
- **Breaking.** Removes the `ADMIN_BASIC_AUTH_USER` and
  `ADMIN_BASIC_AUTH_PASSWORD` options. The supervisor rejects unknown
  options on startup, so anyone who had these set must clear them on
  the Configuration tab before starting 0.3.0.
- No behaviour change for `/webui/`, `/admin`, `/mgmt`, the speaker
  endpoints, seed import, or `data_dir` validation.

## 0.2.2 - 2026-05-08

- Sets `host_network: true`. SoundCork's `/scan` endpoint discovers
  speakers via mDNS (`_soundtouch._tcp.local`) and the soft-switch
  flow needs to reach each speaker's HTTP API on port `8090` on the
  LAN. Bridge networking blocks the multicast announces and was also
  observed to fail outbound to speaker ports in practice; sharing the
  host network namespace is the supported posture for this kind of
  LAN-discovery service.

## 0.2.0 - 2026-05-08

- Pins `ghcr.io/latinvm/soundcork:optional-basic-auth-admin-mgmt`, a
  fork of `deborahgu/soundcork` that adds optional HTTP Basic auth on
  `/admin` and `/mgmt`.
- Options: `base_url`, `ADMIN_BASIC_AUTH_USER`,
  `ADMIN_BASIC_AUTH_PASSWORD`, `data_dir`. Setting both auth fields
  enables the gate; leaving both blank disables it.
- `data_dir` is validated to live under `/data` on startup.
- `init: false` plus `tini` for clean shutdown signals.
- Architectures: `amd64`, `aarch64`. No `host_network`, no
  `privileged`, no `full_access`, no `docker_api`.
- Imports hand-placed seed files from `/share/soundcork/seed` on
  startup with `cp -rn` (existing files in `/data` win).
