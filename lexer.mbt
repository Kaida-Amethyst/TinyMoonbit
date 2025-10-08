///|
pub suberror TokenizeError String derive(Show)

///|
pub enum Keyword {
  Fn
  Struct
  Enum
  Let
  Mut
  If
  Else
  Match
  While
  For
  Return
  Extern
} derive(Show, Eq)

///|
pub enum Operator {
  Plus // +
  Minus // -
  Mult // *
  Div // /
  Mod // %
  ShiftLeft // <<
  ShiftRight // >>
  Eq // ==
  NE // !=
  LT // <
  GT // >
  LE // <=
  GE // >=
  And // &&
  Or // ||
  BitAnd // &
  BitOr // |
  Not // !
} derive(Show, Eq)

///|
pub enum AssignOp {
  Assign // =
  PlusAssign // +=
  MinusAssign // -=
  MultAssign // *=
  DivAssign // /=
  ModAssign // %=
} derive(Show, Eq, ToJson)

///|
pub struct Token {
  kind : TokenKind
  lineno : Int
  column : Int
} derive(Show, Eq)

///|
pub fn Token::new(kind : TokenKind, lineno : Int, column : Int) -> Token {
  Token::{ kind, lineno, column }
}

///|
pub enum TokenKind {
  Bool(Bool) // true, false
  Int(Int) // 1, 42, -100
  Int64(Int64) // 1L, 42L, -100L
  UInt(UInt) // 1U, 42U, 100U
  UInt64(UInt64) // 1UL, 42UL, 100UL
  //Float(Float) // 1.0F, 3.14F
  Double(Double)
  Keyword(Keyword)
  Upper(String)
  Lower(String)
  Operator(Operator) // +, -, *, /, %, =, ==, !=, <, >, <=, >=, &&, ||
  AssignOp(AssignOp) // =, +=, -=, *=, /=, %=
  Bracket(Char) // (, ), [, ], {, }
  Dot // .
  Comma
  Colon
  DoubleColon // ::
  SemiColon // ;
  LeftArrow // ->
  BoldLeftArrow // =>
  EOF
} derive(Show, Eq)

///|
pub fn Context::tokenize(self : Self) -> Unit raise TokenizeError {
  let { code, tokens, .. } = self
  tokens.clear()
  let mut line = 1
  let mut column = 1
  loop code[:] {
    [] => {
      let tok = Token::new(EOF, line, column)
      tokens.push(tok)
      break
    }
    [' ' | '\t' | '\r', .. rest] => {
      column += 1
      continue rest
    }
    ['\n', .. rest] => {
      line += 1
      column = 1
      continue rest
    }
    [.. "//", .. rest] =>
      continue loop rest {
          ['\n', .. rest_str] => {
            line += 1
            column = 1
            break rest_str
          }
          [_, .. rest_str] => continue rest_str
          [] as rest_str => break rest_str
        }
    [.. "::", .. rest] => {
      let tok = Token::new(DoubleColon, line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "->", .. rest] => {
      let tok = Token::new(LeftArrow, line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "=>", .. rest] => {
      let tok = Token::new(BoldLeftArrow, line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "!=", .. rest] => {
      let tok = Token::new(Operator(NE), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "==", .. rest] => {
      let tok = Token::new(Operator(Eq), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "<=", .. rest] => {
      let tok = Token::new(Operator(LE), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. ">=", .. rest] => {
      let tok = Token::new(Operator(GE), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "&&", .. rest] => {
      let tok = Token::new(Operator(And), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "||", .. rest] => {
      let tok = Token::new(Operator(Or), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "<<", .. rest] => {
      let tok = Token::new(Operator(ShiftLeft), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. ">>", .. rest] => {
      let tok = Token::new(Operator(ShiftRight), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "+=", .. rest] => {
      let tok = Token::new(AssignOp(PlusAssign), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "-=", .. rest] => {
      let tok = Token::new(AssignOp(MinusAssign), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "*=", .. rest] => {
      let tok = Token::new(AssignOp(MultAssign), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "/=", .. rest] => {
      let tok = Token::new(AssignOp(DivAssign), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "%=", .. rest] => {
      let tok = Token::new(AssignOp(ModAssign), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    ['+', .. rest] => {
      let tok = Token::new(Operator(Plus), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['-', .. rest] => {
      let tok = Token::new(Operator(Minus), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['*', .. rest] => {
      let tok = Token::new(Operator(Mult), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['/', .. rest] => {
      let tok = Token::new(Operator(Div), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['%', .. rest] => {
      let tok = Token::new(Operator(Mod), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['&', .. rest] => {
      let tok = Token::new(Operator(BitAnd), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['|', .. rest] => {
      let tok = Token::new(Operator(BitOr), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['<', .. rest] => {
      let tok = Token::new(Operator(LT), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['>', .. rest] => {
      let tok = Token::new(Operator(GT), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['=', .. rest] => {
      let tok = Token::new(AssignOp(Assign), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['!', .. rest] => {
      let tok = Token::new(Operator(Not), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['(', .. rest] => {
      let tok = Token::new(Bracket('('), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    [')', .. rest] => {
      let tok = Token::new(Bracket(')'), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['[', .. rest] => {
      let tok = Token::new(Bracket('['), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    [']', .. rest] => {
      let tok = Token::new(Bracket(']'), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['{', .. rest] => {
      let tok = Token::new(Bracket('{'), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['}', .. rest] => {
      let tok = Token::new(Bracket('}'), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['.', .. rest] => {
      let tok = Token::new(Dot, line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    [',', .. rest] => {
      let tok = Token::new(Comma, line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    [':', .. rest] => {
      let tok = Token::new(Colon, line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    [';', .. rest] => {
      let tok = Token::new(SemiColon, line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['A'..='Z', ..] as code => {
      let sb = StringBuilder::new()
      let rest = loop code {
        ['A'..='Z' | 'a'..='z' | '0'..='9' | '_' as c, .. rest] => {
          sb.write_char(c)
          column += 1
          continue rest
        }
        rest => break rest
      }
      let ident = sb.to_string()
      let tok = Token::new(Upper(ident), line, column)
      tokens.push(tok)
      continue rest
    }
    ['a'..='z', ..] as code => {
      let (ident, rest, len) = tokenize_lower_ident(code)
      let tok = Token::new(ident, line, column)
      column += len
      tokens.push(tok)
      continue rest
    }
    ['0'..='9', ..] as code => {
      let (tok, rest, len) = tokenize_number(code, line, column)
      column += len
      tokens.push(tok)
      continue rest
    }
    other_strs =>
      raise TokenizeError("Tokenize Error: Unexpected char: \{other_strs}")
  }
}

///|
fn tokenize_lower_ident(code : StringView) -> (TokenKind, StringView, Int) {
  let sb = StringBuilder::new()
  let mut len = 0
  let rest = loop code {
    ['a'..='z' | 'A'..='Z' | '0'..='9' | '_' as c, .. rest] => {
      sb.write_char(c)
      len += 1
      continue rest
    }
    rest => break rest
  }
  let ident = sb.to_string()
  let kind = match ident {
    "fn" => Keyword(Fn)
    "struct" => Keyword(Struct)
    "enum" => Keyword(Enum)
    "let" => Keyword(Let)
    "mut" => Keyword(Mut)
    "if" => Keyword(If)
    "else" => Keyword(Else)
    "match" => Keyword(Match)
    "while" => Keyword(While)
    "for" => Keyword(For)
    "return" => Keyword(Return)
    "true" => Bool(true)
    "false" => Bool(false)
    "extern" => Keyword(Extern)
    _ => Lower(ident)
  }
  (kind, rest, len)
}

///|
///
/// TODO: handle Int64, UInt, UInt64, Float, Double
fn tokenize_number(
  code : StringView,
  line : Int,
  column : Int,
) -> (Token, StringView, Int) raise TokenizeError {
  let sb = StringBuilder::new()
  let mut len = 0
  let rest = loop code {
    ['0'..='9' as c, .. rest] => {
      sb.write_char(c)
      len += 1
      continue rest
    }
    rest => break rest
  }
  let num_str = sb.to_string()
  let num = @strconv.parse_int(num_str) catch {
    _ =>
      raise TokenizeError(
        "Tokenize Error: Invalid integer literal: \{num_str} at line \{line}, column \{column}",
      )
  }
  (Token::new(Int(num), line, column), rest, len)
}

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
