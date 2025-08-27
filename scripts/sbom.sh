#!/usr/bin/env bash
set -euo pipefail
IMAGE="${1:?image}"
mkdir -p sbom
echo "📦 Gerando SBOM (SPDX/CycloneDX) para ${IMAGE}"
syft packages "${IMAGE}" -o spdx-json > sbom/spdx.json
syft packages "${IMAGE}" -o cyclonedx-json > sbom/cyclonedx.json
echo "✅ SBOMs em ./sbom/"
