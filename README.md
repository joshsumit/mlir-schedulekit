# MLIR ScheduleKit

Target-aware MLIR optimization scheduling, native lowering, and performance evaluation framework.

## Overview

MLIR ScheduleKit explores how optimization schedules for structured computations
affect generated IR, native code, correctness, and runtime performance.

The project separates:

    Computation
        ↓
    Optimization Schedule
        ↓
    Target Lowering
        ↓
    Native Execution
        ↓
    Performance Evaluation

The initial workload is `linalg.matmul` on CPU.

## Current Status

The native execution foundation is complete:

    linalg.matmul
        ↓
    bufferization
        ↓
    loop/control-flow lowering
        ↓
    LLVM dialect
        ↓
    LLVM IR
        ↓
    x86-64 native code
        ↓
    C++ runner
        ↓
    correctness validation

The next development stage introduces explicit Transform dialect scheduling.

## Project Goals

ScheduleKit is being built to make optimization decisions:

- explicit;
- reproducible;
- inspectable;
- measurable.

The goal is not simply to generate a fast matrix multiplication kernel.

The goal is to connect:

    schedule decisions
        ↓
    transformed IR
        ↓
    generated code
        ↓
    measured performance

## Documentation

See [ARCHITECTURE.md](ARCHITECTURE.md) for the complete project architecture.

Native execution documentation is available under:

`docs/native-execution/`

## License

Apache License 2.0.