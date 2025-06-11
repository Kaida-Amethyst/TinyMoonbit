# TinyMoonbit

TinyMoonbit 是一个极度简化的类 Moonbit 语言编译器项目，其复杂度相当于 C 语言的层级。本项目旨在为 [llvm.mbt](https://github.com/moonbitlang/llvm.mbt) LLVM binding 项目以及仿 LLVM 项目 Aether 提供一个完整的教学示例，展示如何使用 Moonbit 语言开发一个能够生成 LLVM IR 的编译器。

## TinyMoonbit 语言特性

TinyMoonbit 去除了 Moonbit 的绝大部分高级特性，只保留了最核心的编程构造：

### 数据类型

- **基本类型**：`Bool`, `Int`, `Int64`, `UInt`, `UInt64`, `Float`, `Double`
- **引用类型**：`Ref[T]` - 指针类型，`Ref[Int]` 表示 Int 的指针
- **数组类型**：`Array[T]` - 堆分配的动态数组
- **结构体**：用户自定义的复合数据类型

### 语法结构

#### 1. 变量声明和赋值

```moonbit
let x: Int = 42;
let arr: Array[Int] = [1, 2, 3];
x = 100;  // 无需 mut 关键字
```

#### 2. 函数定义

```moonbit
fn add(x: Int, y: Int) -> Int {
  return x + y;
}

fn modify_ref(ptr: Ref[Int]) -> Unit {
  ptr.val = 20;
}
```

#### 3. 控制流

```moonbit
// 条件语句
if x > 0 {
  return x;
} else {
  return -x;
}

// 循环语句
while i < 10 {
  i = i + 1;
}
```

#### 4. 结构体定义

```moonbit
struct Point {
  x: Int,
  y: Int,
}
```

## LLVM IR 代码生成预览

以下是一些 TinyMoonbit 代码及其对应的 LLVM IR 生成示例：

### 简单函数

**TinyMoonbit:**

```moonbit
fn add(x: Int, y: Int) -> Int {
  return x + y;
}
```

**生成的 LLVM IR:**
```llvm
define i32 @add(i32 %x, i32 %y) {
entry:
  %0 = add i32 %x, %y
  ret i32 %0
}
```

### 条件语句

**TinyMoonbit:**

```moonbit
fn abs(x: Int) -> Int {
  if x < 0 {
    return -x;
  } else {
    return x;
  }
}
```

**生成的 LLVM IR:**
```llvm
define i32 @abs(i32 %x) {
entry:
  %0 = icmp slt i32 %x, 0
  br i1 %0, label %then, label %else

then:
  %1 = sub i32 0, %x
  ret i32 %1

else:
  ret i32 %x
}
```

### 数组操作

**TinyMoonbit:**

```moonbit
fn sum_array(arr: Array[Int]) -> Int {
  let total: Int = 0;
  let i: Int = 0;
  while i < arr.length {
    total = total + arr[i];
    i = i + 1;
  }
  return total;
}
```

**生成的 LLVM IR:**

```llvm
define i32 @sum_array(ptr %arr) {
entry:
  %total = alloca i32
  %i = alloca i32
  store i32 0, ptr %total
  store i32 0, ptr %i
  br label %while.cond

while.cond:
  %0 = load i32, ptr %i
  %1 = call i32 @array_length(ptr %arr)
  %2 = icmp slt i32 %0, %1
  br i1 %2, label %while.body, label %while.end

while.body:
  %3 = load i32, ptr %total
  %4 = load i32, ptr %i
  %5 = call i32 @array_get(ptr %arr, i32 %4)
  %6 = add i32 %3, %5
  store i32 %6, ptr %total
  %7 = load i32, ptr %i
  %8 = add i32 %7, 1
  store i32 %8, ptr %i
  br label %while.cond

while.end:
  %9 = load i32, ptr %total
  ret i32 %9
}
```

## 开发计划

- [x] 词法分析器实现
- [x] 语法分析器实现
- [ ] 语义分析器实现
- [ ] LLVM IR 代码生成器实现
