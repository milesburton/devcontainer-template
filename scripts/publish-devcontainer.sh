#!/usr/bin/env bash
set -euo pipefail

IMAGE=${IMAGE:-ghcr.io/milesburton/devcontainer-template}
TAG=${TAG:-latest}
DOCKERFILE=${DOCKERFILE:-.devcontainer/Dockerfile}
REGISTRY_USER=${REGISTRY_USER:-milesburton}

TOKEN=${GHCR_TOKEN:-${GHCR_PAT:-}}
if [ -z "$TOKEN" ]; then
  echo "GHCR_TOKEN or GHCR_PAT environment variable is required (with read:packages, write:packages)." >&2
  exit 1
fi

echo "Logging into GHCR as '$REGISTRY_USER'..."
echo "$TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin

echo "Building image $IMAGE:$TAG from $DOCKERFILE ..."
docker build -f "$DOCKERFILE" -t "$IMAGE:$TAG" .

if sha=$(git rev-parse --short HEAD 2>/dev/null); then
  docker tag "$IMAGE:$TAG" "$IMAGE:$sha"
  echo "Tagged SHA: $IMAGE:$sha"
fi

echo "Pushing $IMAGE:$TAG ..."
docker push "$IMAGE:$TAG"

if [ -n "${sha:-}" ]; then
  echo "Pushing $IMAGE:$sha ..."
  docker push "$IMAGE:$sha"
fi

echo "Done. Verify locally:"
echo "  docker images $IMAGE"
