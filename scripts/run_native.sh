#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_MLIR_BUILD_DIR="/local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build"
MLIR_BUILD_DIR="${MLIR_BUILD_DIR:-$DEFAULT_MLIR_BUILD_DIR}"
MLIR_BIN_DIR="${MLIR_BIN_DIR:-$MLIR_BUILD_DIR/bin}"
MLIR_OPT="${MLIR_OPT:-$MLIR_BIN_DIR/mlir-opt}"
MLIR_TRANSLATE="${MLIR_TRANSLATE:-$MLIR_BIN_DIR/mlir-translate}"
LLC="${LLC:-$MLIR_BIN_DIR/llc}"
LLVM_NM="${LLVM_NM:-$MLIR_BIN_DIR/llvm-nm}"
LLVM_CONFIG="${LLVM_CONFIG:-$MLIR_BIN_DIR/llvm-config}"
CXX="${CXX:-clang++}"
TARGET_TRIPLE="${TARGET_TRIPLE:-x86_64-unknown-linux-gnu}"
EXPECTED_LLVM_REVISION="ac5dc54d509169d387fcfd495d71853d81c46484"

WORKLOAD="$ROOT_DIR/workloads/matmul/matmul_4x4x4_f32.mlir"
RUNNER_SOURCE="${RUNNER_SOURCE:-$ROOT_DIR/runtime/runner/native_runner.cpp}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT_DIR/artifacts/native-execution}"
IR_DIR="$ARTIFACT_DIR/ir"
COMPILER_DIR="$ARTIFACT_DIR/compiler"
NATIVE_DIR="$ARTIFACT_DIR/native"
DIAGNOSTICS="$COMPILER_DIR/diagnostics.txt"
COMMANDS="$COMPILER_DIR/commands.txt"
PIPELINE="$COMPILER_DIR/pipeline.txt"
TEMP_STDERR="$COMPILER_DIR/.stderr.tmp"

mkdir -p "$IR_DIR" "$COMPILER_DIR" "$NATIVE_DIR"
: > "$DIAGNOSTICS"
: > "$COMMANDS"
rm -f \
  "$IR_DIR/00-input.mlir" \
  "$IR_DIR/01-bufferized.mlir" \
  "$IR_DIR/02-llvm-dialect.mlir" \
  "$IR_DIR/03-llvm.ll" \
  "$NATIVE_DIR/matmul.o" \
  "$NATIVE_DIR/native_runner.o" \
  "$NATIVE_DIR/native_runner" \
  "$NATIVE_DIR/symbols.txt"
trap 'rm -f "$TEMP_STDERR"' EXIT

for tool in "$MLIR_OPT" "$MLIR_TRANSLATE" "$LLC" "$LLVM_NM" "$LLVM_CONFIG"; do
  if [[ ! -x "$tool" ]]; then
    printf 'Required tool is not executable: %s\n' "$tool" >&2
    exit 127
  fi
done

if ! command -v "$CXX" >/dev/null 2>&1; then
  printf 'C++ compiler not found: %s\n' "$CXX" >&2
  exit 127
fi
CXX="$(command -v "$CXX")"

BUILD_CACHE="$MLIR_BUILD_DIR/CMakeCache.txt"
if [[ ! -f "$BUILD_CACHE" ]]; then
  printf 'LLVM build cache not found: %s\n' "$BUILD_CACHE" \
    | tee -a "$DIAGNOSTICS" >&2
  exit 1
fi
LLVM_HOME="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$BUILD_CACHE")"
if [[ -z "$LLVM_HOME" || ! -d "$LLVM_HOME" ]]; then
  printf 'Could not resolve LLVM source directory from %s\n' "$BUILD_CACHE" \
    | tee -a "$DIAGNOSTICS" >&2
  exit 1
fi
LLVM_SOURCE_ROOT="$(dirname "$LLVM_HOME")"
ACTUAL_LLVM_REVISION="$(git -C "$LLVM_SOURCE_ROOT" rev-parse HEAD)"
if [[ "$ACTUAL_LLVM_REVISION" != "$EXPECTED_LLVM_REVISION" ]]; then
  printf 'LLVM revision mismatch: expected %s, found %s\n' \
    "$EXPECTED_LLVM_REVISION" "$ACTUAL_LLVM_REVISION" \
    | tee -a "$DIAGNOSTICS" >&2
  exit 1
fi
if [[ -n "$(git -C "$LLVM_SOURCE_ROOT" status --porcelain)" ]]; then
  printf 'LLVM source tree has uncommitted changes: %s\n' "$LLVM_SOURCE_ROOT" \
    | tee -a "$DIAGNOSTICS" >&2
  exit 1
fi

record_command() {
  local argument
  printf '+' >> "$COMMANDS"
  for argument in "$@"; do
    printf ' %q' "$argument" >> "$COMMANDS"
  done
  printf '\n' >> "$COMMANDS"
}

run_step() {
  local label="$1"
  shift
  local status

  printf '== %s ==\n' "$label"
  record_command "$@"
  if "$@" 2> "$TEMP_STDERR"; then
    status=0
  else
    status=$?
  fi

  if [[ -s "$TEMP_STDERR" ]]; then
    cat "$TEMP_STDERR" >> "$DIAGNOSTICS"
    cat "$TEMP_STDERR" >&2
  fi
  : > "$TEMP_STDERR"

  if (( status != 0 )); then
    printf '%s failed with exit status %d\n' "$label" "$status" \
      | tee -a "$DIAGNOSTICS" >&2
    return "$status"
  fi
}

cat > "$PIPELINE" <<EOF
Input verification:
  $MLIR_OPT <workload> --verify-each
Tensor function-boundary bufferization:
  builtin.module(one-shot-bufferize{bufferize-function-boundaries function-boundary-type-conversion=identity-layout-map})
Loop and LLVM dialect lowering:
  --convert-linalg-to-loops
  --convert-scf-to-cf
  --convert-func-to-llvm='use-bare-ptr-memref-call-conv=1'
  --convert-to-llvm
  --reconcile-unrealized-casts
LLVM IR generation:
  $MLIR_TRANSLATE --mlir-to-llvmir
Native object generation:
  $LLC -filetype=obj -mtriple=$TARGET_TRIPLE -O0
Runner compilation:
  $CXX -std=c++17 -O0 -g -Wall -Wextra -Werror
Runner link:
  $CXX <runner-object> <kernel-object> -o <runner>
EOF

run_step "Verify workload" \
  "$MLIR_OPT" "$WORKLOAD" --verify-each -o /dev/null

record_command cp "$WORKLOAD" "$IR_DIR/00-input.mlir"
cp "$WORKLOAD" "$IR_DIR/00-input.mlir"

run_step "Bufferize tensor function boundaries" \
  "$MLIR_OPT" "$IR_DIR/00-input.mlir" \
  '--pass-pipeline=builtin.module(one-shot-bufferize{bufferize-function-boundaries function-boundary-type-conversion=identity-layout-map})' \
  --verify-each -o "$IR_DIR/01-bufferized.mlir"

run_step "Lower to LLVM dialect" \
  "$MLIR_OPT" "$IR_DIR/01-bufferized.mlir" \
  --convert-linalg-to-loops \
  --convert-scf-to-cf \
  '--convert-func-to-llvm=use-bare-ptr-memref-call-conv=1' \
  --convert-to-llvm \
  --reconcile-unrealized-casts \
  --verify-each -o "$IR_DIR/02-llvm-dialect.mlir"

record_command grep -Eq \
  '(^|[[:space:]])(linalg\.|memref<|scf\.|arith\.|func\.func)' \
  "$IR_DIR/02-llvm-dialect.mlir"
if grep -Eq '(^|[[:space:]])(linalg\.|memref<|scf\.|arith\.|func\.func)' \
  "$IR_DIR/02-llvm-dialect.mlir"; then
  printf 'Unexpected high-level operations remain after LLVM dialect lowering\n' \
    | tee -a "$DIAGNOSTICS" >&2
  exit 1
fi

run_step "Translate LLVM dialect to LLVM IR" \
  "$MLIR_TRANSLATE" "$IR_DIR/02-llvm-dialect.mlir" \
  --mlir-to-llvmir -o "$IR_DIR/03-llvm.ll"

run_step "Generate native object" \
  "$LLC" -filetype=obj "-mtriple=$TARGET_TRIPLE" -O0 \
  "$IR_DIR/03-llvm.ll" -o "$NATIVE_DIR/matmul.o"

run_step "Inspect generated native symbols" \
  "$LLVM_NM" --defined-only "$NATIVE_DIR/matmul.o" \
  > "$NATIVE_DIR/symbols.txt"
record_command grep -Eq '[[:space:]]matmul$' "$NATIVE_DIR/symbols.txt"
if ! grep -Eq '[[:space:]]matmul$' "$NATIVE_DIR/symbols.txt"; then
  printf 'Generated native object does not define the matmul symbol\n' \
    | tee -a "$DIAGNOSTICS" >&2
  exit 1
fi

run_step "Compile runner" \
  "$CXX" -std=c++17 -O0 -g -Wall -Wextra -Werror -c \
  "$RUNNER_SOURCE" -o "$NATIVE_DIR/native_runner.o"

run_step "Link runner with generated kernel" \
  "$CXX" "$NATIVE_DIR/native_runner.o" "$NATIVE_DIR/matmul.o" \
  -o "$NATIVE_DIR/native_runner"

run_step "Invoke generated kernel and check correctness" \
  "$NATIVE_DIR/native_runner"
