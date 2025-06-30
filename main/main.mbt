///|
fnalias @lexer.lex

///|
typealias @parser.Function

///|
fn main {
  let code =
    #| fn fib(n : Int) -> Int {
    #|   if n <= 1 {
    #|     return n;
    #|   }
    #|   return fib(n - 1) + fib(n - 2);
    #| }
  let prog = @parser.Program::parse(lex(code))
  let _ = @parser.TypeCheck::check_prog(prog)

  let codegen = @codegen.CodeGen::init(prog)
  match (try? codegen.run()) {
    Ok(_) => println("Code generation successful!")
    Err(e) => println("Error during code generation: \{e}")
  }
  codegen.dump()
}
