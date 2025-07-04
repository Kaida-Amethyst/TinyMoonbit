///|
fnalias @lexer.lex

///|
typealias @parser.Function

fn testcode1 () -> Unit {
  let code =
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
fn main {
  testcode1()
}

test {
  ignore(testcode1)
}

