# Changelog

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
