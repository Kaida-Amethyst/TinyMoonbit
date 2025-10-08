///|
pub suberror ParseError (Token, String) derive(Show)

///|
pub struct Context {
  code : String
  tokens : Array[Token]
  fatal_errors : Array[ParseError] // stop type check
  normal_errors : Array[ParseError] // stop codegen
}

///|
pub fn Context::new(code : String) -> Context {
  Context::{
    code,
    tokens: Array::new(),
    fatal_errors: Array::new(),
    normal_errors: Array::new(),
  }
}
