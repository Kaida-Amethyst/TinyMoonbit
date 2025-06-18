typealias @lexer.Token
fnalias @lexer.lex

///|
pub(all) enum TypeName {
  Unit
  Bool
  Int
  Int64
  UInt
  UInt64
  Float
  Double
  Array(TypeName) // e.g. Array[Int]
  Struct(String) // e.g. Struct Point
} derive(Show, Eq)

///|
pub fn TypeName::from(master : String, sub_type~ : String? = None) -> TypeName {
  match (master, sub_type) {
    ("Unit", None) => Unit
    ("Bool", None) => Bool
    ("Int", None) =>  Int
    ("Int64", None) =>Int64
    ("UInt", None) => UInt
    ("UInt64", None) => UInt64
    ("Float", None) =>  Float
    ("Double", None) => Double
    ("Array", Some(sub)) => Array(TypeName::from(sub))
    (struct_name, None) =>  Struct(struct_name)
    _ => {
      println("Unknown type name: \{master} with sub-type: \{sub_type}")
      panic()
    }
  }
}

///|
pub(all) enum Atomic {
  Bool(Bool)
  Int(Int)
  Int64(Int64)
  UInt(UInt)
  UInt64(UInt64)
  Float(Float)
  Double(Double)
  Var(String)
  Array(Array[Expr]) // e.g. [1, 2, 3]
  Paren(Expr) // e.g. (1 + 2)
} derive(Show, Eq)

///|
pub(all) enum ApplyExpr {
  Atomic(Atomic)
  ArrayGet(String, Expr) // e.g. arr[i]
  StructAccess(String, String) // e.g. struct.field
  Call(String, Array[Expr]) // e.g. func(arg1, arg2)
  Construct(String, Array[(String, Expr)]) // e.g. Point::{x: 1, y: 2}
} derive(Show, Eq)

///|
pub(all) enum Expr {
  Apply(ApplyExpr) // e.g. func(arg1, arg2)
  Add(Expr, Expr)
  Sub(Expr, Expr)
  Mul(Expr, Expr)
  Div(Expr, Expr)
  Rem(Expr, Expr)
  Eq(Expr, Expr)
  Ne(Expr, Expr)
  Le(Expr, Expr)
  Ge(Expr, Expr)
  Lt(Expr, Expr)
  Gt(Expr, Expr)
  And(Expr, Expr)
  Or(Expr, Expr)
  Shl(Expr, Expr) // e.g. 1 << 2
  Shr(Expr, Expr) // e.g. 1 >> 2
} derive(Show, Eq)

///|
pub(all) enum Stmt {
  Let(String, TypeName, Expr) // e.g. let x: Int = 10;
  Assign(String, String?, Expr) // e.g. x = 10; x.val = 20;
  ArrayPut(String, Expr, Expr) // e.g. arr[i] = 10;
  If(Expr, Array[Stmt], Array[Stmt]) // condition, then, else
  While(Expr, Array[Stmt]) // condition, body
  Return(Expr?) // optional return value
} derive(Show, Eq)

///|
pub(all) struct Function {
  name : String
  params : Array[(String, TypeName)]
  return_type : TypeName
  body : Array[Stmt]
} derive(Show, Eq)

///|
pub(all) struct StructDef {
  name : String
  fields : Array[(String, TypeName)]
} derive(Show, Eq)

///|
pub struct Program {
  functions : Array[Function]
  structs : Array[StructDef]
} derive(Show, Eq)

///|
pub fn parse_program(tokens : Array[Token]) -> Program {
  let functions = Array::new()
  let structs = Array::new()
  loop tokens[:] {
    [EOF] => break
    [Keyword(Fn), ..] as toks => {
      let (f, rest_toks) = parse_function(toks)
      functions.push(f)
      continue rest_toks
    }
    [Keyword(Struct), ..] as toks => {
      let (s, rest_toks) = parse_struct(toks)
      structs.push(s) // TODO: handle structs
      continue rest_toks
    }
    _ => {
      println("Parse Program Error: Unexpected token in program: \{tokens}")
      panic()
    }
  }
  Program::{ functions, structs }
}

///|
pub fn parse_function(
  tokens : ArrayView[Token]
) -> (Function, ArrayView[Token]) {
  guard tokens is [Keyword(Fn), Lower(fname), Bracket('('), .. tokens] else {
    println("Parse Function Error, Not a function definition")
    panic()
  }
  let params : Array[(String, TypeName)] = Array::new()
  let tokens = loop tokens {
    [
      Lower(param_name),
      Symbol(":"),
      Upper("Array"),
      Bracket('['),
      Upper(sub_type),
      Bracket(']'),
      .. rest_toks,
    ] => {
      let type_name = TypeName::from("Array", sub_type=Some(sub_type))
      params.push((param_name, type_name))
      continue rest_toks
    }
    [Lower(param_name), Symbol(":"), Upper(type_name), .. rest_toks] => {
      let type_name = TypeName::from(type_name)
      params.push((param_name, type_name))
      continue rest_toks
    }
    [Symbol(","), .. rest_toks] => continue rest_toks
    [Bracket(')'), LeftArrow, .. rest_toks] => break rest_toks
    _ as tokens => {
      println("Parse Function Error: Unexpected token in parameters: \{tokens}")
      panic()
    }
  }

  // parse return type
  let (return_type, tokens) = match tokens {
    [
      Upper("Array"),
      Bracket('['),
      Upper(sub_type),
      Bracket(']'),
      Bracket('{'),
      .. rest_toks,
    ] => {
      let return_type = TypeName::from("Array", sub_type=Some(sub_type))
      (return_type, rest_toks)
    }
    [Upper(return_type), Bracket('{'), .. rest_toks] => {
      let return_type = TypeName::from(return_type)
      (return_type, rest_toks)
    }
    _ => {
      println("Parse Function Error, during parsing return type")
      panic()
    }
  }
  let body : Array[Stmt] = Array::new()
  let tokens = loop tokens {
    [Bracket('}'), .. rest_toks] => break rest_toks
    _ as tokens => {
      let (stmt, rest_toks) = parse_statement(tokens)
      body.push(stmt)
      continue rest_toks
    }
  }
  let function = Function::{ name: fname, params, return_type, body }
  (function, tokens)
}

///|
pub fn parse_struct(tokens : ArrayView[Token]) -> (StructDef, ArrayView[Token]) {
  guard tokens is [Keyword(Struct), Lower(name), Bracket('{'), .. tokens] else {
    println("Parse Struct Error, Not a struct definition")
    panic()
  }
  let fields : Array[(String, TypeName)] = Array::new()
  let tokens = loop tokens {
    [
      Lower(field_name),
      Symbol(":"),
      Upper("Array"),
      Bracket('['),
      Upper(sub_type),
      Bracket(']'),
      Symbol(","),
      .. rest_toks,
    ] => {
      let type_name = TypeName::from("Array", sub_type=Some(sub_type))
      fields.push((field_name, type_name))
      continue rest_toks
    }
    [
      Lower(field_name),
      Symbol(":"),
      Upper(type_name),
      Symbol(","),
      .. rest_toks,
    ] => {
      let type_name = TypeName::from(type_name)
      fields.push((field_name, type_name))
      continue rest_toks
    }
    [Bracket('}'), .. rest_toks] => break rest_toks
    _ as tokens => {
      println(
        "Parse Struct Error: Unexpected token in struct fields: \{tokens}",
      )
      panic()
    }
  }
  let struct_def = StructDef::{ name, fields }
  (struct_def, tokens)
}

///|
pub fn parse_statement(tokens : ArrayView[Token]) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Keyword(Let), ..] => parse_let_statement(tokens)
    [Keyword(If), ..] => parse_if_statement(tokens)
    [Keyword(While), ..] => parse_while_statement(tokens)
    [Keyword(Return), ..] => parse_return_statement(tokens)
    [Lower(_), Symbol("."), Lower(_), Operator("="), ..] =>
      parse_assign_statement(tokens)
    [Lower(_), Operator("="), ..] => parse_assign_statement(tokens)
    _ => {
      println("Parse Statement Error: Unexpected token in statement: \{tokens}")
      panic()
    }
  }
}

///|
pub fn parse_let_statement(
  tokens : ArrayView[Token]
) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [
      Keyword(Let),
      Lower(var_name),
      Symbol(":"),
      Upper("Array"),
      Bracket('['),
      Upper(sub_type),
      Bracket(']'),
      Operator("="),
      .. rest_toks,
    ] => {
      let type_name = TypeName::from("Array", sub_type=Some(sub_type))
      let (expr, rest_toks) = parse_expression(rest_toks)
      let stmt = Stmt::Let(var_name, type_name, expr)
      guard rest_toks is [Terminator, .. rest_toks] else {
        println("Parse Let Statement Error: Expected ';' after let statement")
        panic()
      }
      (stmt, rest_toks)
    }
    [
      Keyword(Let),
      Lower(var_name),
      Symbol(":"),
      Upper(type_name),
      Operator("="),
      .. rest_toks,
    ] => {
      let type_name = TypeName::from(type_name)
      let (expr, rest_toks) = parse_expression(rest_toks)
      let stmt = Stmt::Let(var_name, type_name, expr)
      guard rest_toks is [Terminator, .. rest_toks] else {
        println("Parse Let Statement Error: Expected ';' after let statement")
        panic()
      }
      (stmt, rest_toks)
    }
    _ => {
      println(
        "Parse Let Statement Error: Unexpected token in let statement: \{tokens}",
      )
      panic()
    }
  }
}

///|
pub fn parse_assign_statement(
  tokens : ArrayView[Token]
) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Lower(var_name), Operator("="), .. rest_toks] => {
      let (expr, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Terminator, .. rest_toks] else {
        println("Parse Assign Statement Error: Expected ';' after assignment")
        panic()
      }
      let stmt = Stmt::Assign(var_name, None, expr)
      (stmt, rest_toks)
    }
    [Lower(var_name), Symbol("."), Lower(field_name), Operator("="), .. rest_toks] => {
      let (expr, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Terminator, .. rest_toks] else {
        println(
          "Parse Assign Statement Error: Expected ';' after struct field assignment",
        )
        panic()
      }
      let stmt = Stmt::Assign(var_name, Some(field_name), expr)
      (stmt, rest_toks)
    }
    [Lower(var_name), Bracket('['), .. rest_toks] => {
      let (index_expr, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Bracket(']'), Operator("="), .. rest_toks] else {
        println("Parse Assign Statement Error: Expected ']' and '=' after array index")
        panic()
      }
      let (expr, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Terminator, .. rest_toks] else {
        println("Parse Assign Statement Error: Expected ';' after array assignment")
        panic()
      }
      let stmt = Stmt::ArrayPut(var_name, index_expr, expr)
      (stmt, rest_toks)
    }
    _ => {
      println(
        "Parse Assign Statement Error: Unexpected token in assignment: \{tokens}",
      )
      panic()
    }
  }
}

///|
pub fn parse_if_statement(
  tokens : ArrayView[Token]
) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Keyword(If), .. rest_toks] => {
      let (condition, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Bracket('{'), .. rest_toks] else {
        println("Parse If Statement Error: Expected '}' after condition")
        panic()
      }
      let then_body : Array[Stmt] = Array::new()
      let rest_toks = loop rest_toks {
        [Bracket('}'), .. rest_toks] => break rest_toks
        _ as rest_toks => {
          let (stmt, rest_toks) = parse_statement(rest_toks)
          then_body.push(stmt)
          continue rest_toks
        }
      }
      let else_body : Array[Stmt] = Array::new()
      let rest_toks = if rest_toks
        is [Keyword(Else), Bracket('{'), .. rest_toks] {
        loop rest_toks {
          [Bracket('}'), .. rest_toks] => break rest_toks
          _ as rest_toks => {
            let (stmt, rest_toks) = parse_statement(rest_toks)
            else_body.push(stmt)
            continue rest_toks
          }
        }
      } else {
        rest_toks
      }
      let stmt = Stmt::If(condition, then_body, else_body)
      (stmt, rest_toks)
    }
    _ => {
      println(
        "Parse If Statement Error: Unexpected token in if statement: \{tokens}",
      )
      panic()
    }
  }
}

///|
pub fn parse_while_statement(
  tokens : ArrayView[Token]
) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Keyword(While), .. rest_toks] => {
      let (condition, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Bracket('{'), .. rest_toks] else {
        println("Parse While Statement Error: Expected '}' after condition")
        panic()
      }
      let body : Array[Stmt] = Array::new()
      let rest_toks = loop rest_toks {
        [Bracket('}'), .. rest_toks] => break rest_toks
        _ as rest_toks => {
          let (stmt, rest_toks) = parse_statement(rest_toks)
          body.push(stmt)
          continue rest_toks
        }
      }
      let stmt = Stmt::While(condition, body)
      (stmt, rest_toks)
    }
    _ => {
      println(
        "Parse While Statement Error: Unexpected token in while statement: \{tokens}",
      )
      panic()
    }
  }
}

///|
pub fn parse_return_statement(
  tokens : ArrayView[Token]
) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Keyword(Return), Terminator, .. rest_toks] => {
      let stmt = Stmt::Return(None)
      (stmt, rest_toks)
    }
    [Keyword(Return), .. rest_toks] => {
      let (expr, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Terminator, .. rest_toks] else {
        println(
          "Parse Return Statement Error: Expected ';' after return expression",
        )
        panic()
      }
      let stmt = Stmt::Return(Some(expr))
      (stmt, rest_toks)
    }
    _ => {
      println(
        "Parse Return Statement Error: Unexpected token in return statement: \{tokens}",
      )
      panic()
    }
  }
}

// precdence:
// +, -: 7
// *, /, %: 8
///|
pub fn parse_expression(tokens : ArrayView[Token]) -> (Expr, ArrayView[Token]) {
  fn construct_bin_expr(left : Expr, right : Expr, oper : String) -> Expr {
    match oper {
      "+" => Expr::Add(left, right)
      "-" => Expr::Sub(left, right)
      "*" => Expr::Mul(left, right)
      "/" => Expr::Div(left, right)
      "%" => Expr::Rem(left, right)
      "==" => Expr::Eq(left, right)
      "!=" => Expr::Ne(left, right)
      "<=" => Expr::Le(left, right)
      ">=" => Expr::Ge(left, right)
      "<" => Expr::Lt(left, right)
      ">" => Expr::Gt(left, right)
      "&&" => Expr::And(left, right)
      "||" => Expr::Or(left, right)
      "<<" => Expr::Shl(left, right) // left shift
      ">>" => Expr::Shr(left, right) // logical right shift
      _ => {
        println("Unknown operator: \{oper}")
        panic()
      }
    }
  }

  fn preced(op : String) -> Int {
    match op {
      "*" | "/" | "%" => 9
      "+" | "-" => 8
      "<<" | ">>" => 7 // left and logical right shift
      "==" | "!=" | "<=" | ">=" | "<" | ">" => 6
      "&&" => 3
      "||" => 2
      _ => {
        println("Unknown operator precedence for: \{op}")
        panic()
      }
    }
  }

  let exprs : Array[Expr] = Array::new()
  let opers : Array[String] = Array::new()
  let (head_apply, rest_toks) = parse_apply_expr(tokens)
  exprs.push(Expr::Apply(head_apply))
  loop rest_toks {
    [Operator(op), .. rest_toks] if opers.is_empty() => {
      let (next_apply, rest_toks) = parse_apply_expr(rest_toks)
      exprs.push(Expr::Apply(next_apply))
      opers.push(op)
      continue rest_toks
    }
    [Operator(op), .. rest_toks] if preced(op) >= preced(opers.last().unwrap()) => {
      let (next_apply, rest_toks) = parse_apply_expr(rest_toks)
      exprs.push(Expr::Apply(next_apply))
      opers.push(op)
      continue rest_toks
    }
    [Operator(op), .. rest_toks] => {
      let new_exprs = Array::new()
      let new_opers = Array::new()
      while opers.last() is Some(last_op) && preced(op) < preced(last_op) {
        new_exprs.push(exprs.pop().unwrap()) // right_expr
        new_opers.push(opers.pop().unwrap())
      } else {
        new_exprs.push(exprs.pop().unwrap()) // left_expr
      }
      while not(new_opers.is_empty()) {
        let left_expr = new_exprs.pop().unwrap()
        let right_expr = new_exprs.pop().unwrap()
        let oper = new_opers.pop().unwrap()
        let new_expr = construct_bin_expr(left_expr, right_expr, oper)
        new_exprs.push(new_expr)
      }
      guard new_exprs.length() == 1 else {
        println("Parse Expression Error: Mismatched expression and operators")
        panic()
      }
      exprs.push(new_exprs.pop().unwrap())
      let (next_apply, rest_toks) = parse_apply_expr(rest_toks)
      exprs.push(Expr::Apply(next_apply))
      opers.push(op)
      continue rest_toks
    }
    _ as rest_toks => {
      // clear opers and exprs
      while not(opers.is_empty()) {
        let right_expr = exprs.pop().unwrap()
        let left_expr = exprs.pop().unwrap()
        let oper = opers.pop().unwrap()
        let new_expr = construct_bin_expr(left_expr, right_expr, oper)
        exprs.push(new_expr)
      }
      guard exprs.length() == 1 else {
        println("Parse Expression Error: Mismatched expression and operators")
        panic()
      }
      (exprs[0], rest_toks)
    }
  }
}

///|
pub fn parse_apply_expr(
  tokens : ArrayView[Token]
) -> (ApplyExpr, ArrayView[Token]) {
  match tokens {
    [Lower(var_name), Bracket('['), .. rest_toks] => {
      let (index_expr, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Bracket(']'), .. rest_toks] else {
        println("Parse ApplyExpr Error: Expected ']' after array index")
        panic()
      }
      (ApplyExpr::ArrayGet(var_name, index_expr), rest_toks)
    }
    [Lower(var_name), Symbol("."), Lower(field_name), .. rest_toks] =>
      (ApplyExpr::StructAccess(var_name, field_name), rest_toks)
    [Lower(func_name), Bracket('('), .. rest_toks] => {
      let args : Array[Expr] = Array::new()
      let rest_toks = loop rest_toks {
        [Bracket(')'), .. rest_toks] => break rest_toks
        _ as rest_toks => {
          let (arg_expr, rest_toks) = parse_expression(rest_toks)
          args.push(arg_expr)
          if rest_toks is [Symbol(","), .. rest_toks] {
            continue rest_toks
          } else if rest_toks is [Bracket(')'), .. rest_toks] {
            break rest_toks
          } else {
            println(
              "Parse ApplyExpr Error: Unexpected token in function call arguments: \{rest_toks}",
            )
            panic()
          }
        }
      }
      (ApplyExpr::Call(func_name, args), rest_toks)
    }
    [Upper(struct_name), Symbol("::"), Bracket('{'), .. rest_toks] => {
      let fields : Array[(String, Expr)] = Array::new()
      let rest_toks = loop rest_toks {
        [Bracket('}'), .. rest_toks] => break rest_toks
        [Lower(field_name), Symbol(":"), .. rest_toks] => {
          let (field_expr, rest_toks) = parse_expression(rest_toks)
          fields.push((field_name, field_expr))
          continue rest_toks
        }
        [Symbol(","), .. rest_toks] => continue rest_toks
        _ as rest_toks => {
          println("Parse ApplyExpr Error: Unexpected token in struct constructor: \{rest_toks}")
          panic()
        }
      }
      (ApplyExpr::Construct(struct_name, fields), rest_toks)
    }
    _ => {
      let (atomic, rest_toks) = parse_atomic(tokens)
      (ApplyExpr::Atomic(atomic), rest_toks)
    }
  }
}

///|
pub fn parse_atomic(tokens : ArrayView[Token]) -> (Atomic, ArrayView[Token]) {
  match tokens {
    [Bool(value), .. rest_toks] => (Bool(value), rest_toks)
    [Int(value), .. rest_toks] => (Int(value), rest_toks)
    [Int64(value), .. rest_toks] => (Int64(value), rest_toks)
    [UInt(value), .. rest_toks] => (UInt(value), rest_toks)
    [UInt64(value), .. rest_toks] => (UInt64(value), rest_toks)
    [Float(value), .. rest_toks] => (Float(value), rest_toks)
    [Double(value), .. rest_toks] => (Double(value), rest_toks)
    [Lower(var_name), .. rest_toks] => (Var(var_name), rest_toks)
    [Bracket('['), .. rest_toks] => {
      let elements : Array[Expr] = Array::new()
      let rest_toks = loop rest_toks {
        [Bracket(']'), .. rest_toks] => break rest_toks
        _ as rest_toks => {
          let (expr, rest_toks) = parse_expression(rest_toks)
          elements.push(expr)
          if rest_toks is [Symbol(","), .. rest_toks] {
            continue rest_toks
          } else if rest_toks is [Bracket(']'), .. rest_toks] {
            break rest_toks
          } else {
            println(
              "Parse Atomic Error: Unexpected token in array literal: \{rest_toks}",
            )
            panic()
          }
        }
      }
      (Array(elements), rest_toks)
    }
    [Bracket('('), .. rest_toks] => {
      let (expr, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Bracket(')'), .. rest_toks] else {
        println("Parse Atomic Error: Expected ')' after parenthesis")
        panic()
      }
      (Paren(expr), rest_toks)
    }
    _ => {
      println(
        "Parse Atomic Error: Unexpected token in atomic expression: \{tokens}",
      )
      panic()
    }
  }
}

test "Parser" {
  let code = "1 + 3"
  inspect(
    parse_expression(lex(code)).0,
    content="Add(Apply(Atomic(Int(1))), Apply(Atomic(Int(3))))"
  )

  let code = "1 + 3 * 5"
  inspect(
    parse_expression(lex(code)).0,
    content="Add(Apply(Atomic(Int(1))), Mul(Apply(Atomic(Int(3))), Apply(Atomic(Int(5)))))"
  )

  let code = "1 + 2 - 3"
  inspect(
    parse_expression(lex(code)).0,
    content="Add(Apply(Atomic(Int(1))), Sub(Apply(Atomic(Int(2))), Apply(Atomic(Int(3)))))"
  )

  let code = "1 * 2 * 3 + 4"
  inspect(
    parse_expression(lex(code)).0,
    content="Add(Mul(Mul(Apply(Atomic(Int(1))), Apply(Atomic(Int(2)))), Apply(Atomic(Int(3)))), Apply(Atomic(Int(4))))"
  )

  let code = "let x : Int = 10;"
  inspect(
    parse_let_statement(lex(code)).0,
    content="Let(\"x\", Int, Apply(Atomic(Int(10))))"
  )
  
  let code = "let x : Array[Int] = [];"
  inspect(
    parse_let_statement(lex(code)).0,
    content = "Let(\"x\", Array(Int), Apply(Atomic(Array([]))))"
  )

  let code = "let x : Point = Point::{x : 1, x : 2};"
  inspect(
    parse_let_statement(lex(code)).0,
    content = "Let(\"x\", Struct(\"Point\"), Apply(Construct(\"Point\", [(\"x\", Apply(Atomic(Int(1)))), (\"x\", Apply(Atomic(Int(2))))])))"
  )

  let code = "if x > 0 { return x; } else { return 0 - x; }"
  inspect(
    parse_if_statement(lex(code)).0,
    content = "If(Gt(Apply(Atomic(Var(\"x\"))), Apply(Atomic(Int(0)))), [Return(Some(Apply(Atomic(Var(\"x\")))))], " +
               "[Return(Some(Sub(Apply(Atomic(Int(0))), Apply(Atomic(Var(\"x\"))))))])"
  )
  let code = "if a < b { return true; } else { return false; }"
  inspect(
    parse_if_statement(lex(code)).0,
    content = "If(Lt(Apply(Atomic(Var(\"a\"))), Apply(Atomic(Var(\"b\")))), [Return(Some(Apply(Atomic(Bool(true)))))], " +
               "[Return(Some(Apply(Atomic(Bool(false)))))])"
  )
  let code = "if a >= 2 { x.val = 1; } else if a <= 1 { x.val = 2; } else { x.val = 3; }"
  inspect(
    parse_if_statement(lex(code)).0,
    content = "If(Ge(Apply(Atomic(Var(\"a\"))), Apply(Atomic(Int(2)))), [Assign(\"x\", Some(\"val\"), Apply(Atomic(Int(1))))], [])"

  )
}
