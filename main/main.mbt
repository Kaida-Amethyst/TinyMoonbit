///|
fnalias @lexer.lex

///|
typealias @parser.Function

///|
fn testcode1() -> Unit {
  let code =
    #| extern fn print_int(x : Int) -> Unit;
    #|
    #| fn fib(n : Int) -> Int {
    #|   if n <= 1 {
    #|     return n;
    #|   }
    #|   return fib(n - 1) + fib(n - 2);
    #| }
    #|
    #| fn main {
    #|   print_int(fib(10));
    #| }
  let prog = @parser.Program::parse(lex(code))
  let _ = @parser.TypeCheck::check_prog(prog)
  let codegen = @codegen.CodeGen::init(prog)
  match (try? codegen.emitProg()) {
    Ok(_) => ()
    Err(e) => println("Error during code generation: \{e}")
  }
  codegen.dump()
}

///|
fn testcode2() -> Unit {
  let code =
    #|extern fn print_int(x: Int) -> Unit;
    #|
    #|fn caltz(n: Int, cnt: Int) -> Int {
    #|  if n == 1 {
    #|    return cnt;
    #|  }
    #|  if n % 2 == 0 {
    #|    return caltz(n / 2, cnt + 1);
    #|  }
    #|  return caltz(3*n + 1, cnt + 1);
    #|}
    #|
    #|fn main {
    #|  let n : Int = caltz(23, 0);
    #|  print_int(n);
    #|}
  let prog = @parser.Program::parse(lex(code))
  let _ = @parser.TypeCheck::check_prog(prog)
  let codegen = @codegen.CodeGen::init(prog)
  match (try? codegen.emitProg()) {
    Ok(_) => ()
    Err(e) => println("Error during code generation: \{e}")
  }
  codegen.dump()
}

///|
fn testcode3() -> Unit {
  let code =
    #|extern fn malloc(size: Int) -> Ptr[Unit];
    #|extern fn print_int(x: Int) -> Unit;
    #|extern fn print_endline() -> Unit;
    #|
    #|fn vec_muladd(a: Ptr[Int], b: Ptr[Int], c: Ptr[Int], len: Int) -> Ptr[Int] {
    #|  let i: Int = 0;
    #|  let dst : Ptr[Int] = malloc(sizeof(Int) * len) as Ptr[Int];
    #|  while i < len {
    #|    dst[i] = a[i] * b[i] + c[i];
    #|  }
    #|  return dst;
    #|}
    #|
    #|fn main {
    #|  let a : Array[Int] = [1, 2, 3, 4, 5];
    #|  let b: Array[Int] = [6, 7, 8, 9, 10];
    #|  let c: Array[Int] = [10, 11, 12, 13, 14];
    #|
    #|  let d : Ptr[Int] = vec_muladd(a as Ptr[Int], b as Ptr[Int], c as Ptr[Int], 5);
    #|  let i : Int = 0;
    #|  while i < 5 {
    #|    print_int(d[i]);
    #|    print_endline();
    #|  }
    #|}
  let prog = @parser.Program::parse(lex(code))
  let _ = @parser.TypeCheck::check_prog(prog)
  let codegen = @codegen.CodeGen::init(prog)
  match (try? codegen.emitProg()) {
    Ok(_) => ()
    Err(e) => println("Error during code generation: \{e}")
  }
  codegen.dump()
}

///|
fn main {
  testcode3()
}

///|
test {
  ignore(testcode1)
  ignore(testcode2)
  ignore(testcode3)
}
