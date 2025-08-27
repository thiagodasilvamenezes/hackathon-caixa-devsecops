#!/usr/bin/env bash
set -euo pipefail
IMAGE_BASE="${1:?registry/repo}"
TAG="${2:?tag}"
LOCAL="${IMAGE_BASE}:${TAG}"
echo "📤 Pushing ${LOCAL}"
docker push "${LOCAL}"
