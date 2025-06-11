///| TinyMoonbit
/// 
/// example:
///
/// fn add (x: Int, y: Int) -> Int {
///   return x + y;
/// }
///
/// fn modify(x: Ref[Int]) -> Int {
///   x.val = 10;
/// }
///
/// fn fibonacci(n: Int) -> Int {
///   if n <= 1 {
///     return n;
///   else {
///     return fibonacci(n - 1) + fibonacci(n - 2);
///   }
/// }
///
/// fn counter(x: Int) -> Unit {
///   while x > 0 {
///     println(x);
///     x = x - 1;
///   }
/// }
///
/// fn sum(arr: Array[Int]) -> Int {
///   let total : Int = 0;
///   let i : Int = 0;
///   while i < arr.length {
///     total = total + arr[i];
///     i = i + 1;
///   }
///   return total;
/// }


pub(all) type Var String

pub(all) enum TypeName {
  Unit
  Bool
  Int
  Int64
  UInt
  UInt64
  Float
  Double
  Ref(TypeName) // e.g. Ref[Int]
  Array(TypeName) // e.g. Array[Int]
  Struct(String) // e.g. Struct[MyStruct]
}

pub fn TypeName::from(master: String, sub_type~: String? = None) -> TypeName {
  match (master, sub_type) {
    ("Unit", None) => TypeName::Unit
    ("Bool", None) => TypeName::Bool
    ("Int", None) => TypeName::Int
    ("Int64", None) => TypeName::Int64
    ("UInt", None) => TypeName::UInt
    ("UInt64", None) => TypeName::UInt64
    ("Float", None) => TypeName::Float
    ("Double", None) => TypeName::Double
    ("Ref", Some(sub)) => TypeName::Ref(TypeName::from(sub))
    ("Array", Some(sub)) => TypeName::Array(TypeName::from(sub))
    (struct_name, None) => TypeName::Struct(struct_name)
    _ => {
      println("Unknown type name: \{master} with sub-type: \{sub_type}")
      panic()
    }
  }
}

pub(all) enum Atomic {
  Bool(Bool)
  Int(Int)
  Int64(Int64)
  UInt(UInt)
  UInt64(UInt64)
  Float(Float)
  Double(Double)
  Var(Var)
  Array(Array[Expr]) // e.g. [1, 2, 3]
}

pub(all) enum ApplyExpr{
  Atomic(Atomic)
  ArrayGet(Var, Expr) // e.g. arr[i]
  StructAccess(Var, Var) // e.g. struct.field
  Call(Var, Array[Expr]) // e.g. func(arg1, arg2)
}

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
  BitAnd(Expr, Expr) // e.g. 1 & 2
  BitOr(Expr, Expr) // e.g. 1 | 2
  Shl(Expr, Expr) // e.g. 1 << 2
  Shr(Expr, Expr) // e.g. 1 >> 2
}

pub(all) enum Stmt {
  Let(Var, TypeName, Expr) // e.g. let x: Int = 10;
  Assign(Var, Expr) // e.g. x = 10;
  If(Expr, Array[Stmt], Array[Stmt]) // condition, then, else
  While(Expr, Array[Stmt]) // condition, body
  Return(Expr?) // optional return value
}

pub(all) struct Function {
  name: Var
  params: Array[(Var, TypeName)]
  return_type: TypeName
  body: Array[Stmt]
}

pub(all) struct StructDef {
  name: Var
  fields: Array[(Var, TypeName)]
}

pub struct Program {
  functions: Array[Function]
  structs: Array[StructDef]
  // global_vars: Array[(Var, TypeName)] // global variables
}

pub fn parse_program(tokens: Array[Token]) -> Program {
  let functions = Array::new()
  let structs = Array::new()

  loop tokens[:] {
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
  Program::{
    functions: functions,
    structs: structs,
    // global_vars: Array::new() // TODO: handle global variables
  }
}

pub fn parse_function(tokens: ArrayView[Token]) -> (Function, ArrayView[Token]) {
  guard tokens is [Keyword(Fn), Lower(fname), Bracket('('), ..tokens] else {
    println("Parse Function Error, Not a function definition")
    panic()
  }
  let params: Array[(Var, TypeName)] = Array::new()
  let tokens = loop tokens {
    [Lower(param_name), Symbol(':'), Keyword(Array), Bracket('['), Upper(sub_type), Bracket(']'), .. rest_toks] => {
      let type_name = TypeName::from("Array", sub_type=Some(sub_type))
      params.push((param_name, type_name))
      continue rest_toks
    }
    [Lower(param_name), Symbol(':'), Keyword(Ref), Bracket('['), Upper(sub_type), Bracket(']'), .. rest_toks] => {
      let type_name = TypeName::from("Ref", sub_type=Some(sub_type))
      params.push((param_name, type_name))
      continue rest_toks
    }
    [Lower(param_name), Symbol(':'), Upper(type_name), .. rest_toks] => {
      let type_name = TypeName::from(type_name)
      params.push((param_name, type_name))
      continue rest_toks
    }
    [Symbol(','), .. rest_toks] => {
      continue rest_toks
    }
    [Bracket(')'), LeftArrow, ..rest_toks] => break rest_toks
    _ as tokens => {
      println("Parse Function Error: Unexpected token in parameters: \{tokens}")
      panic()
    }
  }

  // parse return type
  let (return_type, tokens) = match tokens {
    [Keyword(Array), Bracket('['), Upper(sub_type), Bracket(']'), Bracket('{'), .. rest_toks] => {
      let return_type = TypeName::from("Array", sub_type=Some(sub_type))
      (return_type, rest_toks)
    }
    [Keyword(Ref), Bracket('['), Upper(sub_type), Bracket(']'), Bracket('{'), .. rest_toks] => {
      let return_type = TypeName::from("Ref", sub_type=Some(sub_type))
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
  loop tokens {
    [Bracket('}'), ..] => break
    _ as tokens => {
      let (stmt, rest_toks) = parse_statement(tokens)
      body.push(stmt)
      continue rest_toks
    }
  }
  let function = Function::{
    name: fname,
    params: params,
    return_type,
    body: body
  }
  (function, tokens)
}

pub fn parse_struct(tokens: ArrayView[Token]) -> (StructDef, ArrayView[Token]) {
  guard tokens is [Keyword(Struct), Lower(name), Bracket('{'), ..tokens] else {
    println("Parse Struct Error, Not a struct definition")
    panic()
  }
  let fields: Array[(Var, TypeName)] = Array::new()
  let tokens = loop tokens {
    [Lower(field_name), Symbol(':'), Keyword(Array), Bracket('['), Upper(sub_type), Bracket(']'), Symbol(','), .. rest_toks] => {
      let type_name = TypeName::from("Array", sub_type=Some(sub_type))
      fields.push((field_name, type_name))
      continue rest_toks
    }
    [Lower(field_name), Symbol(':'), Keyword(Ref), Bracket('['), Upper(sub_type), Bracket(']'), Symbol(','), .. rest_toks] => {
      let type_name = TypeName::from("Ref", sub_type=Some(sub_type))
      fields.push((field_name, type_name))
      continue rest_toks
    }
    [Lower(field_name), Symbol(':'), Upper(type_name), Symbol(','), .. rest_toks] => {
      let type_name = TypeName::from(type_name)
      fields.push((field_name, type_name))
      continue rest_toks
    }
    [Bracket('}'), .. rest_toks] => break rest_toks
    _ as tokens => {
      println("Parse Struct Error: Unexpected token in struct fields: \{tokens}")
      panic()
    }
  }
  let struct_def = StructDef::{name: name, fields: fields}
  (struct_def, tokens)
}

pub fn parse_statement(tokens: ArrayView[Token]) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Keyword(Let), ..] => parse_let_statement(tokens)
    [Keyword(If), ..] => parse_if_statement(tokens)
    [Keyword(While), ..] => parse_while_statement(tokens)
    [Keyword(Return), ..] => parse_return_statement(tokens)
    [Lower(_), Symbol('='), ..] => parse_assign_statement(tokens)
    _ => {
      println("Parse Statement Error: Unexpected token in statement: \{tokens}")
      panic()
    }
  }
}

pub fn parse_let_statement(tokens: ArrayView[Token]) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Keyword(Let), Lower(var_name), Symbol(':'),
     Keyword(Array), Bracket('['), Upper(sub_type), Bracket(']'),
     Symbol('='), .. rest_toks] => {
      let type_name = TypeName::from("Array", sub_type=Some(sub_type))
      let (expr, rest_toks) = parse_expression(rest_toks)
      let stmt = Stmt::Let(var_name, type_name, expr)
      guard rest_toks is [Terminator, .. rest_toks] else {
        println("Parse Let Statement Error: Expected ';' after let statement")
        panic()
      }
      (stmt, rest_toks)
    }
    [Keyword(Let), Lower(var_name), Symbol(':'), Upper(type_name),
     Symbol('='), .. rest_toks] => {
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
      println("Parse Let Statement Error: Unexpected token in let statement: \{tokens}")
      panic()
    }
  }
}

pub fn parse_assign_statement(tokens: ArrayView[Token]) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Lower(var_name), Symbol('='), .. rest_toks] => {
      let (expr, rest_toks) = parse_expression(rest_toks)
      let stmt = Stmt::Assign(var_name, expr)
      (stmt, rest_toks)
    }
    _ => {
      println("Parse Assign Statement Error: Unexpected token in assignment: \{tokens}")
      panic()
    }
  }
}

pub fn parse_if_statement(tokens: ArrayView[Token]) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Keyword(If), .. rest_toks] => {
      let (condition, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Bracket('{'), .. rest_toks] else {
        println("Parse If Statement Error: Expected '}' after condition")
        panic()
      }
      let then_body: Array[Stmt] = Array::new()
      let rest_toks = loop rest_toks {
        [Bracket('}'), .. rest_toks] => break rest_toks
        _ as rest_toks => {
          let (stmt, rest_toks) = parse_statement(rest_toks)
          then_body.push(stmt)
          continue rest_toks
        }
      }
      let else_body: Array[Stmt] = Array::new()
      let rest_toks = if rest_toks is [Keyword(Else), Bracket('{'), .. rest_toks] {
        loop rest_toks {
          [Bracket('}'), ..rest_toks] => break rest_toks
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
      println("Parse If Statement Error: Unexpected token in if statement: \{tokens}")
      panic()
    }
  }
}

pub fn parse_while_statement(tokens: ArrayView[Token]) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Keyword(While), .. rest_toks] => {
      let (condition, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Bracket('{'), .. rest_toks] else {
        println("Parse While Statement Error: Expected '}' after condition")
        panic()
      }
      let body: Array[Stmt] = Array::new()
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
      println("Parse While Statement Error: Unexpected token in while statement: \{tokens}")
      panic()
    }
  }
}

pub fn parse_return_statement(tokens: ArrayView[Token]) -> (Stmt, ArrayView[Token]) {
  match tokens {
    [Keyword(Return), Terminator, .. rest_toks] => {
      let stmt = Stmt::Return(None)
      (stmt, rest_toks)
    }
    [Keyword(Return), .. rest_toks] => {
      let (expr, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Terminator, .. rest_toks] else {
        println("Parse Return Statement Error: Expected ';' after return expression")
        panic()
      }
      let stmt = Stmt::Return(Some(expr))
      (stmt, rest_toks)
    }
    _ => {
      println("Parse Return Statement Error: Unexpected token in return statement: \{tokens}")
      panic()
    }
  }
}

// precdence:
// +, -: 7
// *, /, %: 8
pub fn parse_expression(tokens: ArrayView[Token]) -> (Expr, ArrayView[Token]) {

  fn construct_bin_expr(left: Expr, right: Expr, oper: String) -> Expr {
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
      "&" => Expr::BitAnd(left, right) // bitwise AND
      "|" => Expr::BitOr(left, right) // bitwise OR
      "<<" => Expr::Shl(left, right) // left shift
      ">>" => Expr::Shr(left, right) // logical right shift
      _ => {
        println("Unknown operator: \{oper}")
        panic()
      }
    }
  }

  fn preced(op: String) -> Int {
    match op {
      "+" | "-" => 7
      "*" | "/" | "%" => 8
      "==" | "!=" | "<=" | ">=" | "<" | ">" => 6
      "&&" => 5
      "||" => 4
      "&" => 3 // bitwise AND
      "|" => 2 // bitwise OR
      "<<" => 1 // left shift
      ">>" => 1 // logical right shift
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
    [Operator(op), .. rest_toks] if opers.is_empty()  => {
      let (next_apply, rest_toks) = parse_apply_expr(rest_toks)
      exprs.push(Expr::Apply(next_apply))
      opers.push(op)
      continue rest_toks
    }
    [Operator(op), .. rest_toks] if preced(op) >= preced(opers.last().unwrap())  => {
      let (next_apply, rest_toks) = parse_apply_expr(rest_toks)
      exprs.push(Expr::Apply(next_apply))
      opers.push(op)
      continue rest_toks
    }
    [Operator(op), .. rest_toks] => {
      while preced(op) < preced(opers.last().unwrap()) {
        let right_expr = exprs.pop().unwrap()
        let left_expr = exprs.pop().unwrap()
        let oper = opers.pop().unwrap()
        let new_expr = construct_bin_expr(left_expr, right_expr, oper)
        exprs.push(new_expr)
      }
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

pub fn parse_apply_expr(tokens: ArrayView[Token]) -> (ApplyExpr, ArrayView[Token]) {
  match tokens {
    [Lower(var_name), Bracket('['), .. rest_toks] => {
      let (index_expr, rest_toks) = parse_expression(rest_toks)
      guard rest_toks is [Bracket(']'), .. rest_toks] else {
        println("Parse ApplyExpr Error: Expected ']' after array index")
        panic()
      }
      (ApplyExpr::ArrayGet(var_name, index_expr), rest_toks)
    }
    [Lower(var_name), Symbol('.'), Lower(field_name), .. rest_toks] => {
      (ApplyExpr::StructAccess(var_name, field_name), rest_toks)
    }
    [Lower(func_name), Bracket('('), .. rest_toks] => {
      let args: Array[Expr] = Array::new()
      let rest_toks = loop rest_toks {
        [Bracket(')'), .. rest_toks] => break rest_toks
        _ as rest_toks => {
          let (arg_expr, rest_toks) = parse_expression(rest_toks)
          args.push(arg_expr)
          if rest_toks is [Symbol(','), .. rest_toks] {
            continue rest_toks
          } else if rest_toks is [Bracket(')'), .. rest_toks] {
            break rest_toks
          } else {
            println("Parse ApplyExpr Error: Unexpected token in function call arguments: \{rest_toks}")
            panic()
          }
        }
      }
      (ApplyExpr::Call(func_name, args), rest_toks)
    }
    _ => {
      println("Parse ApplyExpr Error: Unexpected token in apply expression: \{tokens}")
      panic()
    }
  }
}

pub fn parse_atomic(tokens: ArrayView[Token]) -> (Atomic, ArrayView[Token]) {
  match tokens {
    [Bool(value), .. rest_toks] => (Bool(value), rest_toks)
    [Int(value), .. rest_toks] =>  (Int(value), rest_toks)
    [Int64(value), .. rest_toks] =>(Int64(value), rest_toks)
    [UInt(value), .. rest_toks] => (UInt(value), rest_toks)
    [UInt64(value), .. rest_toks] => (UInt64(value), rest_toks)
    [Float(value), .. rest_toks] =>  (Float(value), rest_toks)
    [Double(value), .. rest_toks] => (Double(value), rest_toks)
    [Lower(var_name), .. rest_toks] => (Var(var_name), rest_toks)
    [Bracket('['), .. rest_toks] => {
      let elements: Array[Expr] = Array::new()
      let rest_toks = loop rest_toks {
        [Bracket(']'), .. rest_toks] => break rest_toks
        _ as rest_toks => {
          let (expr, rest_toks) = parse_expression(rest_toks)
          elements.push(expr)
          if rest_toks is [Symbol(','), .. rest_toks] {
            continue rest_toks
          } else if rest_toks is [Bracket(']'), .. rest_toks] {
            break rest_toks
          } else {
            println("Parse Atomic Error: Unexpected token in array literal: \{rest_toks}")
            panic()
          }
        }
      }
      (Array(elements), rest_toks)
    }
    _ => {
      println("Parse Atomic Error: Unexpected token in atomic expression: \{tokens}")
      panic()
    }
  }
}
