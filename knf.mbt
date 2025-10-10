///|
pub(all) struct Name {
  id : String
  slot : Int
}

///|
pub fn Context::new_name(self : Self, n : String) -> Name {
  match self.name_env.get(n) {
    Some({ id, slot }) => {
      let name = Name::{ id, slot: slot + 1 }
      self.name_env.set(n, name)
      name
    }
    None => {
      let name = Name::{ id: n, slot: 0 }
      self.name_env.set(n, name)
      name
    }
  }
}

///|
pub fn Context::get_knf_name(self : Self, n : String) -> Name {
  match self.name_env.get(n) {
    Some(name) => name
    None => {
      println("Compiler ICE: Name \{n} not found in name environment.")
      panic()
    }
  }
}

///|
pub impl Show for Name with output(self, logger) {
  if self.slot == 0 {
    logger.write_string(self.id)
    return
  }
  logger.write_string("\{self.id}$\{self.slot}")
}

///|
pub(all) struct KnfTopLet {
  name : Name
  ty : TypeKind
  expr : KnfExpr
}

///|
pub(all) struct KnfStructDef {
  name : String
  fields : Array[(String, TypeKind)]
}

///|
pub(all) struct KnfExternFunc {
  name : String
  ty : TypeKind
  params : Array[TypeKind]
}

///|
pub(all) struct KnfFunction {
  name : String
  ty : TypeKind
  params : Array[(Name, TypeKind)]
  body : KnfBlock
}

///|
pub fn Context::top_function_to_knf(
  self : Self,
  func : TopFunction,
) -> KnfFunction {
  self.push_name_env()
  // Convert parameters
  let params : Array[(Name, TypeKind)] = Array::new()
  for param in func.param_list {
    let { name, ty, .. } = param
    let name = self.new_name(name)
    params.push((name, ty.kind))
  }
  let ty = func.ret_ty.kind
  let body = self.block_to_knf(func.body)
  self.pop_name_env()
  KnfFunction::{ name: func.fname, ty, params, body }
}

///|
pub fn KnfFunction::stringify(self : KnfFunction) -> String {
  let sb = StringBuilder::new()
  let { name, ty, params, body } = self
  sb.write_string("fn \{name}(")
  let params_str = params
    .map(pair => {
      let (n, t) = pair
      "\{n.id}: \{t}"
    })
    .join(", ")
  sb.write_string(params_str)
  sb.write_string(") -> \{ty} ")
  sb.write_string(body.stringify(ident=2))
  sb.to_string()
}

///|
pub impl Show for KnfFunction with output(self, logger) {
  logger.write_string(self.stringify())
}

///|
pub(all) struct KnfBlock {
  stmts : Array[KnfStmt]
  final_expr : KnfExpr
}

///|
pub fn Context::block_to_knf(self : Self, block : BlockExpr) -> KnfBlock {
  let stmts : Array[KnfStmt] = Array::new()
  for stmt in block.stmts {
    let knf_stmt = self.stmt_to_knf(stmt)
    stmts.append(knf_stmt)
  }
  let last_stmt = stmts.last()
  let final_expr = match last_stmt {
    None => KnfExpr::Unit
    Some(ExprStmt(expr)) => {
      let _ = stmts.pop() // Remove the last ExprStmt
      expr
    }
    _ => KnfExpr::Unit
  }
  KnfBlock::{ stmts, final_expr }
}

///|
pub fn KnfBlock::stringify(self : KnfBlock, ident~ : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\n")
  let indent_str = " ".repeat(ident)
  for stmt in self.stmts {
    sb.write_string(indent_str)
    sb.write_string(stmt.stringify(ident~))
    sb.write_string("\n")
  }
  sb.write_string(" ".repeat(ident))
  sb.write_string(self.final_expr.stringify())
  sb.write_string("\n")
  sb.write_string(" ".repeat(ident - 2))
  sb.write_string("}")
  sb.to_string()
}

///|
pub(all) enum KnfStmt {
  Let(Name, TypeKind, KnfExpr)
  LetMut(Name, TypeKind, KnfExpr)
  Assign(Name, Name)
  ArrayPut(Name, Name, KnfExpr)
  StructSet(Name, String, KnfExpr)
  If(KnfExpr, KnfBlock, KnfBlock)
  While(KnfExpr, KnfBlock)
  ExprStmt(KnfExpr)
  Return(KnfExpr)
  ReturnVoid
}

///|
pub fn Context::stmt_to_knf(self : Self, stmt : Stmt) -> Array[KnfStmt] {
  match stmt.kind {
    LetStmt(let_stmt) => self.let_stmt_to_knf(let_stmt)
    LetMutStmt({ name, ty, expr, .. }) => {
      let name = self.new_name(name)
      let (stmts, expr) = self.expr_to_knf(expr)
      guard ty is Some(ty) else {
        println(
          "Compiler ICE: Let Mut Stmt must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      [..stmts, KnfStmt::LetMut(name, ty.kind, expr)]
    }
    AssignStmt(assign_stmt) => self.assign_stmt_to_knf(assign_stmt)
    WhileStmt(while_stmt) => self.while_stmt_to_knf(while_stmt)
    ForStmt(for_stmt) => self.for_stmt_to_knf(for_stmt)
    ReturnStmt(Some(ret_expr)) => {
      let (stmts, expr) = self.expr_to_knf(ret_expr)
      [..stmts, KnfStmt::Return(expr)]
    }
    ReturnStmt(None) => [KnfStmt::ReturnVoid]
    ExprStmt(expr) => {
      let (stmts, expr) = self.expr_to_knf(expr)
      [..stmts, KnfStmt::ExprStmt(expr)]
    }
  }
}

///|
///
/// Convert Let Stmt to KnfStmt
///
/// ```mbt
/// let code = 
///   #|fn foo() -> Int {
///   #|  let (a, b, c) = (1, true, "hello")
///   #|  a
///   #|}
///
/// let ctx = Context::new(code)
/// ctx..tokenize()..parse()..typecheck()
/// let f = ctx.top_functions.get("foo").unwrap()
/// let knf_func = ctx.top_function_to_knf(f)
///
/// let expected = 
///   #|fn foo() -> Int {
///   #|  let a: Int = 1;
///   #|  let b: Bool = true;
///   #|  let c: String = "hello";
///   #|  a
///   #|}
///
/// inspect(knf_func, content=expected)
/// ```
pub fn Context::let_stmt_to_knf(
  self : Self,
  let_stmt : LetStmt,
) -> Array[KnfStmt] {
  let { pattern, ty, expr, .. } = let_stmt
  guard ty is Some(ty) else {
    println(
      "Compiler ICE: Let Stmt must have been inferred type in Type Checking phase.",
    )
    panic()
  }
  if pattern.kind is Tuple(pats) &&
    ty.kind is Tuple(tys) &&
    expr.kind is ApplyExpr(apply_expr) &&
    apply_expr.kind is AtomExpr(atom_expr) &&
    atom_expr.kind is Tuple(element_exprs) {
    return self.simple_let_tuple_to_knf(pats, tys, element_exprs)
  }
  let (stmts, expr) = self.expr_to_knf(expr)
  match (pattern.kind, ty.kind, expr) {
    (Wildcard, _, expr) =>
      // let _ = expr;
      [..stmts, KnfStmt::ExprStmt(expr)]
    (Ident(name), ty, expr) => {
      let name = self.new_name(name)
      [..stmts, KnfStmt::Let(name, ty, expr)]
    }
    (Tuple(pats), Tuple(tys), TupleLiteral(tup)) => {
      guard pats.length() == tys.length() && pats.length() == tup.length() else {
        println(
          "Compiler ICE: Pattern, type, and expression length mismatch in tuple pattern.",
        )
        panic()
      }
      let all_stmts : Array[KnfStmt] = stmts
      for i in 0..<pats.length() {
        let pat = pats[i]
        let ty = tys[i]
        let n = tup[i]
        let bind_stmts = self.bind_pat_and_name_to_knf(pat, ty, n)
        all_stmts.append(bind_stmts)
      }
      all_stmts
    }
    (Tuple(pats), Tuple(tys), expr) => {
      let all_stmts : Array[KnfStmt] = stmts
      let n = self.new_name("tmp")
      all_stmts.push(KnfStmt::Let(n, ty.kind, expr))
      for i in 0..<pats.length() {
        let pat = pats[i]
        let ty = tys[i]
        let n = self.new_name("tmp")
        all_stmts.push(KnfStmt::Let(n, ty, KnfExpr::TupleGet(n, i)))
        let bind_stmts = self.bind_pat_and_name_to_knf(pat, ty, n)
        all_stmts.append(bind_stmts)
      }
      all_stmts
    }
    _ => {
      println("Compiler ICE: Unsupported pattern in let statement.")
      panic()
    }
  }
}

///|
pub fn Context::simple_let_tuple_to_knf(
  self : Context,
  pats : Array[Pattern],
  tys : Array[TypeKind],
  expr : Array[Expr],
) -> Array[KnfStmt] {
  let stmts : Array[KnfStmt] = Array::new()
  guard pats.length() == tys.length() && pats.length() == expr.length() else {
    println(
      "Compiler ICE: Pattern, type, and expression length mismatch in simple let tuple.",
    )
    panic()
  }
  for i in 0..<pats.length() {
    let pat = pats[i]
    let ty = tys[i]
    let e = expr[i]
    let (expr_stmts, expr_knf) = self.expr_to_knf(e)
    stmts.append(expr_stmts)
    let bind_stmts = self.bind_pat_and_expr_to_knf(pat, ty, expr_knf)
    stmts.append(bind_stmts)
  }
  stmts
}

///|
pub fn Context::bind_pat_and_name_to_knf(
  self : Self,
  pat : Pattern,
  ty : TypeKind,
  name : Name,
) -> Array[KnfStmt] {
  let stmts : Array[KnfStmt] = Array::new()
  match pat.kind {
    Wildcard => () // Do nothing
    Ident(pat_name) => {
      let pat_name = self.new_name(pat_name)
      let s = KnfStmt::Let(pat_name, ty, KnfExpr::Ident(name))
      stmts.push(s)
    }
    Tuple(pats) => {
      guard ty is Tuple(tys) else {
        println("Compiler ICE: Type must be a tuple type for tuple pattern.")
        panic()
      }
      guard pats.length() == tys.length() else {
        println(
          "Compiler ICE: Pattern and type length mismatch in tuple pattern.",
        )
        panic()
      }
      for i in 0..<pats.length() {
        let pat = pats[i]
        let ty = tys[i]
        let field_name = self.new_name("tmp")
        let get_expr = KnfExpr::TupleGet(name, i)
        let get_stmt = KnfStmt::Let(field_name, ty, get_expr)
        stmts.push(get_stmt)
        let nested_stmts = self.bind_pat_and_name_to_knf(pat, ty, field_name)
        stmts.append(nested_stmts)
      }
    }
  }
  stmts
}

///|
pub fn Context::bind_pat_and_expr_to_knf(
  self : Self,
  pat : Pattern,
  ty : TypeKind,
  expr : KnfExpr,
) -> Array[KnfStmt] {
  let stmts : Array[KnfStmt] = Array::new()
  match pat.kind {
    Wildcard => {
      // let _ = expr;
      stmts.push(KnfStmt::ExprStmt(expr))
      stmts
    }
    Ident(pat_name) => {
      let pat_name = self.new_name(pat_name)
      let s = KnfStmt::Let(pat_name, ty, expr)
      stmts.push(s)
      stmts
    }
    Tuple(pats) => {
      guard ty is Tuple(tys) else {
        println("Compiler ICE: Type must be a tuple type for tuple pattern.")
        panic()
      }
      guard pats.length() == tys.length() else {
        println(
          "Compiler ICE: Pattern and type length mismatch in tuple pattern.",
        )
        panic()
      }
      let temp_name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(temp_name, ty, expr))
      for i in 0..<pats.length() {
        let pat = pats[i]
        let ty = tys[i]
        let field_name = self.new_name("tmp")
        let get_expr = KnfExpr::TupleGet(temp_name, i)
        let get_stmt = KnfStmt::Let(field_name, ty, get_expr)
        stmts.push(get_stmt)
        let nested_stmts = self.bind_pat_and_name_to_knf(pat, ty, field_name)
        stmts.append(nested_stmts)
      }
      stmts
    }
  }
}

///|
///
/// Convert Assign Stmt to KnfStmt
///
/// ```mbt
/// let code = 
///   #|fn foo() -> Int {
///   #|  let mut a = 1
///   #|  a += 2 + 3
///   #|  a
///   #|}
///
/// let ctx = Context::new(code)
/// ctx..tokenize()..parse()..typecheck()
/// let f = ctx.top_functions.get("foo").unwrap()
/// let knf_func = ctx.top_function_to_knf(f)
///
/// let expected = 
///   #|fn foo() -> Int {
///   #|  let mut a: Int = 1;
///   #|  let tmp: Int = 2;
///   #|  let tmp$1: Int = 3;
///   #|  let tmp$2: Int = tmp + tmp$1;
///   #|  let tmp$3: Int = a + tmp$2;
///   #|  a = tmp$3;
///   #|  a
///   #|}
///
/// inspect(knf_func, content=expected)
/// ```
pub fn Context::assign_stmt_to_knf(
  self : Self,
  assign_stmt : AssignStmt,
) -> Array[KnfStmt] {
  let stmts : Array[KnfStmt] = Array::new()
  let { left_value, op, expr, .. } = assign_stmt
  let (expr_stmts, expr_knf) = self.expr_to_knf(expr)
  stmts.append(expr_stmts)
  let expr_name = match expr_knf {
    Ident(name) => name
    _ => {
      guard expr.ty is Some(ty) else {
        println(
          "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, ty, expr_knf))
      name
    }
  }
  guard expr.ty is Some(ty) else {
    println(
      "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
    )
    panic()
  }
  match left_value.kind {
    Ident(id) => {
      let name = self.get_knf_name(id)
      match op {
        Assign => stmts.push(KnfStmt::Assign(name, expr_name))
        PlusAssign => {
          let bin_expr = KnfExpr::Binary(Add, name, expr_name)
          let tmp_name = self.new_name("tmp")
          let plus_stmt = KnfStmt::Let(tmp_name, ty, bin_expr)
          stmts.push(plus_stmt)
          stmts.push(KnfStmt::Assign(name, tmp_name))
        }
        MinusAssign => {
          let bin_expr = KnfExpr::Binary(Sub, name, expr_name)
          let tmp_name = self.new_name("tmp")
          let minus_stmt = KnfStmt::Let(tmp_name, ty, bin_expr)
          stmts.push(minus_stmt)
          stmts.push(KnfStmt::Assign(name, tmp_name))
        }
        MultAssign => {
          let bin_expr = KnfExpr::Binary(Mul, name, expr_name)
          let tmp_name = self.new_name("tmp")
          let mult_stmt = KnfStmt::Let(tmp_name, ty, bin_expr)
          stmts.push(mult_stmt)
          stmts.push(KnfStmt::Assign(name, tmp_name))
        }
        DivAssign => {
          let bin_expr = KnfExpr::Binary(Div, name, expr_name)
          let tmp_name = self.new_name("tmp")
          let div_stmt = KnfStmt::Let(tmp_name, ty, bin_expr)
          stmts.push(div_stmt)
          stmts.push(KnfStmt::Assign(name, tmp_name))
        }
        ModAssign => {
          let bin_expr = KnfExpr::Binary(Mod, name, expr_name)
          let tmp_name = self.new_name("tmp")
          let mod_stmt = KnfStmt::Let(tmp_name, ty, bin_expr)
          stmts.push(mod_stmt)
          stmts.push(KnfStmt::Assign(name, tmp_name))
        }
      }
    }
    ArrayAccess(_) => abort("Unimplemented yet")
    FieldAccess(_) => abort("Unimplemented yet")
  }
  stmts
}

///|
pub fn Context::left_value_to_knf(
  self : Self,
  left_value : LeftValue,
) -> (Array[KnfStmt], Name) {
  ...
}

///|
pub fn Context::while_stmt_to_knf(
  self : Self,
  while_stmt : WhileStmt,
) -> Array[KnfStmt] {
  ...
}

///|
pub fn Context::for_stmt_to_knf(
  self : Self,
  for_stmt : ForStmt,
) -> Array[KnfStmt] {
  ...
}

///|
pub fn KnfStmt::stringify(self : KnfStmt, ident~ : Int) -> String {
  let sb = StringBuilder::new()
  match self {
    KnfStmt::Let(name, ty, expr) =>
      sb.write_string("let \{name}: \{ty} = \{expr.stringify()};")
    KnfStmt::LetMut(name, ty, expr) =>
      sb.write_string("let mut \{name}: \{ty} = \{expr.stringify()};")
    KnfStmt::Assign(name, expr) => sb.write_string("\{name.id} = \{expr};")
    KnfStmt::ArrayPut(array_name, index_name, expr) =>
      sb.write_string(
        "\{array_name.id}[\{index_name.id}] = \{expr.stringify()};",
      )
    KnfStmt::StructSet(struct_name, field_name, expr) =>
      sb.write_string("\{struct_name.id}.\{field_name} = \{expr.stringify()};")
    KnfStmt::If(cond, then_block, else_block) => {
      sb.write_string("if \{cond.stringify()} ")
      sb.write_string(then_block.stringify(ident=ident + 2))
      if else_block.stmts.length() > 0 {
        sb.write_string(" else ")
        sb.write_string(else_block.stringify(ident=ident + 2))
      }
    }
    KnfStmt::While(cond, body) => {
      sb.write_string("while \{cond.stringify()} ")
      sb.write_string(body.stringify(ident=ident + 2))
    }
    KnfStmt::ExprStmt(expr) => sb.write_string("\{expr.stringify()};")
    KnfStmt::Return(expr) => sb.write_string("return \{expr.stringify()};")
    KnfStmt::ReturnVoid => sb.write_string("return;")
    KnfStmt::StructSet(struct_name, field_name, expr) =>
      sb.write_string("\{struct_name}.\{field_name} = \{expr.stringify()};")
  }
  sb.to_string()
}

///|
pub impl Show for KnfStmt with output(self, logger) {
  logger.write_string(self.stringify(ident=0))
}

///|
pub(all) enum KnfExpr {
  Unit
  Int(Int)
  UInt(UInt)
  Int64(Int64)
  UInt64(UInt64)
  Float(Float)
  Double(Double)
  Bool(Bool)
  String(String)
  Ident(Name)
  Binary(BinaryOp, Name, Name)
  If(Name, KnfBlock, KnfBlock) // condition, then, else
  Not(Name)
  Neg(Name)
  Call(Name, Array[Name])
  ArrayGet(Name, Name)
  TupleGet(Name, Int)
  CreateStruct(String)
  ArrayLiteral(Array[Name])
  TupleLiteral(Array[Name])
}

///|
pub fn Context::expr_to_knf(
  self : Self,
  expr : Expr,
) -> (Array[KnfStmt], KnfExpr) {
  match expr.kind {
    ApplyExpr(apply_expr) => self.apply_expr_to_knf(apply_expr)
    BlockExpr(block_expr) => {
      let { stmts, final_expr } = self.block_to_knf(block_expr)
      (stmts, final_expr)
    }
    BinaryExpr(op, lhs, rhs) => {
      guard expr.ty is Some(ty) else {
        println(
          "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      self.binary_expr_to_knf(op, lhs, rhs, ty)
    }
    IfExpr(if_expr) => self.if_expr_to_knf(if_expr)
  }
}

///|
pub fn Context::binary_expr_to_knf(
  self : Self,
  op : BinaryOp,
  lhs : Expr,
  rhs : Expr,
  ty : TypeKind,
) -> (Array[KnfStmt], KnfExpr) {
  let (lhs_stmts, lhs_knf_expr) = self.expr_to_knf(lhs)
  let (rhs_stmts, rhs_knf_expr) = self.expr_to_knf(rhs)
  let stmts = Array::new()
  stmts..append(lhs_stmts)..append(rhs_stmts)
  let lhs_name = match lhs_knf_expr {
    Ident(name) => name
    _ => {
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, ty, lhs_knf_expr))
      name
    }
  }
  let rhs_name = match rhs_knf_expr {
    Ident(name) => name
    _ => {
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, ty, rhs_knf_expr))
      name
    }
  }
  let result_expr = KnfExpr::Binary(op, lhs_name, rhs_name)
  (stmts, result_expr)
}

///|
pub fn Context::apply_expr_to_knf(
  self : Self,
  apply_expr : ApplyExpr,
) -> (Array[KnfStmt], KnfExpr) {
  match apply_expr.kind {
    AtomExpr(atom_expr) => self.atom_expr_to_knf(atom_expr)
    ArrayAccess(array_expr, index_expr) =>
      self.array_access_to_knf(array_expr, index_expr)
    FieldAccess(struct_expr, field_name) =>
      self.field_access_to_knf(struct_expr, field_name)
    TupleAccess(tuple_expr, idx) => self.tuple_access_to_knf(tuple_expr, idx)
    Call(func_expr, arg_exprs) => self.call_expr_to_knf(func_expr, arg_exprs)
  }
}

///|
pub fn Context::array_access_to_knf(
  self : Self,
  array_expr : ApplyExpr,
  index_expr : Expr,
) -> (Array[KnfStmt], KnfExpr) {
  let (array_stmts, array_knf) = self.apply_expr_to_knf(array_expr)
  let (index_stmts, index_knf) = self.expr_to_knf(index_expr)
  let stmts = Array::new()
  stmts..append(array_stmts)..append(index_stmts)
  let array_name = match array_knf {
    Ident(name) => name
    _ => {
      guard array_expr.ty is Some(ty) else {
        println(
          "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, ty, array_knf))
      name
    }
  }
  let index_name = match index_knf {
    Ident(name) => name
    _ => {
      guard index_expr.ty is Some(ty) else {
        println(
          "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, ty, index_knf))
      name
    }
  }
  let result_expr = KnfExpr::ArrayGet(array_name, index_name)
  (stmts, result_expr)
}

///|
pub fn Context::field_access_to_knf(
  self : Self,
  struct_expr : ApplyExpr,
  field_name : String,
) -> (Array[KnfStmt], KnfExpr) {
  ...
}

///|
pub fn Context::tuple_access_to_knf(
  self : Self,
  tuple_expr : ApplyExpr,
  idx : Int,
) -> (Array[KnfStmt], KnfExpr) {
  let (tuple_stmts, tuple_knf) = self.apply_expr_to_knf(tuple_expr)
  let stmts = Array::new()
  stmts..append(tuple_stmts)
  let tuple_name = match tuple_knf {
    Ident(name) => name
    _ => {
      guard tuple_expr.ty is Some(ty) else {
        println(
          "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, ty, tuple_knf))
      name
    }
  }
  let result_expr = KnfExpr::TupleGet(tuple_name, idx)
  (stmts, result_expr)
}

///|
///
/// Convert Call Expr to KnfExpr
///
/// ```mbt
/// let code = 
///   #|extern fn add(a: Int, b: Int) -> Int = "add";
///   #|
///   #|fn foo() -> Int {
///   #|  let a = add(1, 2)
///   #|  a
///   #|}
///
/// let ctx = Context::new(code)
/// ctx..tokenize()..parse()..typecheck()
/// let _ = ctx.new_name("add") // extern function
/// let f = ctx.top_functions.get("foo").unwrap()
/// let knf_func = ctx.top_function_to_knf(f)
///
/// let expected = 
///   #|fn foo() -> Int {
///   #|  let tmp: Int = 1;
///   #|  let tmp$1: Int = 2;
///   #|  let a: Int = add(tmp, tmp$1);
///   #|  a
///   #|}
///
/// inspect(knf_func, content=expected)
/// ```
pub fn Context::call_expr_to_knf(
  self : Self,
  func_expr : ApplyExpr,
  arg_exprs : Array[Expr],
) -> (Array[KnfStmt], KnfExpr) {
  let (func_stmts, func_knf) = self.apply_expr_to_knf(func_expr)
  let (arg_stmts, arg_names) = self.multiple_exprs_to_knf(arg_exprs)
  let stmts = Array::new()
  stmts..append(func_stmts)..append(arg_stmts)
  let func_name = match func_knf {
    Ident(name) => name
    _ => {
      guard func_expr.ty is Some(ty) else {
        println(
          "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, ty, func_knf))
      name
    }
  }
  let result_expr = KnfExpr::Call(func_name, arg_names)
  (stmts, result_expr)
}

///|
///
/// Convert AtomExpr to KnfExpr
///
/// ```mbt
/// let code = 
///   #|fn foo() -> Int {
///   #|  let b = 1
///   #|  let a = true
///   #|  let mut a = "hello"
///   #|  let a = 3.14
///   #|  let mut a = ()
///   #|  let a = b
///   #|  a
///   #|}
///
/// let ctx = Context::new(code)
/// ctx..tokenize()..parse()..typecheck()
///
/// let f = ctx.top_functions.get("foo").unwrap()
/// 
/// let knf_func = ctx.top_function_to_knf(f)
///
/// let expected = 
///   #|fn foo() -> Int {
///   #|  let b: Int = 1;
///   #|  let a: Bool = true;
///   #|  let mut a$1: String = "hello";
///   #|  let a$2: Double = 3.14;
///   #|  let mut a$3: Unit = ();
///   #|  let a$4: Int = b;
///   #|  a$4
///   #|}
///
/// inspect(knf_func, content=expected)
/// ```
pub fn Context::atom_expr_to_knf(
  self : Self,
  atom_expr : AtomExpr,
) -> (Array[KnfStmt], KnfExpr) {
  let stmts : Array[KnfStmt] = Array::new()
  let e = match atom_expr.kind {
    Unit => KnfExpr::Unit
    Int(v) => Int(v)
    UInt(v) => UInt(v)
    Int64(v) => Int64(v)
    UInt64(v) => UInt64(v)
    Float(v) => Float(v)
    Double(v) => Double(v)
    Bool(v) => Bool(v)
    String(v) => String(v)
    Ident(id) => {
      let name = self.get_knf_name(id)
      KnfExpr::Ident(name)
    }
    Paren(e) => {
      let (inner_stmts, inner_expr) = self.expr_to_knf(e)
      stmts.append(inner_stmts)
      inner_expr
    }
    Tuple(elements) => {
      let (element_stmts, element_names) = self.multiple_exprs_to_knf(elements)
      stmts.append(element_stmts)
      KnfExpr::TupleLiteral(element_names)
    }
    Array(elements) => {
      let (element_stmts, element_names) = self.multiple_exprs_to_knf(elements)
      stmts.append(element_stmts)
      KnfExpr::ArrayLiteral(element_names)
    }
    StructConstruct(_) => {
      println("Unimplemented yet")
      panic()
    }
  }
  (stmts, e)
}

///|
pub fn Context::multiple_exprs_to_knf(
  self : Self,
  exprs : Array[Expr],
) -> (Array[KnfStmt], Array[Name]) {
  let stmts : Array[KnfStmt] = Array::new()
  let names : Array[Name] = Array::new()
  for expr in exprs {
    let (expr_stmts, expr_knf) = self.expr_to_knf(expr)
    stmts.append(expr_stmts)
    let name = match expr_knf {
      Ident(name) => name
      _ => {
        guard expr.ty is Some(ty) else {
          println(
            "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
          )
          panic()
        }
        let name = self.new_name("tmp")
        stmts.push(KnfStmt::Let(name, ty, expr_knf))
        name
      }
    }
    names.push(name)
  }
  (stmts, names)
}

///|
pub fn Context::if_expr_to_knf(
  self : Self,
  if_expr : IfExpr,
) -> (Array[KnfStmt], KnfExpr) {
  ...
}

///|
pub fn KnfExpr::stringify(self : KnfExpr) -> String {
  match self {
    Unit => "()"
    Int(v) => v.to_string()
    UInt(v) => v.to_string()
    Int64(v) => v.to_string()
    UInt64(v) => v.to_string()
    Float(v) => v.to_string()
    Double(v) => v.to_string()
    Bool(v) => v.to_string()
    String(v) => "\"\{v}\""
    Ident(name) => name.to_string()
    Binary(op, left, right) => "\{left} \{op} \{right}"
    Not(name) => "!\{name}"
    Neg(name) => "-\{name}"
    Call(func_name, args) => {
      let args_str = args.map(arg => arg.to_string()).join(", ")
      "\{func_name}(\{args_str})"
    }
    ArrayGet(array_name, index_name) => "\{array_name}[\{index_name}]"
    TupleGet(tuple_name, index) => "\{tuple_name}.\{index}"
    ArrayLiteral(elements) => {
      let elements_str = elements.map(e => e.to_string()).join(", ")
      "[\{elements_str}]"
    }
    TupleLiteral(elements) => {
      let elements_str = elements.map(e => e.to_string()).join(", ")
      "(\{elements_str})"
    }
    If(cond_name, then_block, else_block) => {
      let sb = StringBuilder::new()
      sb.write_string("if \{cond_name} ")
      sb.write_string(then_block.stringify(ident=2))
      if else_block.stmts.length() > 0 {
        sb.write_string(" else ")
        sb.write_string(else_block.stringify(ident=2))
      }
      sb.to_string()
    }
    CreateStruct(struct_name) => "new \{struct_name}"
  }
}

///|
pub impl Show for KnfExpr with output(self, logger) {
  logger.write_string(self.stringify())
}
