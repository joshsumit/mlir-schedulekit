module {
  func.func @matmul(%a: tensor<4x4xf32>, %b: tensor<4x4xf32>, %c: tensor<4x4xf32>) {
    %result = linalg.matmul
        ins(%a, %b : tensor<4x4xf32>, tensor<4x4xf32>)
        outs(%c : tensor<4x4xf32>) -> tensor<4x4xf32>
    return
  }
}
