
fnalias @lexer.lex
fnalias @parser.parse_if_statement

///|
fn main {
  //let code =
  //  #|fn add(x: Int, y: Int) -> Int {
  //  #|  let res : Int = x + y;
  //  #|  return res;
  //  #|}

  //let codes_let = [
  //  "let x : Int = 1;",
  //  "let y : UInt = 3U;",
  //  "let z : Float = 3.14;",
  //  "let a : Bool = true;",
  //  "let x : Ref[Int] = Ref(x);",
  //  "let x : Array[Int] = [];",
  //  "let x : Point = Point(1, 2);",
  //]
  //
  //for code in codes_let {
  //  let toks = @TinyMoonbit.lex(code)
  //  let (ast, _) = @TinyMoonbit.parse_let_statement(toks)
  //  println(ast)
  //}

  let code_if = [
    "if x > 0 { return x; } else { return 0 - x; }",
    "if a < b { return true; } else { return false; }",
    "if a >= 2 { x.val = 1; } else if a <= 1 { x.val = 2; } else { x.val = 3; }",
  ]
  for code in code_if {
    let toks = lex(code)
    let (ast, _) = parse_if_statement(toks)
    println(ast)
  }
}
