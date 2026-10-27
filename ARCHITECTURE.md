# MLIR ScheduleKit

**Target-Aware Optimization Scheduling and Evaluation**

## 1. Purpose

MLIR ScheduleKit is a standalone MLIR-based project for constructing, applying, and evaluating optimization schedules for structured computations.

The initial workload is matrix multiplication represented as `linalg.matmul` on tensors.

The project addresses a practical compiler-engineering question:

> Given a structured operation and a hardware target, which ordered sequence of transformations should be applied, with which parameters, and what effect does that sequence have on the transformed IR, generated code, correctness, and runtime performance?

ScheduleKit makes optimization decisions explicit, reproducible, inspectable, and measurable.

Its initial purpose is not to discover an automatically optimal schedule. Its purpose is to expose the relationship between:

```text
schedule decisions
    -> transformed IR
    -> lowered IR
    -> generated machine code
    -> measured performance
```

ScheduleKit is not an autotuner, a general-purpose ML compiler, or a replacement for existing compiler stacks.

The first implementation targets x86-64 CPU execution. The architecture must permit additional hardware targets without redesigning the scheduling workflow, but V1 does not attempt to provide universal hardware support.


## 2. Project Identity

ScheduleKit's defining statement is:

> MLIR ScheduleKit makes optimization schedules explicit and connects scheduling decisions to transformed IR, generated code, correctness, and measured performance.

The value of the project is not merely producing a fast matrix multiplication implementation. The value is understanding and demonstrating why a schedule produces a particular result.

A schedule that is slower than the baseline is still a useful result when the experiment is reproducible and the available evidence explains, or helps investigate, the difference.


## 3. Core Model

ScheduleKit separates six concerns:

```text
Computation
    |
    v
Schedule
    |
    v
Transformation
    |
    v
Target Lowering
    |
    v
Execution
    |
    v
Measurement and Analysis
```

### 3.1 Computation

The computation describes what is calculated.

For V1:

```text
C[M, N] = A[M, K] x B[K, N]
```

The computation is represented using `linalg.matmul` on tensors and contains no target-specific optimization policy.

### 3.2 Schedule

The schedule describes how the computation should be organized before target lowering.

A schedule may include:

- tiling;
- multi-level tiling;
- loop interchange;
- packing;
- structured vectorization;
- vector lowering decisions;
- unrolling;
- canonicalization and cleanup.

The schedule is ordered. Transformations are not treated as interchangeable switches.

For example:

```text
tile -> vectorize
```

is not assumed to be equivalent to:

```text
vectorize -> tile
```

Similarly, lowering structured operations too early may remove information needed by subsequent transformations.

### 3.3 Transformation

Transformation applies the schedule to the computation and produces progressively transformed MLIR.

### 3.4 Target Lowering

Target lowering converts the scheduled program through the representations required by the selected target and toolchain.

### 3.5 Execution

Execution runs the compiled kernel with controlled inputs and measurement conditions.

### 3.6 Measurement and Analysis

Measurement records correctness and performance data. Analysis connects this evidence to schedule and code-generation decisions without making unsupported conclusions.


## 4. Implementation Philosophy

ScheduleKit begins as a complete vertical slice, not as a large software framework.

The boundaries in this document describe responsibilities. They do not require extensive C++ class hierarchies, factories, plugin systems, or custom dialects.

V1 should prefer existing MLIR and LLVM tools. Custom infrastructure should be introduced only when an observed requirement cannot be handled cleanly with the existing toolchain.

The first priority is to make this path work end to end:

```text
workload
    -> schedule
    -> transformed IR
    -> lowered executable
    -> correctness validation
    -> performance measurement
    -> preserved experiment bundle
```

ScheduleKit must not begin by implementing:

- a custom dialect;
- a target plugin hierarchy;
- an automatic schedule search engine;
- a sophisticated pass-management framework;
- automated performance-cause inference.


## 5. V1 Scope

V1 supports:

- MLIR and LLVM;
- `linalg.matmul` on tensors;
- `f32` element type;
- static tensor shapes;
- x86-64 CPU target;
- single-threaded kernel execution;
- Transform dialect schedules;
- native code generation;
- numerical correctness validation;
- reproducible runtime measurement;
- intermediate IR preservation;
- compiler diagnostic preservation;
- generated assembly preservation where available;
- machine-readable experiment results;
- a human-readable experiment report.

V1 evaluates multiple matrix shapes, including:

```text
32 x 32 x 32
128 x 128 x 128
512 x 512 x 512
1024 x 64 x 1024
64 x 1024 x 64
```

These shapes provide small, square, and rectangular workloads. The exact set may be adjusted when measurements reveal setup or runtime constraints, but all recorded experiments must preserve their actual shapes.


## 6. Non-Goals

V1 does not attempt to implement:

- arbitrary Linalg operations;
- complete neural-network compilation;
- GPU lowering;
- Arm or RISC-V support;
- custom accelerator support;
- dynamic shapes;
- sparse tensors;
- mixed-precision kernels;
- multithreaded execution;
- distributed execution;
- automatic schedule search;
- ML-based autotuning;
- runtime schedule selection;
- a custom MLIR dialect;
- GraphFlow integration;
- dependency on TVM, IREE, XLA, or another compiler stack.

Other compiler stacks may be studied for architectural and technical inspiration, but they are not implementation dependencies of ScheduleKit.


## 7. Toolchain Reproducibility

ScheduleKit must pin the LLVM/MLIR revision used for development and experiments.

Every experiment bundle must record:

- LLVM repository revision;
- build configuration where relevant;
- target triple;
- CPU model where available;
- enabled CPU features;
- workload shape and data type;
- schedule and schedule parameters;
- exact pass pipeline;
- compiler and linker options;
- execution configuration;
- ScheduleKit revision.

Pass names, pass availability, Transform dialect syntax, and lowering requirements may change across LLVM/MLIR revisions. The implementation must derive its concrete pipeline from the pinned revision rather than assuming that examples from another revision remain valid.


## 8. Inputs

An experiment combines four inputs:

```text
Workload
    +
Schedule
    +
Target Configuration
    +
Measurement Configuration
```

### 8.1 Workload

A workload is the payload MLIR containing the structured computation. V1 uses separate workload files for each static matrix shape. Example: 
```text workloads/matmul/ 
├── matmul_32x32x32_f32.mlir 
├── matmul_128x128x128_f32.mlir 
├── matmul_512x512x512_f32.mlir 
├── matmul_1024x64x1024_f32.mlir 
└── matmul_64x1024x64_f32.mlir
```
An experiment references the concrete workload file it executes.

V1 does not require a workload generator. A generator may be introduced later if maintaining static workload files becomes unnecessarily repetitive.

The workload must not encode a specific optimization schedule..

### 8.2 Schedule

A schedule is an MLIR Transform dialect program supplied separately from the payload IR wherever supported by the pinned toolchain.

Example:

```text
schedules/matmul/tiled_vectorized.mlir
```

A schedule describes transformations and their ordering. It must not contain benchmark policy or target-independent workload-generation logic.

### 8.3 Target Configuration

The target configuration contains only information required by the current implementation.

For V1, it may include:

- target triple;
- CPU name;
- CPU feature flags;
- compiler options;
- target lowering configuration;
- available measurement capabilities.

The target configuration keeps x86-specific policy isolated, but V1 does not require a generic target plugin framework.

### 8.4 Measurement Configuration

The measurement configuration defines:

- warm-up iterations;
- measured iterations;
- correctness tolerances;
- requested output artifacts;
- optional hardware-counter collection.


## 9. Experiment Definition

YAML is the initial experiment format.

Example:

```yaml
experiment:
  name: matmul-512-tiled-vectorized

workload:
  file: workloads/matmul/matmul_512x512x512_f32.mlir
  operation: linalg.matmul
  dtype: f32
  m: 512
  n: 512
  k: 512

target:
  name: x86-native
  triple: x86_64-unknown-linux-gnu
  cpu: native
  features: []

schedule:
  file: schedules/matmul/tiled_vectorized.mlir
  parameters:
    outer_tile: [64, 64, 32]
    inner_tile: [8, 8, 1]

measurement:
  warmups: 10
  iterations: 100
  verify: true
  absolute_tolerance: 1.0e-5
  relative_tolerance: 1.0e-5
  collect_hardware_counters: false
```

The exact schema may evolve during Milestone 1. Schema changes must remain version-controlled.


## 10. Schedule Parameter Binding

Schedule implementation proceeds in two steps.

### 10.1 Fixed Schedule First

The first Transform dialect schedule must use fixed parameters directly in the
schedule.

For example, the first tiling experiment may contain fixed tile sizes such as:

```text
[64, 64, 32]

```
The purpose is to establish that, with the pinned LLVM/MLIR revision:
payload MLIR
    + fixed Transform IR
    -> transformed payload MLIR


### 10.2 Experiment-Driven Parameters

After the fixed schedule works, parameters supplied by an experiment must be bound to the Transform dialect schedule through a deterministic and reproducible mechanism.

V1 must select the simplest reliable mechanism supported by the pinned LLVM/MLIR revision.

Possible mechanisms may include:

Transform dialect parameters;
generated Transform IR;
programmatic schedule construction.

The architecture does not require a template engine, textual substitution system, or C++ schedule builder.

No custom parameterization infrastructure should be implemented until the capabilities and constraints of the pinned LLVM/MLIR revision have been established.

Regardless of the selected mechanism, the final resolved Transform IR applied to the payload must be preserved in the experiment bundle.    

## 11. Execution Flow



The primary execution flow is:

```text
Experiment YAML
      |
      v
Validate Configuration
      |
      v
Load Workload MLIR
      |
      v
Resolve Target Configuration
      |
      v
Resolve Schedule Parameters
      |
      v
Produce Final Transform IR
      |
      v
Apply Transformations
      |
      v
Save Intermediate IR and Diagnostics
      |
      v
Run Target Lowering Pipeline
      |
      v
Generate Native Code
      |
      v
Execute Correctness Check
      |
      v
Run Kernel Benchmark
      |
      v
Write Result and Report
```

A failure at any stage must stop the current experiment and produce a classified outcome with preserved diagnostics.


## 12. Initial Schedules

Milestone 1 contains three schedules.

The exact pass sequence must be validated against the pinned LLVM/MLIR revision. The architecture defines the intended stages, not unverified pass names.

### 12.1 Schedule A: Baseline

Purpose: establish the simplest correct ScheduleKit path from `linalg.matmul` to native execution.

```text
linalg.matmul
    -> required cleanup
    -> bufferization
    -> standard CPU lowering
    -> LLVM lowering
    -> native code
```

This is the ScheduleKit unoptimized baseline. It must not deliberately disable ordinary downstream compiler correctness or code-generation requirements.

### 12.2 Schedule B: Tiled

Purpose: measure the effect of explicit structured tiling.

```text
linalg.matmul
    -> Transform dialect tiling
    -> canonicalization and cleanup
    -> bufferization
    -> CPU lowering
    -> LLVM lowering
    -> native code
```

### 12.3 Schedule C: Tiled and Vectorized

Purpose: measure the combined effect of tiling and explicit structured vectorization.

```text
linalg.matmul
    -> Transform dialect tiling
    -> structured vectorization
    -> vector lowering
    -> remaining bufferization and lowering stages
    -> LLVM lowering
    -> native code
```

The relative ordering of vector lowering, bufferization, and other conversion stages must be established from the requirements of the pinned toolchain and the actual IR produced.

All three schedules must use identical downstream LLVM optimization settings wherever comparison requires them to be identical.

ScheduleKit must not assume that explicit vectorization will outperform the baseline. Generated code and measurements determine the result.


## 13. Baselines and References

ScheduleKit distinguishes three forms of comparison.

### 13.1 ScheduleKit Baseline

The simplest correct path implemented by ScheduleKit.

This baseline answers:

> Did an explicit ScheduleKit transformation improve or degrade the result relative to the simplest ScheduleKit lowering path?

### 13.2 Toolchain-Optimized Baseline

A reproducible optimized path using the selected LLVM/MLIR toolchain's normal optimization configuration.

This baseline answers:

> Did the explicit schedule provide useful structure beyond what the selected toolchain already obtains?

The exact definition must be documented with its pipeline and options.

### 13.3 External Library Reference

A mature matrix multiplication implementation, such as an appropriate BLAS library, may be included after the ScheduleKit measurement path is stable.

This reference answers:

> How far is the generated kernel from a mature external implementation on the same hardware and workload?

An external library comparison is not required for Milestone 1 completion and must not be presented as a like-for-like compiler-pipeline comparison without documenting the differences.


## 14. Experiment Outcomes

Every experiment must produce exactly one primary outcome category:

- `configuration-failure`;
- `transform-failure`;
- `lowering-failure`;
- `compile-failure`;
- `correctness-failure`;
- `execution-failure`;
- `measurement-failure`;
- `success`.

A successful experiment produces valid correctness and benchmark results.

Performance relative to another schedule is comparison data, not an execution outcome. A schedule that executes correctly but is slower than the baseline remains a successful experiment.

Each failed experiment must preserve:

- completed stage artifacts;
- the failed stage;
- compiler diagnostics;
- the invoked command or pipeline;
- experiment metadata.


## 15. Intermediate Artifacts

ScheduleKit must preserve meaningful intermediate representations.

An experiment may produce:

```text
00-input.mlir
01-scheduled.mlir
02-tiled.mlir
03-vectorized.mlir
04-bufferized.mlir
05-lowered.mlir
06-llvm.mlir
```

The exact stages depend on the schedule and pinned toolchain. File names must reflect stages that actually occurred. ScheduleKit must not emit empty placeholder stages merely to maintain numbering.

At minimum, preserve:

- original payload IR;
- resolved Transform IR;
- IR after the primary schedule transformation;
- IR before final LLVM conversion;
- final LLVM dialect or LLVM IR representation;
- compiler diagnostics;
- pass pipeline;
- generated assembly where available.


## 16. Correctness Validation

Performance results are invalid unless the generated kernel is correct.

Correctness validation must:

- generate deterministic input data from a recorded seed;
- compute or invoke a trusted reference result;
- compare output element by element;
- report maximum absolute error;
- report maximum relative error;
- report mismatch count according to configured tolerances;
- run outside the timed kernel region.

The reference implementation must prioritize clarity and correctness over performance.

The chosen tolerances must be recorded in the experiment configuration and result.


## 17. Measurement Protocol

Kernel measurements must exclude:

- MLIR transformation time;
- native compilation time;
- input allocation;
- input initialization;
- output validation;
- report generation.

Compilation time must be measured separately.

Each successful experiment must record:

- warm-up count;
- measurement iteration count;
- individual samples or sufficient aggregate data to reproduce the reported statistics;
- median execution time;
- a dispersion measurement;
- achieved GFLOP/s;
- compilation time.

For matrix multiplication:

```text
FLOPs = 2 * M * N * K
GFLOP/s = FLOPs / execution_time_seconds / 1e9
```

This convention counts one multiplication and one addition as two floating-point operations.

Where controllable, the experiment should record:

- host CPU model;
- thread count;
- process or thread affinity;
- CPU frequency policy;
- operating-system information;
- background-load caveats.

V1 remains single-threaded at the kernel level.

Hardware performance counters are optional. They must only be reported when available and collected reliably. Missing counters must be reported as unavailable rather than estimated.


## 18. Analysis

ScheduleKit records evidence required to analyze performance.

Evidence may include:

- experiment configuration;
- resolved schedule;
- intermediate MLIR;
- lowered IR;
- generated assembly;
- timing samples;
- achieved GFLOP/s;
- cache and instruction counters when available;
- comparison against baselines.

V1 does not automatically infer the cause of a performance difference.

An experiment report may contain manually written findings, but it must distinguish:

- observed evidence;
- interpretation;
- unverified hypotheses.

For example, ScheduleKit must not claim that register pressure caused a slowdown solely because a larger tile was used. Such a conclusion requires supporting evidence, such as spills visible in generated code or appropriate measured data.


## 19. Experiment Bundle

Every experiment run must produce a self-contained bundle.

Recommended structure:

```text
results/
  <experiment-id>/
    experiment.yaml
    metadata.json
    resolved-schedule.mlir

    ir/
      00-input.mlir
      01-scheduled.mlir
      02-bufferized.mlir
      03-lowered.mlir
      04-llvm.mlir

    compiler/
      pipeline.txt
      commands.txt
      diagnostics.txt

    native/
      assembly.s
      executable

    measurements/
      samples.csv

    result.json
    report.md
```

Artifacts that are unavailable for a particular pipeline may be omitted. The result metadata must identify which artifacts were produced.

The bundle must make it possible to determine:

- what input was compiled;
- which schedule was applied;
- which target was selected;
- which commands and pipeline were used;
- whether the result was correct;
- how performance was measured;
- what evidence supports the report.

Generated results should not all be committed to version control. A small curated set of reference experiments may be retained for documentation and regression purposes.


## 20. Target Extensibility

ScheduleKit is target-extensible, not automatically target-portable.

The scheduling workflow remains stable:

```text
workload
    + schedule
    + target configuration
    -> transformed program
    -> target lowering
    -> execution and measurement
```

A new target may require:

- different legal vector forms;
- different tile sizes;
- different packing strategy;
- different Transform dialect operations;
- different lowering passes;
- different compiler options;
- a different runtime;
- different measurement support.

V1 contains one concrete target configuration for x86-64.

The initial target model should contain only information required by the working implementation. A generalized target API should be introduced only after a second target exposes actual shared and target-specific requirements.

ScheduleKit does not promise that an arbitrary schedule will compile or perform well on arbitrary hardware.


## 21. Suggested Repository Structure

```text
mlir-schedulekit/
├── CMakeLists.txt
├── README.md
├── ARCHITECTURE.md
├── LICENSE
│
├── cmake/
│
├── configs/
│   └── targets/
│       └── x86-native.yaml
│
├── workloads/
│   └── matmul/
│       ├── matmul_32x32x32_f32.mlir
│       ├── matmul_128x128x128_f32.mlir
│       ├── matmul_512x512x512_f32.mlir
│       ├── matmul_1024x64x1024_f32.mlir
│       └── matmul_64x1024x64_f32.mlir
│
├── schedules/
│   └── matmul/
│       ├── baseline.mlir
│       ├── tiled.mlir
│       └── tiled_vectorized.mlir
│
├── experiments/
│   └── matmul/
│       ├── baseline-512.yaml
│       ├── tiled-512.yaml
│       └── tiled-vectorized-512.yaml
│
├── tools/
│   └── schedulekit/
│
├── runtime/
│   ├── runner/
│   └── reference/
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── lit/
│
├── docs/
│   ├── experiments/
│   └── findings/
│
└── results/
```

This layout is a starting point, not a requirement to create empty modules. Directories should be added when their first concrete artifact is implemented.


## 22. Minimal Command-Line Experience

The initial tool should support one end-to-end operation:

```text
schedulekit run <experiment.yaml>
```

This command should:

1. load and validate the experiment;
2. resolve workload, schedule, and target inputs;
3. apply the schedule;
4. run the lowering pipeline;
5. create native code;
6. validate correctness;
7. benchmark the kernel;
8. write the experiment bundle;
9. return a non-zero exit status for failed experiments.

Additional commands such as `inspect`, `compare`, or schedule-space exploration should be added only after `run` is reliable.
## 23. Milestone 0: 
Native Execution Proof Before implementing schedule management or benchmarking infrastructure, ScheduleKit must establish the smallest reproducible path from one static `f32` `linalg.matmul` workload to callable native code. This milestone must establish: - the MLIR-to-native lowering path; - the callable kernel interface; - how input and output buffers cross the native invocation boundary; - how the runner allocates and initializes those buffers; - how the generated kernel is invoked; - how the result is returned or observed; - how the result is validated against a trusted reference. The initial execution path is:
 ```text static f32 linalg.matmul -> required lowering -> native code -> runner -> correctness validation
```
Producing LLVM IR alone does not satisfy this milestone. The generated computation must be callable by the runner and produce a correct result.

No schedule parameterization, experiment orchestration, or performance optimization is required for Milestone 0.

Milestone 0 is complete when one static matrix multiplication can be lowered, compiled, invoked through the chosen native interface, and validated for correctness.

## 24. Milestone 1: End-to-End Vertical Slice

Milestone 1 proves the complete project workflow.

### 24.1 Required Capabilities

- Pin and document an LLVM/MLIR revision.
- Build or use the required MLIR and LLVM tools.
- Compile one static `f32` `linalg.matmul` workload to native code.
- Execute the generated kernel.
- Validate its output against a trusted reference.
- Implement Schedule A: Baseline.
- Implement Schedule B: Tiled.
- Implement Schedule C: Tiled and Vectorized.
- Preserve resolved schedules and intermediate IR.
- Preserve exact pipelines, commands, and diagnostics.
- Measure compilation and kernel execution separately.
- Produce `result.json` and `report.md`.
- Run the schedules across small, square, and rectangular shapes.

### 24.2 Acceptance Criteria

Milestone 1 is complete when:

1. all three schedules can be invoked using experiment files;
2. successful experiments generate native executable kernels;
3. successful experiments pass numerical correctness validation;
4. every experiment produces a classified outcome;
5. intermediate artifacts and diagnostics are preserved;
6. runtime measurements follow the documented protocol;
7. the same experiment can be reproduced from its preserved configuration and toolchain revision;
8. a report compares the schedules without making unsupported performance claims;
9. at least one result is analyzed through the path:

```text
schedule
    -> transformed MLIR
    -> lowered/generated code
    -> measured behavior
    -> evidence-based interpretation
```

Milestone 1 does not require Schedule C to outperform Schedule A or Schedule B.


## 25. Later Milestones

Later work is ordered by learning value and dependence on the working vertical slice.

### Milestone 2: Hierarchical Scheduling

- outer/cache tiling;
- inner/register tiling;
- loop interchange;
- packing;
- unrolling;
- schedule-parameter sweeps performed manually or through simple batch execution.

### Milestone 3: Shape Robustness

- non-divisible dimensions;
- remainder handling;
- additional rectangular workloads;
- dynamic shapes;
- schedule applicability checks.

### Milestone 4: Deeper Performance Analysis

- hardware performance counters;
- generated-code inspection support;
- spill and reload investigation;
- arithmetic-intensity calculation;
- roofline analysis;
- stable external BLAS reference comparison.

### Milestone 5: Parallel Execution

- multithreaded outer tiles;
- thread-count controls;
- affinity controls;
- scaling measurements;
- interaction between parallel and vector schedules.

### Milestone 6: Schedule-Space Exploration

- parameter sweeps;
- schedule comparison;
- applicability filtering;
- result ranking based on explicit metrics;
- optional search strategies.

### Milestone 7: Second Hardware Target

Add one genuinely different target and use the implementation experience to define the smallest justified common target interface.

Possible candidates include:

- Arm CPU;
- RISC-V CPU;
- GPU;
- custom accelerator.

The second target should not be selected until the x86-64 workflow is stable.


## 26. Failure Modes the Project Must Expose

ScheduleKit should make the following failure classes observable rather than hiding them:

- a Transform dialect match does not find the expected operation;
- a transformation is not applicable to the current payload IR;
- a transformation invalidates assumptions required by a later stage;
- bufferization fails or produces unexpected memory behavior;
- vector operations cannot be lowered using the selected pipeline;
- the generated kernel is numerically incorrect;
- a schedule compiles but performs worse than the baseline;
- an oversized tile increases cache pressure;
- an oversized register tile contributes to spills;
- excessive unrolling increases code size;
- explicit vectorization produces no useful target vector instructions;
- LLVM already optimizes the baseline sufficiently that an explicit schedule adds no benefit;
- a schedule that performs well for a square matrix performs poorly for a rectangular matrix.

The project must report evidence. It must not automatically assert causal explanations without verification.


## 27. Documentation Requirements

The repository must eventually contain:

- build instructions tied to the pinned LLVM/MLIR revision;
- one end-to-end quick-start experiment;
- the experiment schema;
- schedule authoring guidance;
- measurement methodology;
- explanation of outcome categories;
- one detailed performance investigation;
- representative before-and-after MLIR;
- representative generated assembly;
- exact reproduction commands.

Detailed write-ups should be added as each capability is implemented. The architecture document defines the boundaries and required behavior; it should not become a tutorial for every MLIR transformation.


## 28. Definition of Success

V1 is successful when ScheduleKit can answer the following question with preserved evidence:

> Why is schedule A faster or slower than schedule B for this matrix shape on this CPU?

The answer must be traceable through:

```text
experiment configuration
    -> resolved schedule
    -> transformation sequence
    -> intermediate MLIR
    -> lowered/generated code
    -> correctness result
    -> measured performance
    -> evidence-based interpretation
```

The framework does not need to identify a universally optimal schedule.

It must provide a trustworthy and reproducible way to construct schedules, observe their effects, compare results, and investigate why those results occurred.
