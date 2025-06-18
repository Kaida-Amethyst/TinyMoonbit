
fnalias @lexer.lex
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
    ;

  let func = Function::parse(lex(code))
  println(func)
}
