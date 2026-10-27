; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define void @matmul(ptr %0, ptr %1, ptr %2) {
  %4 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %2, 0
  %5 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %4, ptr %2, 1
  %6 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %5, i64 0, 2
  %7 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %6, i64 4, 3, 0
  %8 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %7, i64 4, 4, 0
  %9 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %8, i64 4, 3, 1
  %10 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %9, i64 1, 4, 1
  %11 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %1, 0
  %12 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %11, ptr %1, 1
  %13 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %12, i64 0, 2
  %14 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %13, i64 4, 3, 0
  %15 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %14, i64 4, 4, 0
  %16 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %15, i64 4, 3, 1
  %17 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %16, i64 1, 4, 1
  %18 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %0, 0
  %19 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %18, ptr %0, 1
  %20 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %19, i64 0, 2
  %21 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %20, i64 4, 3, 0
  %22 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %21, i64 4, 4, 0
  %23 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %22, i64 4, 3, 1
  %24 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %23, i64 1, 4, 1
  br label %25

25:                                               ; preds = %61, %3
  %26 = phi i64 [ %62, %61 ], [ 0, %3 ]
  %27 = icmp slt i64 %26, 4
  br i1 %27, label %28, label %63

28:                                               ; preds = %25
  br label %29

29:                                               ; preds = %59, %28
  %30 = phi i64 [ %60, %59 ], [ 0, %28 ]
  %31 = icmp slt i64 %30, 4
  br i1 %31, label %32, label %61

32:                                               ; preds = %29
  br label %33

33:                                               ; preds = %36, %32
  %34 = phi i64 [ %58, %36 ], [ 0, %32 ]
  %35 = icmp slt i64 %34, 4
  br i1 %35, label %36, label %59

36:                                               ; preds = %33
  %37 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %24, 1
  %38 = mul nuw nsw i64 %26, 4
  %39 = add nuw nsw i64 %38, %34
  %40 = getelementptr inbounds nuw float, ptr %37, i64 %39
  %41 = load float, ptr %40, align 4
  %42 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %17, 1
  %43 = mul nuw nsw i64 %34, 4
  %44 = add nuw nsw i64 %43, %30
  %45 = getelementptr inbounds nuw float, ptr %42, i64 %44
  %46 = load float, ptr %45, align 4
  %47 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %10, 1
  %48 = mul nuw nsw i64 %26, 4
  %49 = add nuw nsw i64 %48, %30
  %50 = getelementptr inbounds nuw float, ptr %47, i64 %49
  %51 = load float, ptr %50, align 4
  %52 = fmul float %41, %46
  %53 = fadd float %51, %52
  %54 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %10, 1
  %55 = mul nuw nsw i64 %26, 4
  %56 = add nuw nsw i64 %55, %30
  %57 = getelementptr inbounds nuw float, ptr %54, i64 %56
  store float %53, ptr %57, align 4
  %58 = add i64 %34, 1
  br label %33

59:                                               ; preds = %33
  %60 = add i64 %30, 1
  br label %29

61:                                               ; preds = %29
  %62 = add i64 %26, 1
  br label %25

63:                                               ; preds = %25
  ret void
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
