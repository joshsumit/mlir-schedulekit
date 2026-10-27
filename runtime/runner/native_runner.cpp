#include <array>
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <limits>

namespace {

constexpr std::size_t kRows = 4;
constexpr std::size_t kInner = 4;
constexpr std::size_t kColumns = 4;
constexpr float kAbsoluteTolerance = 1.0e-5F;
constexpr float kRelativeTolerance = 1.0e-5F;

using Matrix = std::array<float, kRows * kColumns>;

void matmulReference(const Matrix& a, const Matrix& b, Matrix& c) {
  for (std::size_t row = 0; row < kRows; ++row) {
    for (std::size_t column = 0; column < kColumns; ++column) {
      float sum = 0.0F;
      for (std::size_t inner = 0; inner < kInner; ++inner) {
        sum += a[row * kInner + inner] * b[inner * kColumns + column];
      }
      c[row * kColumns + column] += sum;
    }
  }
}

void printMatrix(const char* label, const Matrix& matrix) {
  std::cout << label << ":\n";
  for (std::size_t row = 0; row < kRows; ++row) {
    for (std::size_t column = 0; column < kColumns; ++column) {
      std::cout << std::setw(8) << matrix[row * kColumns + column];
    }
    std::cout << '\n';
  }
}

}  // namespace

extern "C" void matmul(float* a, float* b, float* c);

int main() {
  Matrix a{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
  Matrix b{2, 1, 3, 5, 4, 2, 1, 3, 1, 5, 2, 4, 3, 2, 6, 1};
  Matrix actual{};
  Matrix expected{};

  printMatrix("Input A", a);
  printMatrix("Input B", b);
  printMatrix("Initial C", actual);

  matmul(a.data(), b.data(), actual.data());
  matmulReference(a, b, expected);

  printMatrix("Generated C", actual);
  printMatrix("Reference C", expected);

  std::size_t mismatches = 0;
  float maxAbsoluteError = 0.0F;
  float maxRelativeError = 0.0F;
  for (std::size_t index = 0; index < actual.size(); ++index) {
    const float absoluteError = std::fabs(actual[index] - expected[index]);
    const float relativeError =
        expected[index] == 0.0F
            ? (absoluteError == 0.0F
                   ? 0.0F
                   : std::numeric_limits<float>::infinity())
            : absoluteError / std::fabs(expected[index]);
    maxAbsoluteError = std::max(maxAbsoluteError, absoluteError);
    maxRelativeError = std::max(maxRelativeError, relativeError);

    if (absoluteError > kAbsoluteTolerance &&
        absoluteError > kRelativeTolerance * std::fabs(expected[index])) {
      ++mismatches;
      std::cerr << "Mismatch at [" << index / kColumns << ", "
                << index % kColumns << "]: expected " << expected[index]
                << ", actual " << actual[index]
                << ", absolute error " << absoluteError
                << ", relative error " << relativeError << '\n';
    }
  }

  std::cout << std::scientific << "Maximum absolute error: "
            << maxAbsoluteError << "\nMaximum relative error: "
            << maxRelativeError << "\nMismatch count: " << mismatches << '\n';
  return mismatches == 0 ? 0 : 1;
}
