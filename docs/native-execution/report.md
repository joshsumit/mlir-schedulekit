# Milestone 0 Report: Native Execution Proof

## Result

Milestone 0 passes for one static `f32` `linalg.matmul` on the selected x86-64
Linux toolchain. The workload was lowered, compiled to a native object, linked
with the C++ runner, invoked once, and checked element by element against the
independent reference. All 16 values matched.

Reproduce from this directory with:

```sh
./scripts/run_native.sh
```

The script verifies the pinned LLVM revision before running. The toolchain path
can be supplied with `MLIR_BUILD_DIR` when the same build is installed elsewhere.

## Toolchain

- Host: x86-64 Ubuntu under WSL2, Linux kernel `6.18.33.2-microsoft-standard-WSL2`.
- LLVM/MLIR: commit `ac5dc54d509169d387fcfd495d71853d81c46484`,
  described as `llvmorg-23-init-2125-gac5dc54d5091`.
- LLVM build: `RelWithDebInfo`; CMake configured with
  `LLVM_ENABLE_PROJECTS=llvm;mlir;lld`, `LLVM_TARGETS_TO_BUILD=AMDGPU;NVPTX;X86;Hexagon`,
  and `MLIR_ENABLE_EXECUTION_ENGINE=ON`.
- Runner compiler: Ubuntu Clang 18.1.3.
- Native target: `x86_64-unknown-linux-gnu`.

Commands, tool versions, and build settings are recorded in
[`toolchain.md`](./toolchain.md). Pass and execution-path evidence is in
[`toolchain-capabilities.md`](./toolchain-capabilities.md).

## Workload

- Source: [`matmul_4x4x4_f32.mlir`](../../workloads/matmul/matmul_4x4x4_f32.mlir).
- Operation: `linalg.matmul`.
- Dimensions: M=4, N=4, K=4.
- Element type: `f32`.
- Function: three static tensor arguments and no return value.
- Semantics: row-major `C += A * B`; the runner initializes C to zero.

The exact inputs and reference result are documented in
[`correctness-case.md`](./correctness-case.md).

## Lowering and native invocation

The tested pipeline is:

```text
static tensor linalg.matmul
  -> one-shot bufferization across function boundaries
  -> linalg-to-loops
  -> SCF-to-CF
  -> Func-to-LLVM with bare-pointer memref calling convention
  -> remaining dialects to LLVM
  -> LLVM dialect to LLVM IR
  -> x86-64 native object
  -> C++ runner link and invocation
```

The pass names and options were found in the pinned build's `mlir-opt --help`
and `--help-hidden`, then tested on the actual payload. The complete pipeline
and executable commands are preserved in
[`pipeline.txt`](../../artifacts/native-execution/compiler/pipeline.txt) and
[`commands.txt`](../../artifacts/native-execution/compiler/commands.txt). The
preserved IR stages are:

- [`00-input.mlir`](../../artifacts/native-execution/ir/00-input.mlir)
- [`01-bufferized.mlir`](../../artifacts/native-execution/ir/01-bufferized.mlir)
- [`02-llvm-dialect.mlir`](../../artifacts/native-execution/ir/02-llvm-dialect.mlir)
- [`03-llvm.ll`](../../artifacts/native-execution/ir/03-llvm.ll)

The LLVM IR signature is `define void @matmul(ptr %0, ptr %1, ptr %2)`. The
object exports a global `matmul` symbol. The runner's pointer declaration and
buffer ownership are documented in [`native-interface.md`](./native-interface.md).

The selected mechanism is object emission and native linking, rather than the
available MLIR JIT runner. This makes the generated symbol callable from the
small native runner that owns the test inputs and independent reference.

## Runner and correctness

The runner allocates separate contiguous A, B, and C arrays; initializes A and B
with deterministic, non-symmetric values and C with zeros; calls the generated
kernel exactly once; computes the reference separately; and compares every
element using absolute and relative tolerances of `1.0e-5`.

Observed result:

```text
Maximum absolute error: 0.000000e+00
Maximum relative error: 0.000000e+00
Mismatch count: 0
```

The native object symbol, lowered dialect content, and runner exit status are
checked by the build-and-run script. The failure-propagation test also verified
that lowering, native compilation, linking, invocation, and correctness
failures all produce non-zero outcomes.

## Diagnostics and known limitations

The successful run emitted no compiler stderr; the current-run
[`diagnostics.txt`](../../artifacts/native-execution/compiler/diagnostics.txt) is
empty. The failure-propagation test injects failures in isolated temporary
artifact directories.

Observed scope is limited to this one 4x4 static workload, `f32`, the pinned
x86-64 Linux toolchain, and single-threaded execution. No Transform schedules,
benchmarking, or performance claims are included in Milestone 0.
