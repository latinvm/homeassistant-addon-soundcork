#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE=/data/options.json

if [[ ! -f "${OPTIONS_FILE}" ]]; then
  echo "[soundcork] ${OPTIONS_FILE} missing; supervisor did not provide options" >&2
  exit 1
fi

base_url=$(jq -r '.base_url // ""' "${OPTIONS_FILE}")
data_dir=$(jq -r '.data_dir // "/data/soundcork"' "${OPTIONS_FILE}")
mgmt_username=$(jq -r '.MGMT_USERNAME // "admin"' "${OPTIONS_FILE}")
mgmt_password=$(jq -r '.MGMT_PASSWORD // ""' "${OPTIONS_FILE}")
oidc_issuer_url=$(jq -r '.OIDC_ISSUER_URL // ""' "${OPTIONS_FILE}")
oidc_client_id=$(jq -r '.OIDC_CLIENT_ID // ""' "${OPTIONS_FILE}")
oidc_client_secret=$(jq -r '.OIDC_CLIENT_SECRET // ""' "${OPTIONS_FILE}")

if [[ -z "${base_url}" ]]; then
  echo "[soundcork] base_url is required (set it on the Configuration tab)" >&2
  exit 1
fi

if [[ -z "${mgmt_password}" ]]; then
  echo "[soundcork] MGMT_PASSWORD is required (set it on the Configuration tab)" >&2
  exit 1
fi

# data_dir must resolve under /data so the supervisor persists it across
# upgrades. Anything else is silently lost on add-on update.
case "${data_dir}" in
  /data | /data/* ) ;;
  * )
    echo "[soundcork] data_dir must be under /data (got '${data_dir}')" >&2
    exit 1
    ;;
esac

mkdir -p "${data_dir}"

# OIDC is all-or-nothing. Half-configured OIDC silently disables auth in
# upstream because the property check is a boolean AND, which is worse
# than a clear startup failure here.
oidc_count=0
[[ -n "${oidc_issuer_url}" ]] && oidc_count=$((oidc_count + 1))
[[ -n "${oidc_client_id}" ]] && oidc_count=$((oidc_count + 1))
[[ -n "${oidc_client_secret}" ]] && oidc_count=$((oidc_count + 1))
if [[ "${oidc_count}" -ne 0 && "${oidc_count}" -ne 3 ]]; then
  echo "[soundcork] OIDC requires all three of OIDC_ISSUER_URL, OIDC_CLIENT_ID, OIDC_CLIENT_SECRET, or none of them" >&2
  exit 1
fi

export base_url
export data_dir
export MGMT_USERNAME="${mgmt_username}"
export MGMT_PASSWORD="${mgmt_password}"
export OIDC_ISSUER_URL="${oidc_issuer_url}"
export OIDC_CLIENT_ID="${oidc_client_id}"
export OIDC_CLIENT_SECRET="${oidc_client_secret}"

# Optional manual seed: if /share/soundcork/seed/ exists and contains
# files, copy them into /data/ with cp -rn (no-clobber) so anything
# already in /data wins. This is one-shot insurance for the case where
# the SoundCork "Configure Account" flow fails; it is not a sync.
SEED_DIR=/share/soundcork/seed
seed_files=()
if [[ -d "${SEED_DIR}" ]]; then
  while IFS= read -r -d '' f; do
    seed_files+=("${f}")
  done < <(find "${SEED_DIR}" -type f -print0)
fi

if (( ${#seed_files[@]} == 0 )); then
  echo "[soundcork] no seed files found, skipping"
else
  echo "[soundcork] seeding ${#seed_files[@]} file(s) from ${SEED_DIR} into /data (existing files preserved)"
  for f in "${seed_files[@]}"; do
    rel=${f#"${SEED_DIR}/"}
    echo "[soundcork] seed: ${rel}"
  done
  cp -rn "${SEED_DIR}/." /data/
fi

# init: false in config.yaml means the supervisor does not inject its own
# init system. tini reaps zombies and forwards signals so a stop from the
# UI is a clean SIGTERM to gunicorn rather than a 10-second SIGKILL wait.
exec tini -- gunicorn \
  -c gunicorn_conf.py \
  --bind 0.0.0.0:8000 \
  --access-logfile - \
  --error-logfile - \
  --workers 1 \
  main:app
