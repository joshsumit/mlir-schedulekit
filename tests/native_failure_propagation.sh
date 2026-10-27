#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_SCRIPT="$ROOT_DIR/scripts/run_native.sh"
TEST_DIR="$(mktemp -d)"
REAL_MLIR_OPT="${MLIR_OPT:-${MLIR_BUILD_DIR:-/local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build}/bin/mlir-opt}"
TEST_CXX="${CXX:-clang++}"
trap 'rm -rf "$TEST_DIR"' EXIT

expect_failure() {
  local name="$1"
  local expected="$2"
  shift 2
  local output="$TEST_DIR/$name.log"

  if env "$@" "$RUN_SCRIPT" >"$output" 2>&1; then
    printf 'Expected %s to fail, but it succeeded\n' "$name" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$output"; then
    printf 'Expected failure evidence not found for %s: %s\n' \
      "$name" "$expected" >&2
    cat "$output" >&2
    exit 1
  fi
  printf 'PASS: %s failure propagated\n' "$name"
}

cat > "$TEST_DIR/fail-on-second-mlir-opt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
count=0
if [[ -f "$MLIR_OPT_CALLS" ]]; then
  read -r count < "$MLIR_OPT_CALLS"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$MLIR_OPT_CALLS"
if (( count == 2 )); then
  printf 'Injected lowering failure for propagation test\n' >&2
  exit 42
fi
exec "$REAL_MLIR_OPT" "$@"
EOF
chmod +x "$TEST_DIR/fail-on-second-mlir-opt"
expect_failure lowering \
  "Injected lowering failure for propagation test" \
  ARTIFACT_DIR="$TEST_DIR/lowering" \
  MLIR_OPT="$TEST_DIR/fail-on-second-mlir-opt" \
  REAL_MLIR_OPT="$REAL_MLIR_OPT" \
  MLIR_OPT_CALLS="$TEST_DIR/mlir-opt-calls"

expect_failure native-compilation \
  "Compile runner failed with exit status 1" \
  ARTIFACT_DIR="$TEST_DIR/native-compilation" \
  CXX=/bin/false

cat > "$TEST_DIR/missing-symbol.cpp" <<'EOF'
extern "C" void schedulekit_missing_symbol();
int main() {
  schedulekit_missing_symbol();
  return 0;
}
EOF
expect_failure native-link \
  "Link runner with generated kernel failed" \
  ARTIFACT_DIR="$TEST_DIR/native-link" \
  RUNNER_SOURCE="$TEST_DIR/missing-symbol.cpp"

cat > "$TEST_DIR/nonzero-runner.cpp" <<'EOF'
extern "C" void matmul(float*, float*, float*);
int main() {
  float a[16]{};
  float b[16]{};
  float c[16]{};
  matmul(a, b, c);
  return 23;
}
EOF
expect_failure invocation \
  "Invoke generated kernel and check correctness failed with exit status 23" \
  ARTIFACT_DIR="$TEST_DIR/invocation" \
  RUNNER_SOURCE="$TEST_DIR/nonzero-runner.cpp"

cat > "$TEST_DIR/incorrect-kernel.cpp" <<'EOF'
extern "C" void matmul(float*, float*, float*) {}
EOF
cat > "$TEST_DIR/incorrect-llc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=
while (($#)); do
  if [[ "$1" == "-o" ]]; then
    output="$2"
    shift 2
  else
    shift
  fi
done
"$TEST_CXX" -c "$INCORRECT_KERNEL" -o "$output"
EOF
chmod +x "$TEST_DIR/incorrect-llc"
expect_failure correctness \
  "Mismatch count: 16" \
  ARTIFACT_DIR="$TEST_DIR/correctness" \
  LLC="$TEST_DIR/incorrect-llc" \
  TEST_CXX="$(command -v "$TEST_CXX")" \
  INCORRECT_KERNEL="$TEST_DIR/incorrect-kernel.cpp"
