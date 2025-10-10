///|
test "Atom Expr Knf Convert" {
  let code =
    #|fn foo() -> Int {
    #|  let b = 1
    #|  let a = true
    #|  let mut a = "hello"
    #|  let a = 3.14
    #|  let mut a = ()
    #|  let a = b
    #|  a
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn foo() -> Int {
    #|  let b: Int = 1;
    #|  let a: Bool = true;
    #|  let mut a$1: String = "hello";
    #|  let a$2: Double = 3.14;
    #|  let mut a$3: Unit = ();
    #|  let a$4: Int = b;
    #|  a$4
    #|}
  inspect(knf_func, content=expected)
}

///|
test "Binary Expr Knf Convert" {
  let code =
    #|fn foo() -> Int {
    #|  let a = 1 + 2 * 3 - 4 / 5
    #|  a
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn foo() -> Int {
    #|  let tmp: Int = 2;
    #|  let tmp$1: Int = 3;
    #|  let tmp$2: Int = 1;
    #|  let tmp$3: Int = tmp * tmp$1;
    #|  let tmp$4: Int = 4;
    #|  let tmp$5: Int = 5;
    #|  let tmp$6: Int = tmp$2 + tmp$3;
    #|  let tmp$7: Int = tmp$4 / tmp$5;
    #|  let a: Int = tmp$6 - tmp$7;
    #|  a
    #|}
  inspect(knf_func, content=expected)
}

///|
test "Array Expr Knf Convert" {
  let code =
    #|fn foo() -> Int {
    #|  let a = [1, 2, 3, 4, 5]
    #|  a[3]
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn foo() -> Int {
    #|  let tmp: Int = 1;
    #|  let tmp$1: Int = 2;
    #|  let tmp$2: Int = 3;
    #|  let tmp$3: Int = 4;
    #|  let tmp$4: Int = 5;
    #|  let a: Array[Int] = [tmp, tmp$1, tmp$2, tmp$3, tmp$4];
    #|  let tmp$5: Int = 3;
    #|  a[tmp$5]
    #|}
  inspect(knf_func, content=expected)
}

///|
test "Tuple Expr Knf Convert" {
  let code =
    #|fn foo() -> Int {
    #|  let a = (1, true, "hello", 3.14, ())
    #|  a.0
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)

  //println(knf_func)
  let expected =
    #|fn foo() -> Int {
    #|  let tmp: Int = 1;
    #|  let tmp$1: Bool = true;
    #|  let tmp$2: String = "hello";
    #|  let tmp$3: Double = 3.14;
    #|  let tmp$4: Unit = ();
    #|  let a: (Int, Bool, String, Double, Unit) = (tmp, tmp$1, tmp$2, tmp$3, tmp$4);
    #|  a.0
    #|}
  inspect(knf_func, content=expected)
}

///|
test "Call Expr Knf Convert" {
  let code =
    #|extern fn add(a: Int, b: Int) -> Int = "add";
    #|
    #|fn foo() -> Int {
    #|  let a = add(1, 2)
    #|  a
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let _ = ctx.new_name("add") // extern function
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn foo() -> Int {
    #|  let tmp: Int = 1;
    #|  let tmp$1: Int = 2;
    #|  let a: Int = add(tmp, tmp$1);
    #|  a
    #|}
  inspect(knf_func, content=expected)
}

///|
test "Let Tuple Knf Convert" {
  let code =
    #|fn foo() -> Int {
    #|  let (a, b, c) = (1, true, "hello")
    #|  a
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn foo() -> Int {
    #|  let a: Int = 1;
    #|  let b: Bool = true;
    #|  let c: String = "hello";
    #|  a
    #|}
  inspect(knf_func, content=expected)
}

///|
test "Assign Knf Convert" {
  let code =
    #|fn foo() -> Int {
    #|  let mut a = 1
    #|  a = 2 + 3
    #|  a
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn foo() -> Int {
    #|  let mut a: Int = 1;
    #|  let tmp: Int = 2;
    #|  let tmp$1: Int = 3;
    #|  let tmp$2: Int = tmp + tmp$1;
    #|  a = tmp$2;
    #|  a
    #|}
  inspect(knf_func, content=expected)

  // PlusAssign
  let code =
    #|fn foo() -> Int {
    #|  let mut a = 1
    #|  a += 2 + 3
    #|  a
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn foo() -> Int {
    #|  let mut a: Int = 1;
    #|  let tmp: Int = 2;
    #|  let tmp$1: Int = 3;
    #|  let tmp$2: Int = tmp + tmp$1;
    #|  let tmp$3: Int = a + tmp$2;
    #|  a = tmp$3;
    #|  a
    #|}
  inspect(knf_func, content=expected)
}

///|
test "If Expr Knf Convert" {
  let code =
    #|extern fn f(a: Int) -> Int = "Foo" ;
    #|
    #|fn fmax(a: Int, b: Int) -> Int {
    #|  let res = if f(a) > f(b) {
    #|    a
    #|  } else {
    #|    b
    #|  }
    #|  res
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let _ = ctx.new_name("f") // extern function
  let f = ctx.top_functions.get("fmax").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn fmax(a: Int, b: Int) -> Int {
    #|  let tmp: Int = f(a);
    #|  let tmp$1: Int = f(b);
    #|  let res: Int = if tmp > tmp$1 {
    #|    a
    #|  } else {
    #|    b
    #|  };
    #|  res
    #|}
  inspect(knf_func, content=expected)
}

///|
test "While Stmt Knf Convert" {
  let code =
    #|fn foo() -> Int {
    #|  let mut i = 0
    #|  while i < 10 {
    #|    i += 1
    #|  }
    #|  i
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn foo() -> Int {
    #|  let mut i: Int = 0;
    #|  while { let tmp: Int = 10; i < tmp } do {
    #|    let tmp$1: Int = 1;
    #|    let tmp$2: Int = i + tmp$1;
    #|    i = tmp$2;
    #|  }
    #|  i
    #|}
  inspect(knf_func, content=expected)
}

///|
test "For Stmt Knf Convert" {
  let code =
    #|fn foo() -> Int {
    #|  let mut sum = 0
    #|  for i = 0; i < 10; i += 1 {
    #|    sum += i
    #|  }
    #|  sum
    #|}
  let ctx = Context::new(code)
  ctx..tokenize()..parse()..typecheck()
  let f = ctx.top_functions.get("foo").unwrap()
  let knf_func = ctx.top_function_to_knf(f)
  let expected =
    #|fn foo() -> Int {
    #|  let mut sum: Int = 0;
    #|  let mut i: Int = 0;
    #|  while { let tmp: Int = 10; i < tmp } do {
    #|    let tmp$1: Int = sum + i;
    #|    sum = tmp$1;
    #|    let tmp$2: Int = 1;
    #|    let tmp$3: Int = i + tmp$2;
    #|    i = tmp$3;
    #|  }
    #|  sum
    #|}
  inspect(knf_func, content=expected)
}
