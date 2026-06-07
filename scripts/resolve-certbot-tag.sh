#!/bin/sh
set -eu

DOCKERHUB_REPO="${DOCKERHUB_REPO:-certbot/certbot}"
GHCR_IMAGE="${GHCR_IMAGE:?GHCR_IMAGE is required, e.g. ghcr.io/owner/certbot-hetzner-cloud}"

WORKDIR="$(mktemp -d)"
TAGS_FILE="$WORKDIR/tags.txt"

page=1

while :; do
  url="https://hub.docker.com/v2/repositories/${DOCKERHUB_REPO}/tags?page_size=100&page=${page}"

  response="$(curl -fsSL "$url")"

  echo "$response" \
    | jq -r '.results[].name' \
    >> "$TAGS_FILE"

  next="$(echo "$response" | jq -r '.next')"

  if [ "$next" = "null" ] || [ -z "$next" ]; then
    break
  fi

  page=$((page + 1))
done

CERTBOT_TAG="$(
  grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' "$TAGS_FILE" \
    | sort -V \
    | tail -n 1
)"

if [ -z "$CERTBOT_TAG" ]; then
  echo "Could not resolve latest stable Certbot tag" >&2
  exit 1
fi

echo "Resolved latest stable Certbot tag: $CERTBOT_TAG"

IMAGE_WITH_TAG="${GHCR_IMAGE}:${CERTBOT_TAG}"

if docker manifest inspect "$IMAGE_WITH_TAG" >/dev/null 2>&1; then
  echo "Image already exists in GHCR: $IMAGE_WITH_TAG"
  echo "CERTBOT_TAG=$CERTBOT_TAG" > certbot-tag.env
  echo "IMAGE_EXISTS=true" >> certbot-tag.env
  exit 0
fi

echo "Image does not exist yet in GHCR: $IMAGE_WITH_TAG"
echo "CERTBOT_TAG=$CERTBOT_TAG" > certbot-tag.env
echo "IMAGE_EXISTS=false" >> certbot-tag.env
