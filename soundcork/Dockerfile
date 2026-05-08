# Tracks the optional-basic-auth-admin-mgmt branch on the latinvm fork
# of SoundCork (a PR pending upstream that adds optional HTTP Basic auth
# on /admin and /mgmt). Pinned by tag, not digest, so a rebuild of the
# branch image is picked up by reinstalling or rebuilding the add-on.
# When the PR lands upstream, switch this to a digest pin against the
# upstream :main image and remove this comment block. See DOCS.md
# ("Updating the upstream image").
#
# hadolint global ignore=DL3002
# Final USER is root by design; see DOCS.md "Known limitations".
FROM ghcr.io/latinvm/soundcork:optional-basic-auth-admin-mgmt

# Wrapper additions need root, and upstream already ships USER root in
# this branch (verified with `docker inspect`), so this line is a
# defensive restate rather than a downgrade. /data is created at runtime
# owned by root and the wrapper writes options.json into it.
USER root

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq tini \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /app/soundcork

CMD ["/run.sh"]
