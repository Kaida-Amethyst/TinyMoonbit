///|
fn main {
  let code =
    #|fn add(x: Int, y: Int) -> Int {
    #|  return x + y - 342UL
    #|}
  let toks = @TinyMoonbit.lex(code)
  println(toks)
}
