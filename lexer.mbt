///|
pub suberror TokenizeError String derive(Show)

///|
pub(all) enum Keyword {
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
pub(all) enum BinaryOp {
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
} derive(Show, Eq)

fn BinaryOp::precedence(self : Self) -> Int {
  match self {
    Or => 1
    And => 2
    BitOr => 3
    BitAnd => 4
    Eq | NE => 5
    LT | GT | LE | GE => 6
    ShiftLeft | ShiftRight => 7
    Plus | Minus => 8
    Mult | Div | Mod => 9
  }
}

///|
pub(all) enum AssignOp {
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
pub(all) enum TokenKind {
  Bool(Bool) // true, false
  Int(Int) // 1, 42, -100
  Int64(Int64) // 1L, 42L, -100L
  UInt(UInt) // 1U, 42U, 100U
  UInt64(UInt64) // 1UL, 42UL, 100UL
  Float(Float) // 1.0F, 3.14F
  Double(Double)
  String(String) // "hello", "world"
  Keyword(Keyword)
  Upper(String)
  Lower(String)
  BinaryOp(BinaryOp) // +, -, *, /, %, =, ==, !=, <, >, <=, >=, &&, ||
  AssignOp(AssignOp) // =, +=, -=, *=, /=, %=
  Not // !
  Bracket(Char) // (, ), [, ], {, }
  Dot // .
  Comma
  Colon
  DoubleColon // ::
  SemiColon // ;
  RightArrow // ->
  FatRightArrow // =>
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
      let tok = Token::new(RightArrow, line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "=>", .. rest] => {
      let tok = Token::new(FatRightArrow, line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "!=", .. rest] => {
      let tok = Token::new(BinaryOp(NE), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "==", .. rest] => {
      let tok = Token::new(BinaryOp(Eq), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "<=", .. rest] => {
      let tok = Token::new(BinaryOp(LE), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. ">=", .. rest] => {
      let tok = Token::new(BinaryOp(GE), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "&&", .. rest] => {
      let tok = Token::new(BinaryOp(And), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "||", .. rest] => {
      let tok = Token::new(BinaryOp(Or), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. "<<", .. rest] => {
      let tok = Token::new(BinaryOp(ShiftLeft), line, column)
      tokens.push(tok)
      column += 2
      continue rest
    }
    [.. ">>", .. rest] => {
      let tok = Token::new(BinaryOp(ShiftRight), line, column)
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
      let tok = Token::new(BinaryOp(Plus), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['-', .. rest] => {
      let tok = Token::new(BinaryOp(Minus), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['*', .. rest] => {
      let tok = Token::new(BinaryOp(Mult), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['/', .. rest] => {
      let tok = Token::new(BinaryOp(Div), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['%', .. rest] => {
      let tok = Token::new(BinaryOp(Mod), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['&', .. rest] => {
      let tok = Token::new(BinaryOp(BitAnd), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['|', .. rest] => {
      let tok = Token::new(BinaryOp(BitOr), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['<', .. rest] => {
      let tok = Token::new(BinaryOp(LT), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['>', .. rest] => {
      let tok = Token::new(BinaryOp(GT), line, column)
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
      let tok = Token::new(Not, line, column)
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
    ['\"', ..] as code => {
      let (tok, rest, len) = tokenize_string(code, line, column)
      column += len
      tokens.push(tok)
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
/// Need support:
///
/// 1. normal integer: 42 1577
/// 2. hex integer: 0x1A 0xFF
/// 3. binary integer: 0b1010 0b1101
/// 4. integer with suffix: 42L, 100u (allowed: u, U, l, L, ul, uL, Ul, UL)
/// 5. float: 3.14, 2.71f (allowed suffix: f, F)
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

// return token, remaining code, length of the string token (including quotes)
fn tokenize_string(code: StringView, line: Int, column: Int) -> (Token, StringView, Int) raise TokenizeError {
  guard code is ['\"', ..code] else {
    println("Compiler ICE: Tokenize String Error at line \{line}, column \{column}, missing opening quote")
    panic()
  }
  let sb = StringBuilder::new()
  let mut len = 1 // for the opening quote
  let rest = loop code {
    ['\"', .. rest] => {
      len += 1 // for the closing quote
      break rest
    }
    ['\\', .. rest] => {
      guard rest is [c, .. rest] else {
        raise TokenizeError("Tokenize Error: Invalid escape sequence at line \{line}, column \{column + len}")
      }
      let escaped_char = match c {
        'n' => '\n'
        't' => '\t'
        'r' => '\r'
        '\\' => '\\'
        '\"' => '\"'
        '\'' => '\''
        other =>
          raise TokenizeError("Tokenize Error: Unknown escape character '\{other}' at line \{line}, column \{column + len}")
      }
      sb.write_char(escaped_char)
      len += 2 // for the backslash and the escaped character
      continue rest
    }
    [c, .. rest] => {
      sb.write_char(c)
      len += 1
      continue rest
    }
    [] =>
      raise TokenizeError("Tokenize Error: Unterminated string literal at line \{line}, column \{column}")
  }
  let str_val = sb.to_string()
  (Token::new(String(str_val), line, column), rest, len)
}

