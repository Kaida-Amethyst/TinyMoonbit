///|
pub suberror TypeCheckError String derive(Show)

pub fn Context::typecheck_program(self: Self, prog: Program) -> Unit raise TypeCheckError {
  if false {
    raise TypeCheckError("not implemented")
  }

  // 1. collect all function signatures
  for ext in prog.extern_functions {
    let { params, ret_ty, fname, .. } = ext
    let param_tys = params.map(p => p.ty.kind)
    let fty : TypeKind = Function(param_tys, ret_ty.kind)
    self.type_env.set(fname, fty)
  }

  // 2. collect all top-let 
  for top_let in prog.top_lets {
    let { name, ty, .. } = top_let
    self.type_env.set(name, ty.kind)
  }

  // 3. collect all struct definitions TODO
  // 4. collect all enum definitions TODO

  // 5. collect all function definitions' signatures
  for func in prog.top_functions {
    let { param_list, ret_ty, fname, .. } = func
    let param_tys = param_list.map(p => p.ty.kind)
    let fty : TypeKind = Function(param_tys, ret_ty.kind)
    self.type_env.set(fname, fty)
  }

  // 6. typecheck all function bodies
  for func in prog.top_functions {
    self.typecheck_function(func)
  }
}

pub fn Context::typecheck_function(self: Self, func: TopFunction) -> Unit raise TypeCheckError {
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

  self.pop_env()
}

pub fn Context::type_check_block(self: Self, block: BlockExpr) -> TypeKind raise TypeCheckError {
  self.push_env() // new scope for block
  let mut last_ty : TypeKind = Unit
  for stmt in block.stmts {
    last_ty = self.type_check_stmt(stmt)
  }
  self.pop_env()
  return last_ty
}

pub fn Context::type_check_stmt(self: Self, stmt: Stmt) -> TypeKind raise TypeCheckError {
  match stmt.kind {
    LetStmt(let_stmt) => {
      self.type_check_let_stmt(let_stmt)
      return Unit;
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
    ReturnStmt(ret_expr) => {
      match ret_expr {
        Some(e) => return self.type_check_return_stmt(e)
        None => return Unit
      }
    }
    ExprStmt(expr) => {
      return self.type_check_expr(expr)
    }
  }
}

pub fn Context::type_check_let_stmt(self: Self, let_stmt: LetStmt) -> Unit raise TypeCheckError {
  let { pattern, ty, expr, ..} = let_stmt
  let expr_ty = self.type_check_expr(expr)
  if ty is Some(expected_ty) && expr_ty != expected_ty.kind {
    raise TypeCheckError("type mismatch in let statement: expected \{expected_ty.kind}, got \{expr_ty}")
  } else {
    let ty = Type::{ lineno: -1, column: -1, end_lineno: -1, end_column: -1, kind: expr_ty}
    let_stmt.ty = Some(ty)
  }
  self.bind_pattern(pattern, expr_ty)
}

pub fn Context::bind_pattern(self: Self, pattern: Pattern, ty: TypeKind) -> Unit raise TypeCheckError {
  match (pattern.kind, ty) {
    (Wildcard, _) => () // do nothing
    (Ident(name), ty) => self.set_env(name, ty)
    (Tuple(pats), Tuple(tys)) => {
      guard pats.length() == tys.length() else {
        raise TypeCheckError("pattern and type length mismatch in tuple pattern")
      }
      for i in 0 ..<pats.length() {
        self.bind_pattern(pats[i], tys[i])
      }
    }
    _ => {
      raise TypeCheckError("Type mismatch in pattern binding")
    }
  }
}

pub fn Context::type_check_let_mut_stmt(self: Self, stmt: LetMutStmt) -> Unit raise TypeCheckError {
  let { name, ty, expr, .. } = stmt
  let expr_ty = self.type_check_expr(expr)
  if ty is Some(expected_ty) && expr_ty != expected_ty.kind {
    raise TypeCheckError("type mismatch in let mut statement: expected \{expected_ty.kind}, got \{expr_ty}")
  } else {
    let ty = Type::{ lineno: -1, column: -1, end_lineno: -1, end_column: -1, kind: expr_ty}
    stmt.ty = Some(ty)
  }
  self.set_env(name, expr_ty)
}

pub fn Context::type_check_expr(self: Self, expr: Expr) -> TypeKind raise TypeCheckError {
  let ty = match expr.kind {
    ApplyExpr(apply_expr) => self.type_check_apply_expr(apply_expr)
    BlockExpr(block_expr) => self.type_check_block(block_expr)
    BinaryExpr(op, lhs, rhs) => {
      let lhs_ty = self.type_check_expr(lhs)
      let rhs_ty = self.type_check_expr(rhs)
      guard lhs_ty.equal(rhs_ty) else {
        raise TypeCheckError("type mismatch in binary expression: lhs is \{lhs_ty}, rhs is \{rhs_ty}")
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

pub fn Context::type_check_apply_expr(self: Self, apply_expr: ApplyExpr) -> TypeKind raise TypeCheckError {
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

pub fn Context::type_check_atom_expr(self: Self, atom: AtomExpr) -> TypeKind raise TypeCheckError {
  ...
  //match atom.kind {
  //  Int(_) => TypeKind::Int
  //  Int64(_) => TypeKind::Int64
  //  UInt(_) => TypeKind::UInt
  //  UInt64(_) => TypeKind::UInt64
  //  Float(_) => TypeKind::Float
  //  Double(_) => TypeKind::Double
  //  Bool(_) => TypeKind::Bool
  //  String(_) => TypeKind::String
  //  Ident(name) => {
  //    guard self.get_ident_type(name) is Some(ty) else {
  //      raise TypeCheckError("undefined variable: \{name}")
  //    }
  //    ty
  //  }
  //  Parent(expr) => self.type_check_expr(expr)
  //  Tuple(exprs) => {
  //    let elem_tys = exprs.map(e => self.type_check_expr(e))
  //    TypeKind::Tuple(elem_tys)
  //  }
  //}
}

pub fn Context::type_check_array_access_expr(self: Self, array: ApplyExpr, index: Expr) -> TypeKind raise TypeCheckError {
  ...
}

pub fn Context::type_check_field_access_expr(self: Self, obj: ApplyExpr, field: String) -> TypeKind raise TypeCheckError {
  ...
}

pub fn Context::type_check_tuple_access_expr(self: Self, obj: ApplyExpr, index: Int) -> TypeKind raise TypeCheckError {
  ...
}

pub fn Context::type_check_func_call_expr(self: Self, f: ApplyExpr, args: Array[Expr]) -> TypeKind raise TypeCheckError {
  ...
}

pub fn Context::type_check_if_expr(self: Self, if_expr: IfExpr) -> TypeKind raise TypeCheckError {
  ...
}

pub fn Context::type_check_assign_stmt(self: Self, assign_stmt: AssignStmt) -> Unit raise TypeCheckError {
  ...
}

pub fn Context::type_check_while_stmt(self: Self, while_stmt: WhileStmt) -> Unit raise TypeCheckError {
  ...
}

pub fn Context::type_check_for_stmt(self: Self, for_stmt: ForStmt) -> Unit raise TypeCheckError {
  ...
}

pub fn Context::type_check_return_stmt(self: Self, ret_expr: Expr) -> TypeKind raise TypeCheckError {
  ...
}
