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

test "tokenize number" {
  let code = 
    #|42 58
    #|1U 5u
    #|1L 9l
    #|3UL 7ul
    #|144Ul 57uL
    #|0x1A 0x2B
    #|0b1010 0b1100L
    #|3.14 5.225
    #|7.18f 9.81F

  let ctx = Context::new(code)
  ctx..tokenize()

  let tokens = ctx.tokens
  assert_eq(tokens.length(), 19)
  assert_eq(tokens[0], Token::new(Int(42), 1, 1))
  assert_eq(tokens[1], Token::new(Int(58), 1, 4))
  assert_eq(tokens[2], Token::new(UInt(1), 2, 1))
  assert_eq(tokens[3], Token::new(UInt(5), 2, 4))
  assert_eq(tokens[4], Token::new(Int64(1), 3, 1))
  assert_eq(tokens[5], Token::new(Int64(9), 3, 4))
  assert_eq(tokens[6], Token::new(UInt64(3), 4, 1))
  assert_eq(tokens[7], Token::new(UInt64(7), 4, 4))
  assert_eq(tokens[8], Token::new(UInt64(144), 5, 1))
  assert_eq(tokens[9], Token::new(UInt64(57), 5, 7))
  assert_eq(tokens[10], Token::new(Int(26), 6, 1))
  assert_eq(tokens[11], Token::new(Int(43), 6, 7))
  assert_eq(tokens[12], Token::new(Int(10), 7, 1))
  assert_eq(tokens[13], Token::new(Int64(12), 7, 8))
  assert_eq(tokens[14], Token::new(Float(3.14), 8, 1))
  assert_eq(tokens[15], Token::new(Float(5.225), 8, 6))
  assert_eq(tokens[16], Token::new(Float(7.18), 9, 1))
  assert_eq(tokens[17], Token::new(Float(9.81), 9, 6))
  assert_eq(tokens[18], Token::new(EOF, 9, 9))

}
