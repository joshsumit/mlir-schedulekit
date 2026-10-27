# Milestone 0 Correctness Case

The test uses one static `4 x 4 x 4` `f32` matrix multiplication. Matrices are
row-major. The generated kernel computes `C += A * B`; the runner initializes
`C` to zero, so the tested result is `C = A * B`.

## Deterministic inputs

```text
A =
 1  2  3  4
 5  6  7  8
 9 10 11 12
13 14 15 16

B =
2 1 3 5
4 2 1 3
1 5 2 4
3 2 6 1

Initial C =
0 0 0 0
0 0 0 0
0 0 0 0
0 0 0 0
```

These distinct, non-symmetric matrices make transposed indexing and swapped
operands observable. Every expected output value is nonzero.

## Reference algorithm and expected output

The independent reference uses three straightforward nested loops:

```text
for row in [0, 4):
  for column in [0, 4):
    for inner in [0, 4):
      C[row, column] += A[row, inner] * B[inner, column]
```

Expected output:

```text
25  28  35  27
65  68  83  79
105 108 131 131
145 148 179 183
```

The runner compares all 16 output elements using:

```text
absolute error <= 1.0e-5
    OR
absolute error <= 1.0e-5 * abs(expected)
```

On the successful run, maximum absolute error was `0`, maximum relative error
was `0`, and mismatch count was `0`.
