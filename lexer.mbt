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
  Add // +
  Sub // -
  Mul // *
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
} derive(Eq)

pub impl Show for BinaryOp with output(self, logger) {
  let s = match self {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div => "/"
    Mod => "%"
    ShiftLeft => "<<"
    ShiftRight => ">>"
    Eq => "=="
    NE => "!="
    LT => "<"
    GT => ">"
    LE => "<="
    GE => ">="
    And => "&&"
    Or => "||"
    BitAnd => "&"
    BitOr => "|"
  }
  logger.write_string(s)
}

///|
fn BinaryOp::precedence(self : Self) -> Int {
  match self {
    Or => 1
    And => 2
    BitOr => 3
    BitAnd => 4
    Eq | NE => 5
    LT | GT | LE | GE => 6
    ShiftLeft | ShiftRight => 7
    Add | Sub => 8
    Mul | Div | Mod => 9
  }
}

///|
fn BinaryOp::is_cmp(self : Self) -> Bool {
  match self {
    Eq | NE | LT | GT | LE | GE => true
    _ => false
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
  Wildcard // _
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
      let tok = Token::new(BinaryOp(Add), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['-', .. rest] => {
      let tok = Token::new(BinaryOp(Sub), line, column)
      tokens.push(tok)
      column += 1
      continue rest
    }
    ['*', .. rest] => {
      let tok = Token::new(BinaryOp(Mul), line, column)
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
    ['_', .. rest] => {
      let tok = Token::new(Wildcard, line, column)
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
/// Handle Int64, UInt, UInt64, Float, Double
/// Support:
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
  let mut is_hex = false
  let mut is_binary = false
  let mut is_float = false

  // Check for hex or binary prefix
  let rest = match code {
    [.. "0x", .. rest] | [.. "0X", .. rest] => {
      is_hex = true
      len += 2
      rest
    }
    [.. "0b", .. rest] | [.. "0B", .. rest] => {
      is_binary = true
      len += 2
      rest
    }
    _ => code
  }

  // Parse the numeric part
  let rest = if is_hex {
    // Parse hexadecimal
    loop rest {
      ['0'..='9' | 'a'..='f' | 'A'..='F' as c, .. rest] => {
        sb.write_char(c)
        len += 1
        continue rest
      }
      rest => break rest
    }
  } else if is_binary {
    // Parse binary
    loop rest {
      ['0' | '1' as c, .. rest] => {
        sb.write_char(c)
        len += 1
        continue rest
      }
      rest => break rest
    }
  } else {
    // Parse decimal (including potential float)
    let rest = loop rest {
      ['0'..='9' as c, .. rest] => {
        sb.write_char(c)
        len += 1
        continue rest
      }
      rest => break rest
    }
    // Check for decimal point (float)
    match rest {
      ['.', '0'..='9', ..] as dot_rest => {
        is_float = true
        sb.write_char('.')
        len += 1
        let rest_after_dot = match dot_rest {
          ['.', .. rest] => rest
          _ => panic()
        }
        // Parse fractional part
        loop rest_after_dot {
          ['0'..='9' as c, .. rest] => {
            sb.write_char(c)
            len += 1
            continue rest
          }
          rest => break rest
        }
      }
      _ => rest
    }
  }
  let num_str = sb.to_string()

  // Check for suffix
  let (kind, rest, _suffix_len) = match rest {
    ['U' | 'u', 'L' | 'l', .. rest] => {
      // UL suffix - UInt64
      len += 2
      let value = try {
        if is_hex {
          @strconv.parse_uint64(num_str, base=16)
        } else if is_binary {
          @strconv.parse_uint64(num_str, base=2)
        } else {
          @strconv.parse_uint64(num_str)
        }
      } catch {
        _ => raise TokenizeError("Invalid UInt64 literal: \{num_str}")
      }
      (TokenKind::UInt64(value), rest, 2)
    }
    ['L' | 'l', .. rest] => {
      // L suffix - Int64
      len += 1
      let value = try {
        if is_hex {
          @strconv.parse_int64(num_str, base=16)
        } else if is_binary {
          @strconv.parse_int64(num_str, base=2)
        } else {
          @strconv.parse_int64(num_str)
        }
      } catch {
        _ => raise TokenizeError("Invalid Int64 literal: \{num_str}")
      }
      (TokenKind::Int64(value), rest, 1)
    }
    ['U' | 'u', .. rest] => {
      // U suffix - UInt
      len += 1
      let value = try {
        if is_hex {
          @strconv.parse_uint(num_str, base=16)
        } else if is_binary {
          @strconv.parse_uint(num_str, base=2)
        } else {
          @strconv.parse_uint(num_str)
        }
      } catch {
        _ => raise TokenizeError("Invalid UInt literal: \{num_str}")
      }
      (TokenKind::UInt(value), rest, 1)
    }
    ['F' | 'f', .. rest] if is_float || not(is_hex || is_binary) => {
      // F suffix - Float (only for decimal numbers)
      len += 1
      // If not already a float, treat the integer as a float
      let float_str = if is_float { num_str } else { num_str + ".0" }
      let value = @strconv.parse_double(float_str) catch {
        _ => raise TokenizeError("Invalid Float literal: \{float_str}")
      }
      (TokenKind::Float(value.to_float()), rest, 1)
    }
    _ =>
      // No suffix
      if is_float {
        // It's a double/float without suffix, treat as Float for compatibility
        let value = @strconv.parse_double(num_str) catch {
          _ => raise TokenizeError("Invalid Float literal: \{num_str}")
        }
        (TokenKind::Double(value), rest, 0)
      } else {
        // Regular integer
        let value = try {
          if is_hex {
            @strconv.parse_int(num_str, base=16)
          } else if is_binary {
            @strconv.parse_int(num_str, base=2)
          } else {
            @strconv.parse_int(num_str)
          }
        } catch {
          _ => raise TokenizeError("Invalid Int literal: \{num_str}")
        }
        (TokenKind::Int(value), rest, 0)
      }
  }
  (Token::new(kind, line, column), rest, len)
}

// return token, remaining code, length of the string token (including quotes)

///|
fn tokenize_string(
  code : StringView,
  line : Int,
  column : Int,
) -> (Token, StringView, Int) raise TokenizeError {
  guard code is ['\"', .. code] else {
    println(
      "Compiler ICE: Tokenize String Error at line \{line}, column \{column}, missing opening quote",
    )
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
        raise TokenizeError(
          "Tokenize Error: Invalid escape sequence at line \{line}, column \{column + len}",
        )
      }
      let escaped_char = match c {
        'n' => '\n'
        't' => '\t'
        'r' => '\r'
        '\\' => '\\'
        '\"' => '\"'
        '\'' => '\''
        other =>
          raise TokenizeError(
            "Tokenize Error: Unknown escape character '\{other}' at line \{line}, column \{column + len}",
          )
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
      raise TokenizeError(
        "Tokenize Error: Unterminated string literal at line \{line}, column \{column}",
      )
  }
  let str_val = sb.to_string()
  (Token::new(String(str_val), line, column), rest, len)
}
