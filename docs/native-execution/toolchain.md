# Milestone 0 Toolchain

The Milestone 0 run was established on 2026-10-26 using the local LLVM/MLIR
build below. The commit is pinned in the run script and checked before it
lowers the workload.

## Host and compilers

Commands and observed output:

```text
$ uname -a
Linux WINPF433SJGL 6.18.33.2-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Thu Jun 18 21:54:43 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

$ clang++ --version
Ubuntu clang version 18.1.3 (1ubuntu1)
Target: x86_64-pc-linux-gnu

$ c++ --version
c++ (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0

$ cmake --version
cmake version 3.31.6

$ ninja --version
1.13.0.git.kitware.jobserver-pipe-1
```

The runner was compiled and linked with `/usr/bin/clang++`.

## LLVM/MLIR source and build

```text
LLVM source tree:
/local/mnt/workspace/MLIR_build_artifacts/llvm_triton/llvm-project

LLVM build tree:
/local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build

$ git -C /local/mnt/workspace/MLIR_build_artifacts/llvm_triton/llvm-project rev-parse HEAD
ac5dc54d509169d387fcfd495d71853d81c46484

$ git -C /local/mnt/workspace/MLIR_build_artifacts/llvm_triton/llvm-project describe --tags --always --dirty
llvmorg-23-init-2125-gac5dc54d5091

$ /local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build/bin/llvm-config --version
23.0.0git

$ /local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build/bin/llvm-config --targets-built
AMDGPU NVPTX X86 Hexagon
```

`git status --short` in the LLVM source tree produced no output when inspected.

Relevant configured CMake cache values:

```text
CMAKE_BUILD_TYPE:STRING=RelWithDebInfo
CMAKE_CXX_COMPILER:UNINITIALIZED=/usr/bin/clang++
LLVM_ENABLE_PROJECTS:STRING=llvm;mlir;lld
LLVM_ENABLE_RTTI:BOOL=ON
LLVM_TARGETS_TO_BUILD:STRING=AMDGPU;NVPTX;X86;Hexagon
MLIR_ENABLE_EXECUTION_ENGINE:BOOL=ON
```

The run script checks the exact source revision above and requires a clean
source tree. Set `MLIR_BUILD_DIR` when using this same pinned build at a
different location.

## MLIR tools

Commands:

```text
$ /local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build/bin/mlir-opt --version
LLVM version 23.0.0git

$ /local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build/bin/mlir-translate --version
LLVM version 23.0.0git

$ /local/mnt/workspace/MLIR_build_artifacts/llvm_triton/build/bin/mlir-runner --version
LLVM version 23.0.0git
```

The build also provides `llc` and `llvm-nm`, used to create and inspect the
native object.
