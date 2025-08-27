#!/usr/bin/env bash
set -euo pipefail
IMAGE="${1:?image}"
STRICT="${STRICT:-true}"
echo "🔎 Trivy scanning ${IMAGE} (STRICT=${STRICT})"
if [ "${STRICT}" = "true" ]; then
  trivy image --exit-code 1 --severity HIGH,CRITICAL --scanners vuln,secret,config "${IMAGE}"
else
  trivy image --severity HIGH,CRITICAL --scanners vuln,secret,config "${IMAGE}" || true
fi
