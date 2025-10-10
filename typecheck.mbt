///|
pub suberror TypeCheckError String derive(Show)

///|
pub fn Context::typecheck(self : Self) -> Unit raise TypeCheckError {
  let { top_lets, extern_functions, top_functions, .. } = self
  // 1. collect all function signatures
  let dup_container = Set::new()
  fn dup_check(name : String) -> Unit raise TypeCheckError {
    if dup_container.contains(name) {
      raise TypeCheckError("duplicate function name: \{name}")
    }
    dup_container.add(name)
  }

  for ext in extern_functions.values() {
    let { params, ret_ty, fname, .. } = ext
    let param_tys = params.map(p => p.ty.kind)
    let fty : TypeKind = Function(param_tys, ret_ty.kind)
    dup_check(fname)
    self.type_env.set(fname, fty)
  }

  // 2. collect all top-let 
  for top_let in top_lets.values() {
    let { name, ty, .. } = top_let
    dup_check(name)
    self.type_env.set(name, ty.kind)
  }

  // 3. collect all struct definitions TODO
  // 4. collect all enum definitions TODO

  // 5. collect all function definitions' signatures
  for func in top_functions.values() {
    let { param_list, ret_ty, fname, .. } = func
    let param_tys = param_list.map(p => p.ty.kind)
    let fty : TypeKind = Function(param_tys, ret_ty.kind)
    dup_check(fname)
    self.type_env.set(fname, fty)
  }

  // 6. typecheck all function bodies
  for func in top_functions.values() {
    self.typecheck_function(func)
  }
}

///|
pub fn Context::typecheck_function(
  self : Self,
  func : TopFunction,
) -> Unit raise TypeCheckError {
  self.current_func = Some(func)
  let { param_list, body, .. } = func
  self.push_env() // new scope for function body

  // add parameters to var_env
  // Note: parameter names should be unique
  let check_param_dup = Set::new()
  for param in param_list {
    let { name, ty, .. } = param
    if check_param_dup.contains(name) {
      raise TypeCheckError("duplicate parameter name: \{name}")
    }
    check_param_dup.add(name)
    self.set_env(name, ty.kind)
  }
  let ty = self.type_check_block(body)
  guard ty == func.ret_ty.kind else {
    raise TypeCheckError(
      "function return type mismatch: expected \{func.ret_ty.kind}, got \{ty}",
    )
  }
  self.pop_env()
}

///|
pub fn Context::type_check_block(
  self : Self,
  block : BlockExpr,
) -> TypeKind raise TypeCheckError {
  self.push_env() // new scope for block
  let mut last_ty : TypeKind = Unit
  for stmt in block.stmts {
    last_ty = self.type_check_stmt(stmt)
  }
  self.pop_env()
  return last_ty
}

///|
pub fn Context::type_check_stmt(
  self : Self,
  stmt : Stmt,
) -> TypeKind raise TypeCheckError {
  match stmt.kind {
    LetStmt(let_stmt) => {
      self.type_check_let_stmt(let_stmt)
      return Unit
    }
    LetMutStmt(let_mut_stmt) => {
      self.type_check_let_mut_stmt(let_mut_stmt)
      return Unit
    }
    AssignStmt(assign_stmt) => {
      self.type_check_assign_stmt(assign_stmt)
      return Unit
    }
    WhileStmt(while_stmt) => {
      self.type_check_while_stmt(while_stmt)
      return Unit
    }
    ForStmt(for_stmt) => {
      self.type_check_for_stmt(for_stmt)
      return Unit
    }
    ReturnStmt(ret_expr) =>
      match ret_expr {
        Some(e) => return self.type_check_return_stmt(e)
        None => return Unit
      }
    ExprStmt(expr) => return self.type_check_expr(expr)
  }
}

///|
pub fn Context::type_check_let_stmt(
  self : Self,
  let_stmt : LetStmt,
) -> Unit raise TypeCheckError {
  let { pattern, ty, expr, .. } = let_stmt
  let expr_ty = self.type_check_expr(expr)
  if ty is Some(expected_ty) && expr_ty != expected_ty.kind {
    raise TypeCheckError(
      "type mismatch in let statement: expected \{expected_ty.kind}, got \{expr_ty}",
    )
  } else {
    let ty = Type::{
      lineno: -1,
      column: -1,
      end_lineno: -1,
      end_column: -1,
      kind: expr_ty,
    }
    let_stmt.ty = Some(ty)
  }
  self.bind_pattern(pattern, expr_ty)
}

///|
pub fn Context::bind_pattern(
  self : Self,
  pattern : Pattern,
  ty : TypeKind,
) -> Unit raise TypeCheckError {
  match (pattern.kind, ty) {
    (Wildcard, _) => () // do nothing
    (Ident(name), ty) => self.set_env(name, ty)
    (Tuple(pats), Tuple(tys)) => {
      guard pats.length() == tys.length() else {
        raise TypeCheckError(
          "pattern and type length mismatch in tuple pattern",
        )
      }
      for i in 0..<pats.length() {
        self.bind_pattern(pats[i], tys[i])
      }
    }
    _ => raise TypeCheckError("Type mismatch in pattern binding")
  }
}

///|
pub fn Context::type_check_let_mut_stmt(
  self : Self,
  stmt : LetMutStmt,
) -> Unit raise TypeCheckError {
  let { name, ty, expr, .. } = stmt
  let expr_ty = self.type_check_expr(expr)
  if ty is Some(expected_ty) && expr_ty != expected_ty.kind {
    raise TypeCheckError(
      "type mismatch in let mut statement: expected \{expected_ty.kind}, got \{expr_ty}",
    )
  } else {
    let ty = Type::{
      lineno: -1,
      column: -1,
      end_lineno: -1,
      end_column: -1,
      kind: expr_ty,
    }
    stmt.ty = Some(ty)
  }
  self.set_env(name, expr_ty)
}

///|
pub fn Context::type_check_expr(
  self : Self,
  expr : Expr,
) -> TypeKind raise TypeCheckError {
  let ty = match expr.kind {
    ApplyExpr(apply_expr) => self.type_check_apply_expr(apply_expr)
    BlockExpr(block_expr) => self.type_check_block(block_expr)
    BinaryExpr(op, lhs, rhs) => {
      let lhs_ty = self.type_check_expr(lhs)
      let rhs_ty = self.type_check_expr(rhs)
      guard lhs_ty.equal(rhs_ty) else {
        raise TypeCheckError(
          "type mismatch in binary expression: lhs is \{lhs_ty}, rhs is \{rhs_ty}",
        )
      }
      match op.is_cmp() {
        true => TypeKind::Bool
        false => lhs_ty
      }
    }
    IfExpr(if_expr) => self.type_check_if_expr(if_expr)
  }
  expr.ty = Some(ty)
  ty
}

///|
pub fn Context::type_check_apply_expr(
  self : Self,
  apply_expr : ApplyExpr,
) -> TypeKind raise TypeCheckError {
  let { kind, .. } = apply_expr
  let ty = match kind {
    AtomExpr(a) => self.type_check_atom_expr(a)
    ArrayAccess(a, idx) => self.type_check_array_access_expr(a, idx)
    FieldAccess(obj, field) => self.type_check_field_access_expr(obj, field)
    TupleAccess(obj, idx) => self.type_check_tuple_access_expr(obj, idx)
    Call(fname, args) => self.type_check_func_call_expr(fname, args)
  }
  apply_expr.ty = Some(ty)
  ty
}

///|
pub fn Context::type_check_atom_expr(
  self : Self,
  atom : AtomExpr,
) -> TypeKind raise TypeCheckError {
  let ty = match atom.kind {
    Unit => TypeKind::Unit
    Int(_) => TypeKind::Int
    Int64(_) => TypeKind::Int64
    UInt(_) => TypeKind::UInt
    UInt64(_) => TypeKind::UInt64
    Float(_) => TypeKind::Float
    Double(_) => TypeKind::Double
    Bool(_) => TypeKind::Bool
    String(_) => TypeKind::String
    Ident(name) => {
      guard self.get_ident_type(name) is Some(ty) else {
        raise TypeCheckError("undefined variable: \{name}")
      }
      ty
    }
    Paren(expr) => self.type_check_expr(expr)
    Tuple(exprs) => {
      let elem_tys = exprs.map(e => self.type_check_expr(e))
      TypeKind::Tuple(elem_tys)
    }
    Array(exprs) => {
      guard exprs.length() > 0 else {
        raise TypeCheckError("Array at least has one element")
      }
      let first_ty = self.type_check_expr(exprs[0])
      for e in exprs[1:] {
        let e_ty = self.type_check_expr(e)
        guard e_ty == first_ty else {
          raise TypeCheckError(
            "type mismatch in array elements: expected \{first_ty}, got \{e_ty}",
          )
        }
      }
      TypeKind::Array(first_ty)
    }
    StructConstruct(name, fields) => {
      ignore(name)
      ignore(fields)
      ...
    }
  }
  atom.ty = Some(ty)
  ty
}

///|
pub fn Context::type_check_array_access_expr(
  self : Self,
  array : ApplyExpr,
  index : Expr,
) -> TypeKind raise TypeCheckError {
  let array_ty = self.type_check_apply_expr(array)
  guard array_ty is TypeKind::Array(elem_ty) else {
    raise TypeCheckError("type mismatch: expected array type, got \{array_ty}")
  }
  let index_ty = self.type_check_expr(index)
  guard index_ty is Int else {
    raise TypeCheckError("array index must be an integer type, got \{index_ty}")
  }
  elem_ty
}

// TODO: implement field access type checking when structs are supported

///|
pub fn Context::type_check_field_access_expr(
  self : Self,
  obj : ApplyExpr,
  field : String,
) -> TypeKind raise TypeCheckError {
  ignore(obj)
  ignore(field)
  ...
}

///|
pub fn Context::type_check_tuple_access_expr(
  self : Self,
  obj : ApplyExpr,
  index : Int,
) -> TypeKind raise TypeCheckError {
  let obj_ty = self.type_check_apply_expr(obj)
  guard obj_ty is TypeKind::Tuple(elem_tys) else {
    raise TypeCheckError("type mismatch: expected tuple type, got \{obj_ty}")
  }
  guard index >= 0 && index < elem_tys.length() else {
    raise TypeCheckError(
      "tuple index out of bounds: index \{index}, length \{elem_tys.length()}",
    )
  }
  elem_tys[index]
}

///|
pub fn Context::type_check_func_call_expr(
  self : Self,
  f : ApplyExpr,
  args : Array[Expr],
) -> TypeKind raise TypeCheckError {
  let f_ty = self.type_check_apply_expr(f)
  guard f_ty is TypeKind::Function(param_tys, ret_ty) else {
    raise TypeCheckError("type mismatch: expected function type, got \{f_ty}")
  }
  guard param_tys.length() == args.length() else {
    raise TypeCheckError(
      "argument length mismatch: expected \{param_tys.length()}, got \{args.length()}",
    )
  }
  for i in 0..<args.length() {
    let arg_ty = self.type_check_expr(args[i])
    guard arg_ty == param_tys[i] else {
      raise TypeCheckError(
        "argument type mismatch at position \{i}: expected \{param_tys[i]}, got \{arg_ty}",
      )
    }
  }
  ret_ty
}

///|
pub fn Context::type_check_if_expr(
  self : Self,
  if_expr : IfExpr,
) -> TypeKind raise TypeCheckError {
  let { cond, then_block, else_block, .. } = if_expr
  let cond_ty = self.type_check_expr(cond)
  guard cond_ty is Bool else {
    raise TypeCheckError("if condition must be of type Bool, got \{cond_ty}")
  }
  let then_ty = self.type_check_block(then_block)
  let ty = match else_block {
    Some(e) =>
      match e {
        Left(elif) => {
          let elif_ty = self.type_check_if_expr(elif)
          guard then_ty == elif_ty else {
            raise TypeCheckError(
              "type mismatch in if-else branches: then is \{then_ty}, else-if is \{elif_ty}",
            )
          }
          elif_ty
        }
        Right(else_blk) => {
          let else_blk_ty = self.type_check_block(else_blk)
          guard then_ty == else_blk_ty else {
            raise TypeCheckError(
              "type mismatch in if-else branches: then is \{then_ty}, else is \{else_blk_ty}",
            )
          }
          else_blk_ty
        }
      }
    None => TypeKind::Unit
  }
  if_expr.ty = Some(ty)
  ty
}

///|
pub fn Context::type_check_assign_stmt(
  self : Self,
  assign_stmt : AssignStmt,
) -> Unit raise TypeCheckError {
  let { left_value, expr, .. } = assign_stmt
  let left_ty = self.type_check_left_value(left_value)
  let expr_ty = self.type_check_expr(expr)
  guard left_ty == expr_ty else {
    raise TypeCheckError(
      "type mismatch in assignment: left is \{left_ty}, right is \{expr_ty}",
    )
  }
  ()
}

///|
pub fn Context::type_check_left_value(
  self : Self,
  lv : LeftValue,
) -> TypeKind raise TypeCheckError {
  let ty = match lv.kind {
    Ident(name) => {
      guard self.get_ident_type(name) is Some(ty) else {
        raise TypeCheckError("undefined variable in left value: \{name}")
      }
      ty
    }
    ArrayAccess(a, idx) => {
      let a_ty = self.type_check_left_value(a)
      guard a_ty is TypeKind::Array(elem_ty) else {
        raise TypeCheckError(
          "type mismatch in left value: expected array type, got \{a_ty}",
        )
      }
      let idx_ty = self.type_check_expr(idx)
      guard idx_ty is Int else {
        raise TypeCheckError(
          "array index must be an integer type, got \{idx_ty}",
        )
      }
      elem_ty
    }
    FieldAccess(obj, field) => {
      ignore(obj)
      ignore(field)
      ...
    }
  }
  lv.ty = Some(ty)
  ty
}

///|
pub fn Context::type_check_while_stmt(
  self : Self,
  while_stmt : WhileStmt,
) -> Unit raise TypeCheckError {
  let { cond, body, .. } = while_stmt
  let cond_ty = self.type_check_expr(cond)
  guard cond_ty is Bool else {
    raise TypeCheckError(
      "while loop condition must be of type Bool, got \{cond_ty}",
    )
  }
  let block_ty = self.type_check_block(body)
  guard block_ty is Unit else {
    raise TypeCheckError(
      "while loop body must be of type Unit, got \{block_ty}",
    )
  }
  ()
}

///|
pub fn Context::type_check_for_stmt(
  self : Self,
  for_stmt : ForStmt,
) -> Unit raise TypeCheckError {
  let { inits, cond, steps, body, .. } = for_stmt
  self.push_env() // new scope for for loop

  // type check inits
  for init_expr in inits {
    let (name, expr) = init_expr
    let expr_ty = self.type_check_expr(expr)
    self.set_env(name, expr_ty)
  }

  // type check cond
  if cond is Some(c) {
    let cond_ty = self.type_check_expr(c)
    guard cond_ty is Bool else {
      raise TypeCheckError(
        "for loop condition must be of type Bool, got \{cond_ty}",
      )
    }
  }
  // type check steps
  for step in steps {
    let (name, _, expr) = step
    guard self.get_ident_type(name) is Some(var_ty) else {
      raise TypeCheckError("undefined variable in for loop step: \{name}")
    }
    let expr_ty = self.type_check_expr(expr)
    guard var_ty == expr_ty else {
      raise TypeCheckError(
        "type mismatch in for loop step: variable \{name} is of type \{var_ty}, got \{expr_ty}",
      )
    }
  }

  // type check body
  let block_ty = self.type_check_block(body)
  guard block_ty is Unit else {
    raise TypeCheckError("for loop body must be of type Unit, got \{block_ty}")
  }

  // Out of scope
  self.pop_env()
  ()
}

///|
pub fn Context::type_check_return_stmt(
  self : Self,
  ret_expr : Expr,
) -> TypeKind raise TypeCheckError {
  let ret_ty = self.type_check_expr(ret_expr)
  guard self.current_func is Some(func) else {
    println("Compiler ICE: not set current function while met return statement")
    panic()
  }
  let expected_ty = func.ret_ty.kind
  guard ret_ty == expected_ty else {
    raise TypeCheckError(
      "return type mismatch: expected \{expected_ty}, got \{ret_ty}",
    )
  }
  ret_ty
}
