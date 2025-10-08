///|
test "tokenize keywords" {
  let code =
    #|fn let mut
    #|if else
    #|match while for return
  let ctx = Context::new(code)
  ctx..tokenize()
  let tokens = ctx.tokens
  assert_eq(tokens.length(), 10)
  assert_eq(tokens[0], Token::new(Keyword(Fn), 1, 1))
  assert_eq(tokens[1], Token::new(Keyword(Let), 1, 4))
  assert_eq(tokens[2], Token::new(Keyword(Mut), 1, 8))
  assert_eq(tokens[3], Token::new(Keyword(If), 2, 1))
  assert_eq(tokens[4], Token::new(Keyword(Else), 2, 4))
  assert_eq(tokens[5], Token::new(Keyword(Match), 3, 1))
  assert_eq(tokens[6], Token::new(Keyword(While), 3, 7))
  assert_eq(tokens[7], Token::new(Keyword(For), 3, 13))
  assert_eq(tokens[8], Token::new(Keyword(Return), 3, 17))
  assert_eq(tokens[9], Token::new(EOF, 3, 23))
}

///|
test "tokenize string" {
  let code = 
    #|"hello, world!"
    #|"line1\nline2"

  let ctx = Context::new(code)
  ctx..tokenize()
  let tokens = ctx.tokens
  assert_eq(tokens.length(), 3)
  assert_eq(tokens[0], Token::new(String("hello, world!"), 1, 1))
  assert_eq(tokens[1], Token::new(String("line1\nline2"), 2, 1))
}

