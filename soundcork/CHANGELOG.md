# Changelog

## 0.1.0 - 2026-05-08

Initial release. Wrapper around upstream SoundCork.

- Pins `ghcr.io/timvw/soundcork` at digest
  `sha256:78f0b45cf1bc4cbad97b4b96c177c4bc3c8fe30f228514767be3c4393cfba4d7`.
- Exposes `base_url`, `MGMT_USERNAME`, `MGMT_PASSWORD`, `data_dir`, and
  optional `OIDC_*` fields as add-on options.
- `data_dir` is validated to live under `/data` on startup; OIDC is
  validated as all-or-nothing.
- `init: false` plus `tini` for clean shutdown signals.
- Architectures: `amd64`, `aarch64`. No `host_network`, no `privileged`,
  no `full_access`, no `docker_api`.
- Wrapper runs gunicorn as root rather than upstream's `appuser`. See
  `DOCS.md`.
