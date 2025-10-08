///|
/// TinyMoonBit Syntax
///
/// Program :=
///     TopFunction
///   | ExternFunction
///   | TopLet
///   | StructDef
///   | EnumDef
///
/// ExternFunction :=
///   "extern" "fn" func_name "(" param* ")" "->" Type "=" stringlit ";"; 
///
/// TopLet :=
///   "let" ident TypeAnnote? "=" Expr ";"
///
/// StructDef :=
///   "struct" upper_ident "{" struct_item* "}"
///
/// struct_item := ident TypeAnnote ";"
///
/// EnumDef :=
///   "enum" upper_ident "{" enum_item* "}"
///
/// enum_item := upper_ident ("(" Type+ ")")? ";"
///
/// TopFunction :=
///   "fn" ident "(" param* ")" "->" Type "{" Stmt* "}"
///
/// Stmt :=
///     LetStmt
///   | LetMutStmt
///   | AssignStmt
///   | WhileStmt
///   | ForStmt
///
/// LetStmt :=
///   "let" pattern TypeAnnote? "=" Expr ";"
///
/// LetMutStmt :=
///   "let" "mut" ident TypeAnnote? "=" Expr ";"
///
/// AssignStmt :=
///   ident assign_op Expr ";"
///
/// assign_op := "=" | "+=" | "-=" | "*="
///
/// WhileStmt :=
///   "while" Expr "{" Stmt* "}"
///
/// ForStmt :=
///  "for" for_init? ";" for_cond? ";" for_step? "{" Stmt* "}" 
///
/// Expr :=
///     ApplyExpr
///   | unop ApplyExpr
///   | ApplyExpr binop ApplyExpr
///
/// unop := "-" | "+" "!"
///
/// binop: "+" | "-" | "*" | "/" | "%" | ">>" | "<<" |
///        "==" | ">=" | "<=" | ">" | "<" | "!="
///
/// ApplyExpr :=
///     AtomExpr
///   | ApplyExpr "[" Expr "]"  ;; Array Access
///   | ApplyExpr "(" Expr* ")" ;; Function Call 
///
/// AtomExpr :=
///     Literal
///   | ident
///   | "(" ")" ;; Unit
///   | "(" Expr ")"  ;; Paren
///   | "(" expr_list ")"  ;; Tuple
///   | "[" expr_list? "]" ;; Array
///   | BlockExpr
///   | IfExpr
///   | MatchExpr
///
/// BlockExpr :=
///   "{" Stmt* Expr? "}"
///
/// IfExpr :=
///   "if" Expr BlockExpr ("else" BlockExpr)?
///
/// MatchExpr :=
///   "match" Expr "{" match_item "}"
///
/// match_item :=
///   pattern ("if" Expr)? "=>" Expr ";"
pub struct TopFunction {
  lineno : Int
  column : Int
  fname : String
  // param_list: Array[Param]
  // ret_type: Type
  // stmts: Array[Stmt]
}

///|
///
/// Ast - Type
///
/// ```mbt
/// let code = "(Int, Int64, Float, Double) -> UInt"
/// let ctx = Context::new(code)
/// ctx .. tokenize()
///
/// let toks = ctx.tokens[:]
/// let (ty, _) = ctx.parse_type(toks)
///
/// assert_true(
///   ty is {kind: Function([
///     {kind: Int, ..},
///     {kind: Int64, ..},
///     {kind: Float, ..},
///     {kind: Double,..}
///   ], {kind: UInt, ..}), ..}
/// )
/// ```
pub struct Type {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  kind : TypeKind
} derive(Show, Eq)

///|
pub enum TypeKind {
  Unit
  Bool
  Int
  Int64
  UInt
  UInt64
  Float
  Double
  String
  Tuple(Array[Type])
  Array(Type)
  Function(Array[Type], Type)
  Defined(String, Array[Type]) // Array[Int], Map[String, Int]
} derive(Show, Eq)

///|
pub fn Context::parse_type(
  self : Self,
  tokens : ArrayView[Token],
) -> (Type, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Upper("Unit"), lineno, column }, .. rest] =>
      (
        Type::{
          kind: Unit,
          lineno,
          column,
          end_lineno: lineno,
          end_column: column,
        },
        rest,
      )
    [{ kind: Upper("Bool"), lineno, column }, .. rest] =>
      (
        Type::{
          kind: Bool,
          lineno,
          column,
          end_lineno: lineno,
          end_column: column,
        },
        rest,
      )
    [{ kind: Upper("Int"), lineno, column }, .. rest] =>
      (
        Type::{
          kind: Int,
          lineno,
          column,
          end_lineno: lineno,
          end_column: column,
        },
        rest,
      )
    [{ kind: Upper("UInt"), lineno, column }, .. rest] =>
      (
        Type::{
          kind: UInt,
          lineno,
          column,
          end_lineno: lineno,
          end_column: column,
        },
        rest,
      )
    [{ kind: Upper("Int64"), lineno, column }, .. rest] =>
      (
        Type::{
          kind: Int64,
          lineno,
          column,
          end_lineno: lineno,
          end_column: column,
        },
        rest,
      )
    [{ kind: Upper("UInt64"), lineno, column }, .. rest] =>
      (
        Type::{
          kind: UInt64,
          lineno,
          column,
          end_lineno: lineno,
          end_column: column,
        },
        rest,
      )
    [{ kind: Upper("Float"), lineno, column }, .. rest] =>
      (
        Type::{
          kind: Float,
          lineno,
          column,
          end_lineno: lineno,
          end_column: column,
        },
        rest,
      )
    [{ kind: Upper("Double"), lineno, column }, .. rest] =>
      (
        Type::{
          kind: Double,
          lineno,
          column,
          end_lineno: lineno,
          end_column: column,
        },
        rest,
      )
    [{ kind: Upper("String"), lineno, column }, .. rest] =>
      (
        Type::{
          kind: String,
          lineno,
          column,
          end_lineno: lineno,
          end_column: column,
        },
        rest,
      )
    [{ kind: Bracket('('), .. }, ..] as tokens =>
      self.parse_tuple_or_function_type(tokens)
    [{ kind: Upper(_), .. }, ..] as tokens => self.parse_defined_type(tokens)
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tok => raise ParseError((tok[0], "InValid Type Parsing"))
  }
}

///|
pub fn Context::parse_tuple_or_function_type(
  self : Self,
  tokens : ArrayView[Token],
) -> (Type, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Bracket('('), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_tuple_or_function_type")
    panic()
  }
  let tys : Array[Type] = Array::new()
  let (tokens, end_lineno, end_column) = loop tokens {
    [{ kind: Upper(_) | Bracket('('), .. }, ..] as tokens => {
      let (ty, rest) = self.parse_type(tokens)
      tys.push(ty)
      continue rest
    }
    [{ kind: Comma, .. }, { kind: Upper(_) | Bracket('('), .. }, ..] as tokens => {
      let (ty, rest) = self.parse_type(tokens[1:])
      tys.push(ty)
      continue rest
    }
    [{ kind: Bracket(')'), lineno, column }, .. rest] =>
      break (rest, lineno, column)
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tok => raise ParseError((tok[0], "InValid Type Parsing"))
  }
  if tokens is [{ kind: LeftArrow, .. }, .. tokens] {
    let (ret_ty, rest) = self.parse_type(tokens)
    (
      Type::{
        kind: Function(tys, ret_ty),
        lineno,
        column,
        end_lineno: ret_ty.end_lineno,
        end_column: ret_ty.end_column,
      },
      rest,
    )
  } else {
    (Type::{ kind: Tuple(tys), lineno, column, end_lineno, end_column }, tokens)
  }
}

///|
pub fn Context::parse_defined_type(
  self : Self,
  tokens : ArrayView[Token],
) -> (Type, ArrayView[Token]) raise ParseError {
  guard tokens
    is [{ kind: Upper(name), lineno, column } as master_tok, .. tokens] else {
    println("Compiler ICE: Defined Type Must start with Upper Ident")
    panic()
  }
  let tys : Array[Type] = Array::new()
  let (tokens, end_lineno, end_column) = if tokens
    is [{ kind: Bracket('['), .. }, .. tokens] {
    loop tokens {
      [{ kind: Upper(_), .. }, ..] as tokens => {
        let (sub_ty, tokens) = self.parse_type(tokens)
        tys.push(sub_ty)
        continue tokens
      }
      [{ kind: Comma, .. }, { kind: Upper(_), .. }, ..] as tokens => {
        let (sub_ty, tokens) = self.parse_type(tokens[1:])
        tys.push(sub_ty)
        continue tokens
      }
      [{ kind: Bracket(']'), lineno, column }, .. tokens] =>
        break (tokens, lineno, column)
      tokens => raise ParseError((tokens[0], "Unexpected token"))
    }
  } else {
    (tokens, lineno, column)
  }
  let kind = if name is "Array" {
    match tys.length() {
      0 => raise ParseError((master_tok, "Array Must provide element Type"))
      1 => Array(tys[0])
      _ =>
        raise ParseError((master_tok, "Array Must have only one element Type"))
    }
  } else {
    Defined(name, tys)
  }
  let def_ty = Type::{ kind, lineno, column, end_lineno, end_column }
  (def_ty, tokens)
}

///|
test "Type Parsing" {
  let code =
    #|Unit Int Int64 Bool UInt UInt64
    #|Float Double (Double, Int64)
    #|(Int) -> Int Array[Int] Point
    #|Map[K, V] Int
  let ctx = Context::new(code)
  ctx..tokenize()
  let { tokens, .. } = ctx
  let (ty, tok_view) = ctx.parse_type(tokens[:])
  assert_true(ty is { kind: Unit, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Int, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Int64, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Bool, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: UInt, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: UInt64, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Float, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Double, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Tuple(_), .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Function(_), .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Array(_), .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Defined(_), .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Defined(_), .. })
  let (ty, _) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Int, .. })
}

///|
pub struct Param {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  name : String
  ty : Type
} derive(Show, Eq)

///|
pub fn Context::parse_param(
  self : Self,
  tokens : ArrayView[Token],
) -> (Param, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Lower(name), lineno, column }, .. tokens] else {
    raise ParseError((tokens[0], "Expect a lower case"))
  }
  guard tokens is [{ kind: Colon, .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect a `:`"))
  }
  guard tokens is [{ kind: Upper(_), .. }, ..] else {
    raise ParseError((tokens[0], "Expect type name"))
  }
  let (ty, tokens) = self.parse_type(tokens)
  let { end_lineno, end_column, .. } = ty
  let param = Param::{ lineno, column, end_lineno, end_column, name, ty }
  (param, tokens)
}

///|
test "Param Parsing" {
  let code =
    #|a: Int b: Float
    #|c: Double foo: String 
    #|arr: Array[Double]
    #|map: Map[String, Int]
  let ctx = Context::new(code)
  ctx..tokenize()
  let { tokens, .. } = ctx
  let (param, tok_view) = ctx.parse_param(tokens[:])
  assert_true(param is { name: "a", ty: { kind: Int, .. }, .. })
  let (param, tok_view) = ctx.parse_param(tok_view)
  assert_true(param is { name: "b", ty: { kind: Float, .. }, .. })
  let (param, tok_view) = ctx.parse_param(tok_view)
  assert_true(param is { name: "c", ty: { kind: Double, .. }, .. })
  let (param, tok_view) = ctx.parse_param(tok_view)
  assert_true(param is { name: "foo", ty: { kind: String, .. }, .. })
  let (param, tok_view) = ctx.parse_param(tok_view)
  assert_true(
    param is { name: "arr", ty: { kind: Array({ kind: Double, .. }), .. }, .. },
  )
  let (param, _) = ctx.parse_param(tok_view)
  assert_true(
    param
    is {
      name: "map",
      ty: {
        kind: Defined("Map", [{ kind: String, .. }, { kind: Int, .. }]),
        ..,
      },
      ..,
    },
  )
}

///|
// pub struct ExternFunction {
//   // Location Infomation
//   // Start from
//   lineno: Int
//   column: Int
//   // End to
//   end_lineno: Int
//   end_column: Int
//
//   // fname and ffi_name
//   // in code like: extern fn sin(x: Float) -> Float = "sinf"
//   // sin is fname, sinf is ffi_name
//   fname: String
//   ffi_name: String
//
//   // param list
//   params: Array[Param]
// }
//
// pub fn Context::parse_extern_function(
//   self: Self,
//   tokens: ArrayView[Token]
// ) -> (ExternFunction, ArrayView[Token]) raise ParseError {
//
//   guard tokens is [{kind: Keyword(Extern), ..}, ..tokens] else {
//     println("Compiler ICE: extern function should start with extern")
//     panic()
//   }
//
//   guard tokens is [{kind: Keyword(Fn),..},..tokens] else {
//     raise ParseError((tokens[0], "Parse Error, expect \"fn\"."))
//   }
//
//   guard tokens is [{kind: Lower(fname), ..}, .. tokens] else {
//     raise ParseError((tokens[0], "Parse Error, expect a lower ident."))
//   }
//
//   guard tokens is [{kind: Bracket('('), ..}, ..tokens] else {
//     raise ParseError((tokens[0], "Parse Error, expect left parenthesis '('"))
//   }
// }
