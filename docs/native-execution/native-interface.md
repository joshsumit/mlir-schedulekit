# Milestone 0 Native Interface

The selected path is a native x86-64 object linked with the C++ runner. The
declaration below was written only after inspecting the bufferized MLIR,
LLVM-dialect function, translated LLVM IR, and object symbol.

## Function boundary by stage

Source payload signature:

```mlir
func.func @matmul(
    %a: tensor<4x4xf32>,
    %b: tensor<4x4xf32>,
    %c: tensor<4x4xf32>)
```

The function has no return value. `%a` and `%b` are read operands; `%c` is the
output/accumulator operand and is updated in place by `linalg.matmul`.

After one-shot bufferization with function-boundary conversion:

```mlir
func.func @matmul(
    %arg0: memref<4x4xf32>,
    %arg1: memref<4x4xf32>,
    %arg2: memref<4x4xf32>)
```

After Func-to-LLVM conversion with
`use-bare-ptr-memref-call-conv=1`:

```mlir
llvm.func @matmul(
    %arg0: !llvm.ptr,
    %arg1: !llvm.ptr,
    %arg2: !llvm.ptr)
```

Translated LLVM IR:

```llvm
define void @matmul(ptr %0, ptr %1, ptr %2) {
```

`llvm-nm --defined-only` confirms a global text symbol named `matmul`. The
native declaration used by the runner is:

```cpp
extern "C" void matmul(float* a, float* b, float* c);
```

## Memory representation and ownership

The bare-pointer calling convention is selected for this static-shape function.
The lowered function receives three pointers to contiguous `f32` data. Its
LLVM-dialect body reconstructs each static memref descriptor with the passed
pointer as both allocated and aligned pointer, offset `0`, sizes `[4, 4]`, and
strides `[4, 1]`.

The runner owns three separate `std::array<float, 16>` objects for A, B, and C.
Their storage remains alive for the complete call. The kernel does not allocate
or free these buffers; it reads A and B and writes C. The runner initializes C
to zero before invocation and reads it after return. The three arrays do not
alias.
