#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE=/data/options.json

if [[ ! -f "${OPTIONS_FILE}" ]]; then
  echo "[soundcork] ${OPTIONS_FILE} missing; supervisor did not provide options" >&2
  exit 1
fi

base_url=$(jq -r '.base_url // ""' "${OPTIONS_FILE}")
data_dir=$(jq -r '.data_dir // "/data/soundcork"' "${OPTIONS_FILE}")

if [[ -z "${base_url}" ]]; then
  echo "[soundcork] base_url is required (set it on the Configuration tab)" >&2
  exit 1
fi

# Catch the common typo of dropping the scheme ("192.168.1.50:8000")
# before it propagates to every speaker as a silently-broken URL.
if [[ ! "${base_url}" =~ ^https?:// ]]; then
  echo "[soundcork] base_url must start with http:// or https:// (got '${base_url}')" >&2
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

export base_url
export data_dir

# Surface the resolved options in the startup log. The most common
# silent-failure mode is a base_url that does not match the host port
# on the Network tab; eyeballing this line catches it without opening
# Configuration. See DOCS.md "Option reference -> base_url".
echo "[soundcork] base_url=${base_url} data_dir=${data_dir}"

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
