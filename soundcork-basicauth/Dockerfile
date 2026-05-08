# Pinned to a branch tag (not a digest) so rebuilds of the
# optional-basic-auth-admin-mgmt branch on latinvm/soundcork are picked
# up by reinstalling or rebuilding the add-on. This add-on tracks an
# in-flight PR and will be removed once that PR resolves upstream.
#
# hadolint global ignore=DL3002
# Final USER is root by design; matches the production add-on. See
# ../soundcork/DOCS.md "Known limitations".
FROM ghcr.io/latinvm/soundcork:optional-basic-auth-admin-mgmt

USER root

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq tini \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /app/soundcork

CMD ["/run.sh"]
