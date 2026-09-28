#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run_ppc64_regpreserve.sh
#
# Builds and runs test/test_fcontext_ppc64_regpreserve.cpp on a ppc64le
# machine against the patched asm files in src/asm/.
#
# Usage (run from the repo root on the ppc64le machine):
#
#   # Option A — Boost is already installed (e.g. from Ceph build env):
#   BOOST_ROOT=/ceph/build-10/boost/include bash test/run_ppc64_regpreserve.sh
#
#   # Option B — Boost superproject checkout next to this repo:
#   BOOST_ROOT=/path/to/boost bash test/run_ppc64_regpreserve.sh
#
#   # Option C — Boost installed system-wide (dnf/apt):
#   bash test/run_ppc64_regpreserve.sh          # auto-detects /usr/include
#
# Environment variables (all optional, auto-detected if not set):
#   BOOST_ROOT   — path that contains boost/ headers
#   CXX          — C++ compiler (default: g++)
#   CC           — C compiler used to assemble .S files (default: gcc)
#   OUTDIR       — where to put .o and the binary (default: /tmp/ctx_test)
# ---------------------------------------------------------------------------
set -euo pipefail

# ── locate repo root ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── toolchain ───────────────────────────────────────────────────────────────
CXX="${CXX:-g++}"
CC="${CC:-gcc}"
OUTDIR="${OUTDIR:-/tmp/ctx_test}"
mkdir -p "$OUTDIR"

# ── verify we are on ppc64le ─────────────────────────────────────────────────
ARCH="$(uname -m)"
if [[ "$ARCH" != "ppc64le" && "$ARCH" != "ppc64" ]]; then
    echo "WARNING: running on $ARCH — the ppc64-specific inline asm test"
    echo "         (test_make_fcontext_sp_alignment) will be skipped at runtime,"
    echo "         but all other tests will still compile and run."
fi

# ── find Boost headers ───────────────────────────────────────────────────────
if [[ -z "${BOOST_ROOT:-}" ]]; then
    # try common locations
    for candidate in \
        /usr/include \
        /usr/local/include \
        /opt/rh/devtoolset-*/root/usr/include \
        /ceph/build-10/boost/include \
        /ceph/build/boost/include; do
        if [[ -f "$candidate/boost/core/lightweight_test.hpp" ]]; then
            BOOST_ROOT="$candidate"
            break
        fi
    done
fi

if [[ -z "${BOOST_ROOT:-}" || ! -f "$BOOST_ROOT/boost/core/lightweight_test.hpp" ]]; then
    echo "ERROR: cannot find boost/core/lightweight_test.hpp"
    echo "       Set BOOST_ROOT to the directory containing the boost/ folder."
    echo "       e.g.: BOOST_ROOT=/ceph/build-10/boost/include $0"
    exit 1
fi
echo "Using Boost headers: $BOOST_ROOT"

# ── Step 1: assemble the three patched .S files ──────────────────────────────
echo ""
echo "=== Step 1: assemble ppc64 asm ==="

# _CALL_ELF=2 selects ELFv2 (ppc64le Linux).  On big-endian ppc64 use 1.
ELF_VER=2
[[ "$(uname -m)" == "ppc64" ]] && ELF_VER=1

for name in jump make ontop; do
    src="$REPO/src/asm/${name}_ppc64_sysv_elf_gas.S"
    obj="$OUTDIR/${name}.o"
    echo "  assembling $src -> $obj"
    "$CC" -c \
        -x assembler-with-cpp \
        -D_CALL_ELF=$ELF_VER \
        -o "$obj" \
        "$src"
done

# ── Step 2: compile stack_traits + fcontext glue ─────────────────────────────
echo ""
echo "=== Step 2: compile C++ support sources ==="

"$CXX" -c -O2 -std=c++14 \
    -I"$BOOST_ROOT" \
    -DBOOST_CONTEXT_NO_LIB= \
    -DBOOST_CONTEXT_STATIC_LINK= \
    -DBOOST_CONTEXT_EXPORT= \
    -o "$OUTDIR/stack_traits.o" \
    "$REPO/src/posix/stack_traits.cpp"
echo "  compiled stack_traits.o"

"$CXX" -c -O2 -std=c++14 \
    -I"$BOOST_ROOT" \
    -DBOOST_CONTEXT_NO_LIB= \
    -DBOOST_CONTEXT_STATIC_LINK= \
    -DBOOST_CONTEXT_EXPORT= \
    -o "$OUTDIR/fcontext.o" \
    "$REPO/src/fcontext.cpp"
echo "  compiled fcontext.o"

# ── Step 3: compile the test ─────────────────────────────────────────────────
echo ""
echo "=== Step 3: compile test ==="

"$CXX" -c -O2 -std=c++14 \
    -I"$BOOST_ROOT" \
    -DBOOST_CONTEXT_NO_LIB= \
    -DBOOST_CONTEXT_STATIC_LINK= \
    -DBOOST_CONTEXT_EXPORT= \
    -o "$OUTDIR/test.o" \
    "$REPO/test/test_fcontext_ppc64_regpreserve.cpp"
echo "  compiled test.o"

# ── Step 4: link ─────────────────────────────────────────────────────────────
echo ""
echo "=== Step 4: link ==="

BIN="$OUTDIR/test_ppc64_regpreserve"
"$CXX" -O2 \
    "$OUTDIR/test.o" \
    "$OUTDIR/fcontext.o" \
    "$OUTDIR/stack_traits.o" \
    "$OUTDIR/jump.o" \
    "$OUTDIR/make.o" \
    "$OUTDIR/ontop.o" \
    -o "$BIN"
echo "  linked -> $BIN"

# ── Step 5: quick sanity check on the object ─────────────────────────────────
echo ""
echo "=== Step 5: objdump sanity check on jump.o ==="

objdump -d "$OUTDIR/jump.o" | head -30

echo ""
echo "--- expected first instruction:  addi r1,r1,-528"
echo "--- expected first FPR store:    stfd f14,384(r1)"
echo "--- expected first VMX li:       li r0,192"
echo ""

# ── Step 6: run ──────────────────────────────────────────────────────────────
echo "=== Step 6: run tests ==="
echo ""

"$BIN"
RC=$?

echo ""
if [[ $RC -eq 0 ]]; then
    echo "✅  ALL TESTS PASSED"
else
    echo "❌  TESTS FAILED (exit code $RC)"
fi
exit $RC
