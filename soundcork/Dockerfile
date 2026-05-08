# Pinned by digest, not :main, so add-on rebuilds are reproducible and the
# upstream tag floating does not silently change behaviour. See DOCS.md
# ("Bumping the pinned upstream image") for the bump procedure.
#
# hadolint global ignore=DL3002
# Final USER is root by design; see DOCS.md "Known limitations".
FROM ghcr.io/timvw/soundcork@sha256:78f0b45cf1bc4cbad97b4b96c177c4bc3c8fe30f228514767be3c4393cfba4d7

# Wrapper additions need root. Upstream's USER (appuser, uid 1000) is
# replaced rather than restored at the end: Home Assistant's /data bind
# mount is created at runtime owned by root, and the wrapper writes
# options.json into it. Running gunicorn as root is the same posture
# every other root-mode HA add-on takes; document this trade-off rather
# than work around it with gosu/setpriv gymnastics.
USER root

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq tini \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /app/soundcork

CMD ["/run.sh"]
