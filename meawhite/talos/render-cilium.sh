#!/usr/bin/env bash
# Render the pinned Cilium Helm chart into a Talos v1.14 KubeInlineManifestConfig.
# No Helm controller or in-cluster Helm release is involved.
set -euo pipefail

if (( $# != 1 )) || [[ "$1" != /* ]]; then
  printf 'usage: %s /absolute/private/output/cilium-bootstrap.patch.yaml\n' "$0" >&2
  exit 2
fi

command -v helm >/dev/null || { echo "helm is required (use nix develop .#meawhite-talos)" >&2; exit 1; }

output=$1
src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
umask 077
mkdir -p -- "$(dirname -- "$output")"

# Create temporary files alongside the destination for atomic publication.
manifest=$(mktemp "$(dirname -- "$output")/.cilium-manifest.XXXXXXXX")
patch=$(mktemp "$(dirname -- "$output")/.cilium-patch.XXXXXXXX")
trap 'rm -f -- "$manifest" "$patch"' EXIT

helm template cilium oci://quay.io/cilium/charts/cilium \
  --version 1.20.4 \
  --namespace kube-system \
  --include-crds \
  --values "$src/cilium-values.yaml" > "$manifest"

# Fail closed rather than putting an empty or obviously wrong chart into Talos.
if ! grep -qx 'kind: DaemonSet' "$manifest" ||
   ! grep -qx 'kind: Deployment' "$manifest"; then
  echo "Cilium rendering did not produce a DaemonSet and Deployment" >&2
  exit 1
fi

{
  printf 'apiVersion: v1alpha1\nkind: KubeInlineManifestConfig\nname: cilium-bootstrap\nmanifest: |-\n'
  sed 's/^/  /' "$manifest"
} > "$patch"

mv -- "$patch" "$output"
printf 'Rendered Talos Cilium bootstrap patch: %s\n' "$output"
