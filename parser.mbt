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
///   left_value assign_op Expr ";"
///
/// left_value :=
///     ident
///   | left_value "[" Expr "]" ;; Array Access
///   | left_value "." ident ;; Field Access
///
/// assign_op := "=" | "+=" | "-=" | "*="
///
/// WhileStmt :=
///   "while" Expr "{" Stmt* "}"
///
/// ForStmt :=
///  "for" for_init? ";" for_cond? ";" for_step? "{" Stmt* "}" 
///
/// for_init := (ident "=" Expr)*
/// for_cond := Expr
/// for_step := (ident assign_op Expr)*
///
/// Expr :=
///     ApplyExpr
///   | ApplyExpr binop ApplyExpr ;; Binary
///   | IfExpr
///   | MatchExpr
///   | BlockExpr
///
/// unop := "-" | "+" | "!"
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



///|
pub struct TopFunction {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  fname : String
  param_list: Array[Param]
  ret_type: Type
  body: BlockExpr
}

pub fn Context::parse_top_function(
  self : Self,
  tokens : ArrayView[Token],
) -> (TopFunction, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Fn), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_top_function")
    panic()
  }
  guard tokens is [{ kind: Lower(fname), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect a lower ident"))
  }
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect '('"))
  }
  let (param_list, tokens) = self.parse_param_list(tokens)
  guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect ')'"))
  }
  guard tokens is [{ kind: RightArrow, .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect '->'"))
  }
  let (ret_type, tokens) = self.parse_type(tokens)
  let (body, tokens) = self.parse_block_expr(tokens)
  let end_lineno = body.end_lineno
  let end_column = body.end_column
  let top_function = TopFunction::{
    lineno,
    column,
    end_lineno,
    end_column,
    fname,
    param_list,
    ret_type,
    body,
  }
  (top_function, tokens)
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
///
/// Ast - Tuple Type or Function Type
///
/// ```mbt
/// let code = "(Int, Int64, Float, Double) -> UInt"
/// let ctx = Context::new(code)
/// ctx .. tokenize()
///
/// let toks = ctx.tokens[:]
/// let (ty, _) = ctx.parse_type(toks) // call parse_tuple_or_function_type inside
///
/// assert_true(
///   ty is {kind: Function([
///     {kind: Int, ..},
///     {kind: Int64, ..},
///     {kind: Float, ..},
///     {kind: Double,..}
///     ], {kind: UInt, ..}), ..}
/// )
/// ```
fn Context::parse_tuple_or_function_type(
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
  if tokens is [{ kind: RightArrow, .. }, .. tokens] {
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
/// 
/// Ast - Defined Type
///
/// ```mbt
/// let code = "Map[Int, String]"
/// let ctx = Context::new(code)
/// ctx .. tokenize()
///
/// let toks = ctx.tokens[:]
/// let (ty, _) = ctx.parse_type(toks) // call parse_defined_type inside
///
/// assert_true(ty is {kind: Defined("Map", [{kind: Int, ..}, {kind: String, ..}]), ..})
/// ```
fn Context::parse_defined_type(
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
      1 => TypeKind::Array(tys[0])
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
///
/// Ast - Param
///
/// ```mbt
/// let code = "a: Int"
/// let ctx = Context::new(code)
/// ctx .. tokenize()
///
/// let toks = ctx.tokens[:]
/// let (param, _) = ctx.parse_param(toks)
///
/// assert_true(param is {name: "a", ty: {kind: Int, ..}, ..})
/// ```
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
///
/// Ast - Param List
///
/// ```mbt
/// let code = "(a: Int, b: Float, c: Double,)"
/// let ctx = Context::new(code)
/// ctx..tokenize()
/// let { tokens, .. } = ctx
/// guard tokens is [{kind: Bracket('('), ..}, ..tokens]
/// let (params, tok_view) = ctx.parse_param_list(tokens)
/// assert_true(params.length() is 3)
/// assert_true(params[0] is {name: "a", ty: {kind: Int, ..}, ..})
/// assert_true(params[1] is {name: "b", ty: {kind: Float, ..}, ..})
/// assert_true(params[2] is {name: "c", ty: {kind: Double, ..}, ..})
/// assert_true(tok_view is [{kind: Bracket(')'), ..}, ..])
/// ```
pub fn Context::parse_param_list(
  self : Self,
  tokens : ArrayView[Token],
) -> (Array[Param], ArrayView[Token]) raise ParseError {
  let params : Array[Param] = Array::new()
  let tokens = loop tokens {
    [{ kind: Lower(_), .. }, ..] as tokens => {
      let (param, rest) = self.parse_param(tokens)
      params.push(param)
      continue rest
    }
    [{ kind: Comma, .. }, { kind: Lower(_), .. }, ..] as tokens => {
      let (param, rest) = self.parse_param(tokens[1:])
      params.push(param)
      continue rest
    }
    [{ kind: Comma, .. }, { kind: Bracket(')'), .. }, ..] as tokens =>
      break tokens[1:]
    [{ kind: Bracket(')'), .. }, ..] as tokens => break tokens
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tok => raise ParseError((tok[0], "InValid Param List Parsing"))
  }
  (params, tokens)
}

///|
///
/// Ast - Extern Function
///
/// ```mbt
/// let code = "extern fn sin(x: Float) -> Float = \"sinf\";"
/// let ctx = Context::new(code)
/// ctx .. tokenize()
///
/// let toks = ctx.tokens[:]
/// let (extern_fn, _) = ctx.parse_extern_function(toks)
///
/// assert_true(extern_fn is {
///   fname: "sin",
///   ffi_name: "sinf",
///   params: [{name: "x", ty: {kind: Float, ..}, ..}],
///   ret_ty: {kind: Float, ..},
///   ..
/// })
/// ```
pub struct ExternFunction {
  // Location Infomation
  // Start from
  lineno : Int
  column : Int
  // End to
  end_lineno : Int
  end_column : Int

  // fname and ffi_name
  // in code like: extern fn sin(x: Float) -> Float = "sinf"
  // sin is fname, sinf is ffi_name
  fname : String
  ffi_name : String

  // param list
  params : Array[Param]
  ret_ty : Type
}

///|
pub fn Context::parse_extern_function(
  self : Self,
  tokens : ArrayView[Token],
) -> (ExternFunction, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Extern), .. }, .. tokens] else {
    println("Compiler ICE: extern function should start with extern")
    panic()
  }
  guard tokens is [{ kind: Keyword(Fn), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Parse Error, expect \"fn\"."))
  }
  guard tokens is [{ kind: Lower(fname), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Parse Error, expect a lower ident."))
  }
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Parse Error, expect left parenthesis '('"))
  }
  let (params, tokens) = self.parse_param_list(tokens)
  guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Parse Error, expect right parenthesis ')'"))
  }
  guard tokens is [{ kind: RightArrow, .. }, .. tokens] else {
    raise ParseError((tokens[0], "Parse Error, expect '->'"))
  }
  let (ret_ty, tokens) = self.parse_type(tokens)
  guard tokens is [{ kind: AssignOp(Assign), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Parse Error, expect '='"))
  }
  guard tokens is [{ kind: String(ffi_name), lineno, column }, .. tokens] else {
    raise ParseError((tokens[0], "Parse Error, expect a string literal"))
  }
  guard tokens
    is [{ kind: SemiColon, lineno: end_lineno, column: end_column }, .. tokens] else {
    raise ParseError((tokens[0], "Parse Error, expect ';'"))
  }
  let extern_fn = ExternFunction::{
    lineno,
    column,
    end_lineno,
    end_column,
    fname,
    ffi_name,
    params,
    ret_ty,
  }
  (extern_fn, tokens)
}

///|
pub struct TopLet {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  name : String
  ty : Type?
  expr : Expr
}

///|
pub fn Context::parse_top_let(
  self : Self,
  tokens : ArrayView[Token],
) -> (TopLet, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Let), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_top_let")
    panic()
  }
  guard tokens is [{ kind: Lower(name), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect a lower ident"))
  }
  let (ty, tokens) = if tokens is [{ kind: Colon, .. }, .. tokens] {
    guard tokens is [{ kind: Upper(_), .. }, ..] else {
      raise ParseError((tokens[0], "Expect a type name"))
    }
    let (ty, tokens) = self.parse_type(tokens[1:])
    (Some(ty), tokens)
  } else {
    (None, tokens)
  }
  guard tokens is [{ kind: AssignOp(Assign), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect '='"))
  }
  let (expr, tokens) = self.parse_expr(tokens)
  guard tokens
    is [{ kind: SemiColon, lineno: end_lineno, column: end_column }, .. tokens] else {
    raise ParseError((tokens[0], "Expect ';'"))
  }
  let top_let = TopLet::{
    lineno,
    column,
    end_lineno,
    end_column,
    name,
    ty,
    expr,
  }
  (top_let, tokens)
}

///|
pub struct Expr {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  ty : TypeKind?
  kind : ExprKind
} derive(Show, Eq)

///|
///
/// Ast - Expr
///
/// ```mbt
/// let code = "a + b * c"
/// let ctx = Context::new(code)
/// ctx .. tokenize()
///
/// let toks = ctx.tokens[:]
/// let (expr, _) = ctx.parse_expr(toks)
/// assert_true(
///   expr.kind is BinaryExpr(Add, e1, e2) &&
///   e1.kind is ApplyExpr(_) &&
///   e2.kind is BinaryExpr(Mul, e3, e4) &&
///   e3.kind is ApplyExpr(_) &&
///   e4.kind is ApplyExpr(_)
/// )
/// ```
pub fn Context::parse_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (Expr, ArrayView[Token]) raise ParseError {
  guard tokens is [tok, ..] else {
    println("Compiler ICE: Empty Token ArrayView")
    panic()
  }
  match tok.kind {
    Keyword(If) => {
      let (if_expr, rest) = self.parse_if_expr(tokens)
      let expr = Expr::{
        lineno: if_expr.lineno,
        column: if_expr.column,
        end_lineno: if_expr.end_lineno,
        end_column: if_expr.end_column,
        ty: None,
        kind: ExprKind::IfExpr(if_expr),
      }
      return (expr, rest)
    }
    Bracket('{') => {
      let (block, rest) = self.parse_block_expr(tokens)
      let expr = Expr::{
        lineno: block.lineno,
        column: block.column,
        end_lineno: block.end_lineno,
        end_column: block.end_column,
        ty: None,
        kind: ExprKind::BlockExpr(block),
      }
      return (expr, rest)
    }
    _ => ()
  }
  let op_stack : @deque.Deque[BinaryOp] = @deque.Deque::new()
  let expr_stack : @deque.Deque[Expr] = @deque.Deque::new()
  let (apply_expr, tokens) = self.parse_apply_expr(tokens)
  let head_expr = Expr::{
    lineno: apply_expr.lineno,
    column: apply_expr.column,
    end_lineno: apply_expr.end_lineno,
    end_column: apply_expr.end_column,
    ty: apply_expr.ty,
    kind: ExprKind::ApplyExpr(apply_expr),
  }
  expr_stack.push_back(head_expr)
  let mut tokens = tokens
  while tokens is [{ kind: BinaryOp(op), .. }, .. rest] {
    let (apply_expr, rest) = self.parse_apply_expr(rest)
    let next_expr = Expr::{
      lineno: apply_expr.lineno,
      column: apply_expr.column,
      end_lineno: apply_expr.end_lineno,
      end_column: apply_expr.end_column,
      ty: apply_expr.ty,
      kind: ExprKind::ApplyExpr(apply_expr),
    }
    while !op_stack.is_empty() &&
          op.precedence() <= op_stack.back().unwrap().precedence() {
      let right = expr_stack.pop_back().unwrap()
      let left = expr_stack.pop_back().unwrap()
      let bop = op_stack.pop_back().unwrap()
      let new_expr = Expr::{
        lineno: left.lineno,
        column: left.column,
        end_lineno: right.end_lineno,
        end_column: right.end_column,
        ty: None,
        kind: ExprKind::BinaryExpr(bop, left, right),
      }
      expr_stack.push_back(new_expr)
    }
    op_stack.push_back(op)
    expr_stack.push_back(next_expr)
    tokens = rest
  }
  while !op_stack.is_empty() {
    let right = expr_stack.pop_back().unwrap()
    let left = expr_stack.pop_back().unwrap()
    let bop = op_stack.pop_back().unwrap()
    let new_expr = Expr::{
      lineno: left.lineno,
      column: left.column,
      end_lineno: right.end_lineno,
      end_column: right.end_column,
      ty: None,
      kind: ExprKind::BinaryExpr(bop, left, right),
    }
    expr_stack.push_back(new_expr)
  }
  let expr = expr_stack.pop_back().unwrap()
  (expr, tokens)
}

///|
fn Context::parse_expr_list(self: Self, tokens: ArrayView[Token]) -> (Array[Expr], ArrayView[Token]) raise ParseError {
  let exprs: Array[Expr] = Array::new()
  let tokens = loop tokens {
    [{ kind: Bracket(')'), .. }, ..] as tokens => break tokens
    [{ kind: Comma, .. }, { kind: Bracket(')'), .. }, ..] as tokens => break tokens[1:]
    [{ kind: Comma, .. }, ..tokens] => {
      let (expr, rest) = self.parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (expr, rest) = self.parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
  }
  (exprs, tokens)
}

///|
pub enum ExprKind {
  ApplyExpr(ApplyExpr)
  BlockExpr(BlockExpr)
  BinaryExpr(BinaryOp, Expr, Expr)
  IfExpr(IfExpr)
  //MatchExpr(MatchExpr)
} derive(Show, Eq)

///|
pub struct IfExpr {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  ty: TypeKind?
  cond : Expr
  then_block : BlockExpr
  else_block : @either.Either[IfExpr, BlockExpr]?
} derive(Show, Eq)

///|
pub fn Context::parse_if_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (IfExpr, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(If), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_if_expr")
    panic()
  }
  let (cond, tokens) = self.parse_expr(tokens)
  let (then_block, tokens) = self.parse_block_expr(tokens)
  let (else_block, tokens) = if tokens
    is [{ kind: Keyword(Else), .. }, .. tokens] {
    if tokens is [{ kind: Keyword(If), .. }, ..] {
      let (else_if, tokens) = self.parse_if_expr(tokens)
      (Some(@either.Either::Left(else_if)), tokens)
    } else {
      guard tokens is [{ kind: Bracket('{'), .. }, ..] else {
        raise ParseError((tokens[1], "Expect '{' after else"))
      }
      let (else_block, tokens) = self.parse_block_expr(tokens[1:])
      (Some(@either.Either::Right(else_block)), tokens)
    }
  } else {
    (None, tokens)
  }
  let if_expr = IfExpr::{
    lineno,
    column,
    ty: None,
    end_lineno: else_block.map_or(then_block.end_lineno, eb => match eb {
      @either.Either::Left(ie) => ie.end_lineno
      @either.Either::Right(be) => be.end_lineno
    }),
    end_column: else_block.map_or(then_block.end_column, eb => match eb {
      @either.Either::Left(ie) => ie.end_column
      @either.Either::Right(be) => be.end_column
    }),
    cond,
    then_block,
    else_block,
  }
  (if_expr, tokens)
}

///|
pub struct BlockExpr {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  ty: TypeKind?
  stmts : Array[Stmt]
  expr : Expr?
} derive(Show, Eq)

///|
pub fn Context::parse_block_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (BlockExpr, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Bracket('{'), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_block_expr")
    panic()
  }
  let stmts : Array[Stmt] = Array::new()
  let (tokens, end_lineno, end_column) = loop tokens[1:] {
    [{ kind: Bracket('}'), lineno, column }, .. rest] =>
      break (rest, lineno, column)
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (stmt, rest) = self.parse_stmt(tokens)
      stmts.push(stmt)
      continue rest
    }
  }
  let block_expr = BlockExpr::{
    lineno,
    column,
    end_lineno,
    end_column,
    ty: None,
    stmts,
    expr: None,
  }
  (block_expr, tokens)
}

///|
///
/// Ast - Apply Expression
///
/// ```mbt
/// let code = "arr[0].field.method(42, 3.14)"
///
/// let ctx = Context::new(code)
/// ctx .. tokenize()
///
/// let toks = ctx.tokens[:]
/// let (apply_expr, _) = ctx.parse_apply_expr(toks)
/// assert_true(
///   apply_expr.kind is Call(a3, _) &&
///   a3.kind is FieldAccess(a2, "method") &&
///   a2.kind is FieldAccess(a1, "field") &&
///   a1.kind is ArrayAccess(a0, _) &&
///   a0.kind is AtomExpr(_)
/// )
/// ```
pub struct ApplyExpr {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  ty : TypeKind?
  kind : ApplyExprKind
} derive(Show, Eq)

///|
pub enum ApplyExprKind {
  AtomExpr(AtomExpr)
  ArrayAccess(ApplyExpr, Expr)
  FieldAccess(ApplyExpr, String)
  TupleAccess(ApplyExpr, Int)
  Call(ApplyExpr, Array[Expr])
} derive(Show, Eq)

///|
pub fn Context::parse_apply_expr(
  self : Context,
  tokens : ArrayView[Token],
) -> (ApplyExpr, ArrayView[Token]) raise ParseError {
  let (atom_expr, tokens) = self.parse_atom_expr(tokens)
  let apply_expr = ApplyExpr::{
    lineno: atom_expr.lineno,
    column: atom_expr.column,
    end_lineno: atom_expr.end_lineno,
    end_column: atom_expr.end_column,
    ty: atom_expr.ty,
    kind: ApplyExprKind::AtomExpr(atom_expr),
  }
  if !(tokens is [{kind: Bracket('[') | Dot | Bracket('('), ..}, ..]) {
    return (apply_expr, tokens)
  }

  let mut apply_expr = apply_expr

  loop tokens {
    [{ kind: Bracket('['), .. }, ..tokens] => {
      let (index_expr, tokens) = self.parse_expr(tokens)
      guard tokens is [{ kind: Bracket(']'), lineno, column }, ..tokens] else {
        raise ParseError((tokens[0], "Expect ']'"))
      }
      apply_expr = ApplyExpr::{
        lineno: apply_expr.lineno,
        column: apply_expr.column,
        end_lineno: lineno,
        end_column: column,
        ty: None,
        kind: ApplyExprKind::ArrayAccess(apply_expr, index_expr),
      }
      continue tokens
    }
    [{ kind: Dot, .. }, { kind: Lower(field), lineno, column }, ..tokens] => {
      apply_expr = ApplyExpr::{
        lineno: apply_expr.lineno,
        column: apply_expr.column,
        end_lineno: lineno,
        end_column: column,
        ty: None,
        kind: ApplyExprKind::FieldAccess(apply_expr, field),
      }
      continue tokens
    }
    [{ kind: Dot, .. }, { kind: Int(idx), lineno, column }, ..tokens] => {
      apply_expr = ApplyExpr::{
        lineno: apply_expr.lineno,
        column: apply_expr.column,
        end_lineno: lineno,
        end_column: column,
        ty: None,
        kind: ApplyExprKind::TupleAccess(apply_expr, idx),
      }
      continue tokens
    }
    [{ kind: Bracket('('), .. }, ..tokens] => {
      let (args, tokens) = self.parse_expr_list(tokens)
      guard tokens is [{ kind: Bracket(')'), lineno, column }, ..tokens] else {
        raise ParseError((tokens[0], "Expect ')'"))
      }
      apply_expr = ApplyExpr::{
        lineno: apply_expr.lineno,
        column: apply_expr.column,
        end_lineno: lineno,
        end_column: column,
        ty: None,
        kind: ApplyExprKind::Call(apply_expr, args),
      }
      continue tokens
    }
    tokens => break (apply_expr, tokens)
  }
}

///|
///
/// Ast - Atom Expression
///
/// ```mbt
/// let code = "42 3.14 true"
/// let ctx = Context::new(code)
/// ctx .. tokenize()
///
/// let toks = ctx.tokens[:]
/// let (a1, toks) = ctx.parse_atom_expr(toks)
/// let (a2, toks) = ctx.parse_atom_expr(toks)
/// let (a3, _) = ctx.parse_atom_expr(toks)
///
/// assert_true(a1.kind is Int(42))
/// assert_true(a2.kind is Double(3.14))
/// assert_true(a3.kind is Bool(true))
/// ```
pub struct AtomExpr {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  ty : TypeKind?
  kind : AtomExprKind
} derive(Show, Eq)

///|
pub enum AtomExprKind {
  Int(Int)
  Int64(Int64)
  UInt(UInt)
  UInt64(UInt64)
  Float(Float)
  Double(Double)
  Bool(Bool)
  String(String)
  Ident(String)
  Unit
  Paren(Expr)
  Tuple(Array[Expr])
  Array(Array[Expr])
  //MatchExpr(MatchExpr)
} derive(Show, Eq)

///|
pub fn Context::parse_atom_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Int(v), lineno, column }, ..] => {
      let expr = AtomExpr::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        ty: Some(Int),
        kind: AtomExprKind::Int(v),
      }
      (expr, tokens[1:])
    }
    [{ kind: Int64(v), lineno, column }, ..] => {
      let expr = AtomExpr::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        ty: Some(Int64),
        kind: AtomExprKind::Int64(v),
      }
      (expr, tokens[1:])
    }
    [{ kind: UInt(v), lineno, column }, ..] => {
      let expr = AtomExpr::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        ty: Some(UInt),
        kind: AtomExprKind::UInt(v),
      }
      (expr, tokens[1:])
    }
    [{ kind: UInt64(v), lineno, column }, ..] => {
      let expr = AtomExpr::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        ty: Some(UInt64),
        kind: AtomExprKind::UInt64(v),
      }
      (expr, tokens[1:])
    }
    [{ kind: Float(v), lineno, column }, ..] => {
      let expr = AtomExpr::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        ty: Some(Float),
        kind: AtomExprKind::Float(v),
      }
      (expr, tokens[1:])
    }
    [{ kind: Double(v), lineno, column }, ..] => {
      let expr = AtomExpr::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        ty: Some(Double),
        kind: AtomExprKind::Double(v),
      }
      (expr, tokens[1:])
    }
    [{ kind: Bool(v), lineno, column }, ..] => {
      let expr = AtomExpr::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        ty: Some(Bool),
        kind: AtomExprKind::Bool(v),
      }
      (expr, tokens[1:])
    }
    [{ kind: String(ident), lineno, column }, ..] => {
      let expr = AtomExpr::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        ty: Some(String),
        kind: AtomExprKind::String(ident),
      }
      (expr, tokens[1:])
    }
    [{ kind: Lower(ident), lineno, column }, ..] => {
      let expr = AtomExpr::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        ty: None,
        kind: AtomExprKind::Ident(ident),
      }
      (expr, tokens[1:])
    }
    [{ kind: Bracket('('), .. }, ..] => self.parse_paren_or_tuple_expr(tokens)
    [{ kind: Bracket('['), .. }, ..] => self.parse_array_expr(tokens)
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    _ => raise ParseError((tokens[0], "InValid Atom Expression"))
  }
}

///|
fn Context::parse_paren_or_tuple_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Bracket('('), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_paren_or_tuple_expr")
    panic()
  }
  let exprs : Array[Expr] = Array::new()
  let (tokens, end_lineno, end_column) = loop tokens {
    [{ kind: Bracket(')'), lineno, column }, .. rest] =>
      break (rest, lineno, column)
    [{ kind: Comma, .. }, { kind: Bracket(')'), lineno, column }, .. rest] =>
      break (rest, lineno, column)
    [{ kind: Comma, .. }, .. tokens] => {
      let (expr, rest) = self.parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (expr, rest) = self.parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
  }
  let kind = match exprs.length() {
    0 => AtomExprKind::Unit
    1 => AtomExprKind::Paren(exprs[0])
    _ => AtomExprKind::Tuple(exprs)
  }
  let atom_expr = AtomExpr::{
    lineno,
    column,
    end_lineno,
    end_column,
    ty: None,
    kind,
  }
  (atom_expr, tokens)
}

///|
fn Context::parse_array_expr(
  self : Self,
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Bracket('['), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_array_expr")
    panic()
  }
  let exprs : Array[Expr] = Array::new()
  let (tokens, end_lineno, end_column) = loop tokens[1:] {
    [{ kind: Bracket(']'), lineno, column }, .. rest] =>
      break (rest, lineno, column)
    [{ kind: Comma, .. }, { kind: Bracket(']'), lineno, column }, .. rest] =>
      break (rest, lineno, column)
    [{ kind: Comma, .. }, .. tokens] => {
      let (expr, rest) = self.parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (expr, rest) = self.parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
  }
  let atom_expr = AtomExpr::{
    lineno,
    column,
    end_lineno,
    end_column,
    ty: None,
    kind: AtomExprKind::Array(exprs),
  }
  (atom_expr, tokens)
}

///|
pub struct Stmt {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  kind : StmtKind
} derive(Show, Eq)

///|
pub enum StmtKind {
  LetStmt(LetStmt)
  LetMutStmt(LetMutStmt)
  AssignStmt(AssignStmt)
  WhileStmt(WhileStmt)
  ForStmt(ForStmt)
  ExprStmt(Expr)
} derive(Show, Eq)

///|
pub fn Context::parse_stmt(
  self : Self,
  tokens : ArrayView[Token],
) -> (Stmt, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Keyword(Let), .. }, { kind: Keyword(Mut), .. }, ..] as tokens => {
      let (let_mut_stmt, rest) = self.parse_let_mut_stmt(tokens)
      let stmt = Stmt::{
        lineno: let_mut_stmt.lineno,
        column: let_mut_stmt.column,
        end_lineno: let_mut_stmt.end_lineno,
        end_column: let_mut_stmt.end_column,
        kind: StmtKind::LetMutStmt(let_mut_stmt),
      }
      (stmt, rest)
    }
    [{ kind: Keyword(Let), .. }, ..] as tokens => {
      let (let_stmt, rest) = self.parse_let_stmt(tokens)
      let stmt = Stmt::{
        lineno: let_stmt.lineno,
        column: let_stmt.column,
        end_lineno: let_stmt.end_lineno,
        end_column: let_stmt.end_column,
        kind: StmtKind::LetStmt(let_stmt),
      }
      (stmt, rest)
    }
    // Assignment must start with a lower ident
    // but starting with a lower ident does not
    // mean it's an assignment.
    //
    // Hence need to parse a left value first and
    // check if it's followed by an assignment operator.
    [{ kind: Lower(_), .. }, ..] as tokens => {
      let (_, rest) = self.parse_left_value(tokens)
      if rest is [{kind: AssignOp(_), ..}, ..] {
        let (assign_stmt, rest) = self.parse_assign_stmt(tokens)
        let stmt = Stmt::{
          lineno: assign_stmt.lineno,
          column: assign_stmt.column,
          end_lineno: assign_stmt.end_lineno,
          end_column: assign_stmt.end_column,
          kind: StmtKind::AssignStmt(assign_stmt),
        }
        (stmt, rest)
      } else {
        let (expr, rest) = self.parse_expr(tokens)
        guard rest
          is [{ kind: SemiColon, lineno: end_lineno, column: end_column }, ..] else {
          raise ParseError((rest[0], "Expect ';'"))
        }
        let stmt = Stmt::{
          lineno: expr.lineno,
          column: expr.column,
          end_lineno,
          end_column,
          kind: StmtKind::ExprStmt(expr),
        }
        (stmt, rest[1:])
      }
    }
    [{ kind: Keyword(While), .. }, ..] as tokens => {
      let (while_stmt, rest) = self.parse_while_stmt(tokens)
      let stmt = Stmt::{
        lineno: while_stmt.lineno,
        column: while_stmt.column,
        end_lineno: while_stmt.end_lineno,
        end_column: while_stmt.end_column,
        kind: StmtKind::WhileStmt(while_stmt),
      }
      (stmt, rest)
    }
    [{ kind: Keyword(For), .. }, ..] as tokens => {
      let (for_stmt, rest) = self.parse_for_stmt(tokens)
      let stmt = Stmt::{
        lineno: for_stmt.lineno,
        column: for_stmt.column,
        end_lineno: for_stmt.end_lineno,
        end_column: for_stmt.end_column,
        kind: StmtKind::ForStmt(for_stmt),
      }
      (stmt, rest)
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (expr, rest) = self.parse_expr(tokens)
      guard rest
        is [{ kind: SemiColon, lineno: end_lineno, column: end_column }, ..] else {
        raise ParseError((rest[0], "Expect ';'"))
      }
      let stmt = Stmt::{
        lineno: expr.lineno,
        column: expr.column,
        end_lineno,
        end_column,
        kind: StmtKind::ExprStmt(expr),
      }
      (stmt, rest[1:])
    }
  }
}

///|
pub struct LetStmt {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  pattern : Pattern
  ty : Type?
  expr : Expr
} derive(Show, Eq)

///|
pub fn Context::parse_let_stmt(
  self : Self,
  tokens : ArrayView[Token],
) -> (LetStmt, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Let), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_let_stmt")
    panic()
  }
  let (pattern, tokens) = self.parse_pattern(tokens)
  let (ty, tokens) = if tokens is [{ kind: Colon, .. }, .. tokens] {
    guard tokens is [{ kind: Upper(_), .. }, ..] else {
      raise ParseError((tokens[0], "Expect a type name"))
    }
    let (ty, tokens) = self.parse_type(tokens[1:])
    (Some(ty), tokens)
  } else {
    (None, tokens)
  }
  guard tokens is [{ kind: AssignOp(Assign), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect '='"))
  }
  let (expr, tokens) = self.parse_expr(tokens)
  guard tokens
    is [{ kind: SemiColon, lineno: end_lineno, column: end_column }, .. tokens] else {
    raise ParseError((tokens[0], "Expect ';'"))
  }
  let let_stmt = LetStmt::{
    lineno,
    column,
    end_lineno,
    end_column,
    pattern,
    ty,
    expr,
  }
  (let_stmt, tokens)
}

///|
pub struct LetMutStmt {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  name : String
  ty : Type?
  expr : Expr
} derive(Show, Eq)

///|
pub fn Context::parse_let_mut_stmt(
  self : Self,
  tokens : ArrayView[Token],
) -> (LetMutStmt, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Let), lineno, column }, { kind: Keyword(Mut), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_let_mut_stmt")
    panic()
  }
  guard tokens is [{ kind: Lower(name), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect a lower ident"))
  }
  let (ty, tokens) = if tokens is [{ kind: Colon, .. }, .. tokens] {
    guard tokens is [{ kind: Upper(_), .. }, ..] else {
      raise ParseError((tokens[0], "Expect a type name"))
    }
    let (ty, tokens) = self.parse_type(tokens[1:])
    (Some(ty), tokens)
  } else {
    (None, tokens)
  }
  guard tokens is [{ kind: AssignOp(Assign), .. }, .. tokens] else {
    raise ParseError((tokens[0], "Expect '='"))
  }
  let (expr, tokens) = self.parse_expr(tokens)
  guard tokens
    is [{ kind: SemiColon, lineno: end_lineno, column: end_column }, .. tokens] else {
    raise ParseError((tokens[0], "Expect ';'"))
  }
  let let_mut_stmt = LetMutStmt::{
    lineno,
    column,
    end_lineno,
    end_column,
    name,
    ty,
    expr,
  }
  (let_mut_stmt, tokens)
}

///|
pub struct AssignStmt {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  left_value: LeftValue
  op : AssignOp
  expr : Expr
} derive(Show, Eq)

///|
pub fn Context::parse_assign_stmt(
  self : Self,
  tokens : ArrayView[Token],
) -> (AssignStmt, ArrayView[Token]) raise ParseError {
  let (left_value, tokens) = self.parse_left_value(tokens)
  guard tokens is [{ kind: AssignOp(op), .. }, ..tokens] else {
    raise ParseError((tokens[0], "Expect an assign operator"))
  }
  let (expr, tokens) = self.parse_expr(tokens)
  guard tokens
    is [{ kind: SemiColon, lineno: end_lineno, column: end_column }, ..] else {
    raise ParseError((tokens[0], "Expect ';'"))
  }
  let assign_stmt = AssignStmt::{
    lineno: left_value.lineno,
    column: left_value.column,
    end_lineno,
    end_column,
    left_value,
    op,
    expr,
  }
  (assign_stmt, tokens)
}

pub struct LeftValue {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  kind : LeftValueKind
} derive(Show, Eq)

pub enum LeftValueKind {
  Ident(String)
  ArrayAccess(LeftValue, Expr)
  FieldAccess(LeftValue, String)
} derive(Show, Eq)


///|
pub fn Context::parse_left_value(
  self : Self,
  tokens : ArrayView[Token],
) -> (LeftValue, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Lower(ident), lineno, column }, ..] else {
    raise ParseError((tokens[0], "Expect a lower ident"))
  }
  let left_value = LeftValue::{
    lineno,
    column,
    end_lineno: lineno,
    end_column: column,
    kind: LeftValueKind::Ident(ident),
  }
  if !(tokens is [{kind: Bracket('[') | Dot, ..}, ..]) {
    return (left_value, tokens[1:])
  }

  let mut left_value = left_value

  loop tokens[1:] {
    [{ kind: Bracket('['), .. }, ..tokens] => {
      let (index_expr, tokens) = self.parse_expr(tokens)
      guard tokens is [{ kind: Bracket(']'), lineno, column }, ..tokens] else {
        raise ParseError((tokens[0], "Expect ']'"))
      }
      left_value = LeftValue::{
        lineno: left_value.lineno,
        column: left_value.column,
        end_lineno: lineno,
        end_column: column,
        kind: LeftValueKind::ArrayAccess(left_value, index_expr),
      }
      continue tokens
    }
    [{ kind: Dot, .. }, { kind: Lower(field), lineno, column }, ..tokens] => {
      left_value = LeftValue::{
        lineno: left_value.lineno,
        column: left_value.column,
        end_lineno: lineno,
        end_column: column,
        kind: LeftValueKind::FieldAccess(left_value, field),
      }
      continue tokens
    }
    tokens => break (left_value, tokens)
  }
}

///|
pub struct WhileStmt {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  cond : Expr
  body : BlockExpr
} derive(Show, Eq)

///|
pub fn Context::parse_while_stmt(
  self : Self,
  tokens : ArrayView[Token],
) -> (WhileStmt, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(While), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_while_stmt")
    panic()
  }
  let (cond, tokens) = self.parse_expr(tokens)
  let (body, tokens) = self.parse_block_expr(tokens)
  let while_stmt = WhileStmt::{
    lineno,
    column,
    end_lineno: body.end_lineno,
    end_column: body.end_column,
    cond,
    body,
  }
  (while_stmt, tokens)
}

///|
pub struct ForStmt {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  inits : Array[(String, Expr)]
  cond : Expr?
  steps : Array[(String, AssignOp, Expr)]
  body : BlockExpr
} derive(Show, Eq)

///|
///
/// Ast - For Statement
pub fn Context::parse_for_stmt(
  self : Self,
  tokens : ArrayView[Token],
) -> (ForStmt, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(For), lineno, column }, .. tokens] else {
    println("Compiler ICE: Misuse parse_for_stmt")
    panic()
  }
  let inits : Array[(String, Expr)] = Array::new()
  let tokens = loop tokens {
    [{ kind: Lower(name), .. }, { kind: AssignOp(Assign), .. }, ..] as tokens => {
      let (expr, rest) = self.parse_expr(tokens[2:])
      inits.push((name, expr))
      continue rest
    }
    [{ kind: SemiColon, .. }, ..tokens] => break tokens
    tokens => raise ParseError((tokens[0], "Invalid init statement in for loop"))
  }
  let (cond, tokens) = if tokens is [{ kind: SemiColon, .. }, .. tokens] {
    (None, tokens[1:])
  } else {
    let (expr, tokens) = self.parse_expr(tokens)
    guard tokens is [{ kind: SemiColon, .. }, .. tokens] else {
      raise ParseError((tokens[0], "Expect ';'"))
    }
    (Some(expr), tokens[1:])
  }
  let steps: Array[(String, AssignOp, Expr)] = Array::new()
  let tokens = loop tokens {
    [{ kind: Lower(name), .. }, { kind: AssignOp(op), .. }, ..] as tokens => {
      let (expr, rest) = self.parse_expr(tokens[2:])
      steps.push((name, op, expr))
      continue rest
    }
    [{ kind: Bracket('{'), .. }, ..] as tokens => break tokens
    tokens => raise ParseError((tokens[0], "Invalid step statement in for loop"))
  }
  let (body, tokens) = self.parse_block_expr(tokens)
  let for_stmt = ForStmt::{
    lineno,
    column,
    end_lineno: body.end_lineno,
    end_column: body.end_column,
    inits,
    cond,
    steps,
    body,
  }
  (for_stmt, tokens)


}

///|
pub struct Pattern {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  kind : PatternKind
} derive(Show, Eq)

///|
pub enum PatternKind {
  Wildcard
  Ident(String)
  Tuple(Array[Pattern])
} derive(Show, Eq)

///|
pub fn Context::parse_pattern(
  self : Self,
  tokens : ArrayView[Token],
) -> (Pattern, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Wildcard, lineno, column }, ..tokens] => {
      let pattern = Pattern::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        kind: Wildcard,
      }
      (pattern, tokens)
    }
    [{ kind: Lower(ident), lineno, column }, ..tokens] => {
      let pattern = Pattern::{
        lineno,
        column,
        end_lineno: lineno,
        end_column: column,
        kind: Ident(ident),
      }
      (pattern, tokens)
    }
    [{ kind: Bracket('('), lineno, column }, ..tokens] => {
      let patterns : Array[Pattern] = Array::new()
      loop tokens {
        [{kind: Bracket(')'), ..}, ..] => {
          break 
        }
        [{kind: Lower(_) | Wildcard | Bracket('('), ..}, ..] as tokens=> {
          let (pat, rest) = self.parse_pattern(tokens)
          patterns.push(pat)
          continue rest
        }
        tokens => {
          raise ParseError((tokens[0], "InValid Pattern") )
        }
      }
      let kind = if patterns.length() == 0 {
        raise ParseError((tokens[0], "InValid Pattern"))
      } else if patterns.length() == 1 {
        raise ParseError((tokens[0], "InValid Pattern, must over 1 pattern for tuple"))
      } else {
        PatternKind::Tuple(patterns)
      }
      let pattern = Pattern::{
        lineno,
        column,
        end_lineno: tokens[0].lineno,
        end_column: tokens[0].column,
        kind,
      }
      (pattern, tokens)
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    _ => raise ParseError((tokens[0], "InValid Pattern"))
  }
}
