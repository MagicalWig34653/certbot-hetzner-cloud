#!/bin/sh
set -eu

: "${CERTBOT_EMAIL:?CERTBOT_EMAIL is required}"
: "${CERTBOT_DOMAINS:?CERTBOT_DOMAINS is required}"
: "${CERTBOT_CERT_NAME:?CERTBOT_CERT_NAME is required}"

CERTBOT_PROPAGATION_SECONDS="${CERTBOT_PROPAGATION_SECONDS:-120}"
CERTBOT_STAGING="${CERTBOT_STAGING:-0}"
CERTBOT_RENEW_INTERVAL_SECONDS="${CERTBOT_RENEW_INTERVAL_SECONDS:-43200}"
CERTBOT_KEY_TYPE="${CERTBOT_KEY_TYPE:-ecdsa}"
CERTBOT_ECDSA_CURVE="${CERTBOT_ECDSA_CURVE:-secp384r1}"
CERTBOT_EXTRA_ARGS="${CERTBOT_EXTRA_ARGS:-}"

TOKEN_FILE="${HETZNER_CLOUD_DNS_TOKEN_FILE:-/run/secrets/hetzner_cloud_dns_api_token}"
CREDENTIALS_FILE="${CERTBOT_CREDENTIALS_FILE:-/etc/letsencrypt/hetzner-cloud.ini}"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "Hetzner Cloud DNS token file not found: $TOKEN_FILE" >&2
  exit 1
fi

umask 077
mkdir -p "$(dirname "$CREDENTIALS_FILE")"

printf "dns_hetzner_cloud_api_token = %s\n" "$(cat "$TOKEN_FILE")" > "$CREDENTIALS_FILE"
chmod 600 "$CREDENTIALS_FILE"

DOMAIN_ARGS=""
OLD_IFS="$IFS"
IFS=","
for domain in $CERTBOT_DOMAINS; do
  DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
done
IFS="$OLD_IFS"

STAGING_ARG=""
if [ "$CERTBOT_STAGING" = "1" ] || [ "$CERTBOT_STAGING" = "true" ]; then
  STAGING_ARG="--staging"
fi

KEY_ARGS=""
if [ "$CERTBOT_KEY_TYPE" = "ecdsa" ]; then
  KEY_ARGS="--key-type ecdsa --elliptic-curve $CERTBOT_ECDSA_CURVE"
elif [ "$CERTBOT_KEY_TYPE" = "rsa" ]; then
  KEY_ARGS="--key-type rsa"
else
  echo "Unsupported CERTBOT_KEY_TYPE: $CERTBOT_KEY_TYPE. Use 'ecdsa' or 'rsa'." >&2
  exit 1
fi

run_certbot() {
  # shellcheck disable=SC2086
  certbot certonly \
    --non-interactive \
    --agree-tos \
    --email "$CERTBOT_EMAIL" \
    --cert-name "$CERTBOT_CERT_NAME" \
    --authenticator dns-hetzner-cloud \
    --dns-hetzner-cloud-credentials "$CREDENTIALS_FILE" \
    --dns-hetzner-cloud-propagation-seconds "$CERTBOT_PROPAGATION_SECONDS" \
    --keep-until-expiring \
    $STAGING_ARG \
    $KEY_ARGS \
    $CERTBOT_EXTRA_ARGS \
    $DOMAIN_ARGS
}

if [ "${CERTBOT_RUN_ONCE:-0}" = "1" ] || [ "${CERTBOT_RUN_ONCE:-false}" = "true" ]; then
  run_certbot
  exit 0
fi

while true; do
  echo "[$(date -Iseconds)] Running certbot for certificate: $CERTBOT_CERT_NAME"
  run_certbot

  echo "[$(date -Iseconds)] Sleeping ${CERTBOT_RENEW_INTERVAL_SECONDS}s"
  sleep "$CERTBOT_RENEW_INTERVAL_SECONDS"
done
