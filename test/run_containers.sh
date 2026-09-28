#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run_containers.sh
#
# Convenience script: builds and runs both Rocky 9 and Rocky 10 ppc64le
# container images for the boost.context ppc64 register-preservation tests.
#
# Prerequisites:
#   - podman installed on the host
#   - Host is either a ppc64le machine, or an x86_64 machine with
#     qemu-user-static + binfmt_misc configured for ppc64le emulation
#       (e.g. sudo podman run --rm --privileged multiarch/qemu-user-static --reset -p yes)
#
# Usage (run from repo root):
#   bash test/run_containers.sh
#
# Exit code: 0 if both containers pass, non-zero otherwise.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

run_container() {
    local label="$1"
    local containerfile="$2"
    local tag="$3"

    echo ""
    echo "========================================================================"
    echo "  Building: $label"
    echo "  Containerfile: $containerfile"
    echo "  Tag: $tag"
    echo "========================================================================"

    if podman build \
            --platform linux/ppc64le \
            -f "$containerfile" \
            -t "$tag" \
            "$REPO"; then
        echo ""
        echo "✅  $label: PASSED"
        PASS=$(( PASS + 1 ))
    else
        echo ""
        echo "❌  $label: FAILED"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── Rocky Linux 9 (GCC 11) ───────────────────────────────────────────────────
run_container \
    "Rocky Linux 9 ppc64le (GCC 11)" \
    "$REPO/Containerfile.rocky9-ppc64le" \
    "boost-ctx-test:rocky9"

# ── Rocky Linux 10 (GCC 14) ──────────────────────────────────────────────────
# Rocky 10 uses GCC 14, which triggered the original radosgw crash via
# aggressive auto-vectorisation into f14-f31 / v20-v31.  This is the most
# important environment to validate.
run_container \
    "Rocky Linux 10 ppc64le (GCC 14)" \
    "$REPO/Containerfile.rocky10-ppc64le" \
    "boost-ctx-test:rocky10"

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================================================"
echo "  Summary: $PASS passed, $FAIL failed"
echo "========================================================================"

if [[ $FAIL -ne 0 ]]; then
    exit 1
fi
exit 0
