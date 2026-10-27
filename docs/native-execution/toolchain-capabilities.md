# Milestone 0 Toolchain Capabilities

All pass and tool decisions below were checked against LLVM/MLIR commit
`ac5dc54d509169d387fcfd495d71853d81c46484`, using the actual static matmul
input.

## Tool inventory

| Purpose | Tool | Observed capability |
|---|---|---|
| Parse, verify, and transform MLIR | `mlir-opt` | Reports LLVM `23.0.0git`; registers the bufferization and lowering passes listed below. |
| Translate LLVM dialect | `mlir-translate` | Registers `--mlir-to-llvmir`. |
| JIT execution | `mlir-runner` | Available, with `-e`, `--entry-point-result`, and `--dump-object-file` options; the build has `MLIR_ENABLE_EXECUTION_ENGINE=ON`. |
| Generate native object | `llc` | Accepts `-filetype=obj` and `-mtriple`. |
| Inspect object symbols | `llvm-nm` | Accepts `--defined-only`. |
| Compile and link the runner | `clang++` | Ubuntu Clang 18.1.3; links the generated x86-64 object. |

The selected execution path is LLVM IR -> native object -> C++ runner. This
keeps the reference implementation and buffer ownership in a small ordinary
native program, and the actual generated symbol can be checked and linked
directly. The JIT path was not needed.

## Pass discovery and tested pipeline

Pass discovery used:

```text
/local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build/bin/mlir-opt --help
/local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build/bin/mlir-opt --help-hidden
```

The help output contained these exact pass names:

```text
--one-shot-bufferize
--convert-linalg-to-loops
--convert-scf-to-cf
--convert-func-to-llvm
--convert-to-llvm
--reconcile-unrealized-casts
```

The one-shot bufferization help listed
`bufferize-function-boundaries` and
`function-boundary-type-conversion=<value>`, including
`identity-layout-map`. The Func-to-LLVM help listed
`use-bare-ptr-memref-call-conv`.

The tested bufferization command uses this pass pipeline:

```text
builtin.module(one-shot-bufferize{bufferize-function-boundaries function-boundary-type-conversion=identity-layout-map})
```

It converts the three tensor function arguments to static `memref<4x4xf32>`
arguments while keeping the function result-less.

The tested lowering command uses:

```text
--convert-linalg-to-loops
--convert-scf-to-cf
--convert-func-to-llvm=use-bare-ptr-memref-call-conv=1
--convert-to-llvm
--reconcile-unrealized-casts
```

The `--verify-each` option is enabled. The output was verified and contained
only LLVM dialect operations; the run script also checks that Linalg, MemRef,
SCF, Arith, and Func operations are not left at that stage.

Translation and object generation were tested with:

```text
mlir-translate <llvm-dialect.mlir> --mlir-to-llvmir -o <llvm.ll>
llc -filetype=obj -mtriple=x86_64-unknown-linux-gnu -O0 <llvm.ll> -o <kernel.o>
```

`llvm-nm --defined-only <kernel.o>` reported:

```text
0000000000000000 T matmul
```

The exact successful commands and the pipeline are preserved in
[`commands.txt`](../../artifacts/native-execution/compiler/commands.txt) and
[`pipeline.txt`](../../artifacts/native-execution/compiler/pipeline.txt).
