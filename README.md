# TinyMoonbit

TinyMoonbit 是一种语法类似 Moonbit 的微型编程语言，其层级与 C 语言相近。它作为教学项目，旨在为 [llvm.mbt](https://github.com/moonbitlang/llvm.mbt) (Moonbit 官方的 LLVM binding) 以及 [MoonLLVM](https://github.com/Kaida-Amethyst/MoonLLVM) (一个使用 Moonbit 编写的类 LLVM 编译后端框架) 提供支持。

## 核心语言特性

### 类型，变量与 `let` 语句

TinyMoonbit 包含以下基本数据类型：`Int`, `Int64`, `UInt`, `UInt64`, `Double`, `Float`。

使用 `let` 来声明或初始化变量。允许省略类型标记，但必须从表达式中推导出类型。

```moonbit
let x: Int = 1
let y: Double = 1.0
let z = 1.0f // z is Double
```

TinyMoonbit 也允许变量遮蔽 (Shadowing)，可以重复定义同名变量。

```moonbit
let x: Int = 1
let x = 2 // Ok
```

不允许声明未初始化的变量。

```moonbit
let x: Int;
println(x); // 结果是未定义的
```

### 表达式与类型转换

支持常规的算术运算、函数调用和数组索引。类型系统非常严格，不会进行隐式类型转换。

```moonbit
let x: Int = 1 + 2;
let y: Double = 1.0 + 2.0;

// 以下代码会编译报错，因为 Int 和 Double 不能直接相加
// let z: Int = 1 + 2.0;
```

### 赋值

可以对已声明的mut变量进行赋值。与 Moonbit 相同。

```moonbit
let x: Int = 1;
x = 2; // Error

let mut x: Int = 1
x = 2; // Ok

### 分支与循环

支持 `if-else` 条件分支和 `while` 循环。

```moonbit
let mut x: Int = 1;
let mut y: Int = 0;
if x > 0 {
  y = x;
} else {
  y = -x;
}

let count: Int = 0;
while y > 0 {
  count = count + 1;
  y = y - 1;
}
```

### 数组

支持在栈上分配的静态数组。声明数组时必须提供至少初始值，因为编译器需要根据初始值来确定数组的大小。

```moonbit
let ns: Array[Int] = [1, 2, 3, 4];
println(ns[1]); // 输出 2
```

### 结构体

支持定义结构体。

```moonbit
struct Point {
  x: Double
  y: Double
}

let pt = Point::{ x: 1.0, y: 2.0}

```

### 函数

函数的定义和调用语法与其他主流语言类似。

```moonbit
fn add(x: Int, y: Int) -> Int {
  return x + y;
}

fn main {
  let z = add(1, 2);
  println(z); // 输出 3
}
```

### 参考语法


```
TinyMoonBit Syntax

Program :=
    TopFunction
  | ExternFunction
  | TopLet
  | StructDef
  | EnumDef

ExternFunction :=
  "extern" "fn" func_name "(" param* ")" "->" Type "=" stringlit; 

TopLet :=
  "let" ident TypeAnnote? "=" Expr

StructDef :=
  "struct" upper_ident "{" struct_item* "}"

struct_item := ident TypeAnnote ";"

EnumDef :=
  "enum" upper_ident "{" enum_item* "}"

enum_item := upper_ident ("(" Type+ ")")?

TopFunction :=
  "fn" ident "(" param* ")" "->" Type "{" Stmt* "}"

Stmt :=
    LetStmt
  | LetMutStmt
  | AssignStmt
  | WhileStmt
  | ForStmt
  | ReturnStmt

LetStmt :=
  "let" pattern TypeAnnote? "=" Expr

LetMutStmt :=
  "let" "mut" ident TypeAnnote? "=" Expr

AssignStmt :=
  left_value assign_op Expr

left_value :=
    ident
  | left_value "[" Expr "]" ;; Array Access
  | left_value "." ident ;; Field Access

assign_op := "=" | "+=" | "-=" | "*="

WhileStmt :=
  "while" Expr BlockExpr

ForStmt :=
 "for" for_init? ";" for_cond? ";" for_step? BlockExpr

for_init := (ident "=" Expr)*
for_cond := Expr
for_step := (ident assign_op Expr)*

ReturnStmt := "return" Expr? ";"

Expr :=
    ApplyExpr
  | ApplyExpr binop ApplyExpr ;; Binary
  | IfExpr
  | MatchExpr
  | BlockExpr

unop := "-" | "+" | "!"

binop: "+" | "-" | "*" | "/" | "%" | ">>" | "<<" |
       "==" | ">=" | "<=" | ">" | "<" | "!="

ApplyExpr :=
    AtomExpr
  | ApplyExpr "[" Expr "]"  ;; Array Access
  | ApplyExpr "(" Expr* ")" ;; Function Call 

AtomExpr :=
    Literal
  | ident
  | "(" ")" ;; Unit
  | "(" Expr ")"  ;; Paren
  | "(" expr_list ")"  ;; Tuple
  | "[" expr_list? "]" ;; Array
  | BlockExpr
  | IfExpr
  | MatchExpr
  | StructConstruct

BlockExpr :=
  "{" (Stmt ';'?)* "}"

IfExpr :=
  "if" Expr BlockExpr ("else" BlockExpr)?

MatchExpr :=
  "match" Expr "{" match_item "}"

StructConstruct :=
  Upper "::" "{" (ident ":" Expr)* "}"

match_item :=
  pattern ("if" Expr)? "=>" Expr ";"
```

### 关于语句末尾分号的说明

与MoonBit一致，每一行语句的末尾如果进行了换行，是可以不带分号的；但如果不进行换行，则必须带分号。

```
let x: Int = 1; let y = 3  // 这里x的声明后面必须带一个分号，但y的声明就可以不带。
```

### 编译流程

1. Tokenize: lexer.mbt
2. Parsing: parser.mbt
3. TypeCheck: typecheck.mbt
4. Knf Convert: knf.mbt
5. CodeGen: codegen.mbt
