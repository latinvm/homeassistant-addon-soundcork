# Test add-on for the optional-basic-auth-admin-mgmt PR branch on
# latinvm/soundcork. Tracked by tag (not digest) so iterating on the
# branch image and reinstalling here picks up the new build. Expected
# to disappear when the upstream PR lands or is rejected.
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
