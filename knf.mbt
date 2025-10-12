///|
pub(all) struct Name {
  id : String
  slot : Int
} derive(Hash, Eq)

///|
pub fn Name::new_wild_card() -> Name {
  Name::{ id: "_", slot: 0 }
}

///|
pub fn Name::is_wild_card(self : Name) -> Bool {
  self.id == "_"
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
pub fn Context::knf_transform(self : Self) -> Unit {
  // 1. collect all top let
  for top_name, top_let in self.top_lets {
    self.name_env.set(top_name, Name::{ id: top_name, slot: 0 })
    let _ = self.top_let_to_knf(top_let)

  }
  // 2. collect all extern func
  for ext_name, ext_func in self.extern_functions {
    self.name_env.set(ext_name, Name::{ id: ext_name, slot: 0 })
    let _ = self.top_extern_func_to_knf(ext_func)

  }
  // 3. collect all struct def and enum def TODO
  for struct_name, struct_def in self.struct_defs {
    self.name_env.set(struct_name, Name::{ id: struct_name, slot: 0 })
    let _ = self.top_struct_def_to_knf(struct_def)

  }
  // 4. convert all top function to knf function
  // Note: need add functions name first
  for fname, _ in self.top_functions {
    self.name_env.set(fname, Name::{ id: fname, slot: 0 })
  }
  for _, func in self.top_functions {
    let _ = self.top_function_to_knf(func)

  }
}

///|
pub(all) struct KnfTopLet {
  name : Name
  ty : TypeKind
  is_mut : Bool
  expr : KnfExpr
}

///|
pub fn Context::top_let_to_knf(self : Self, let_stmt : TopLet) -> KnfTopLet {
  let { name, is_mut, ty, expr, .. } = let_stmt
  guard expr.kind is ApplyExpr(apply_expr) &&
    apply_expr.kind is AtomExpr(atom_expr) else {
    println(
      "Compiler ICE: Top let expression Cannot support complex expression currently.",
    )
    panic()
  }
  let knf_expr = match atom_expr.kind {
    Int(i) => KnfExpr::Int(i)
    UInt(u) => KnfExpr::UInt(u)
    Int64(i) => KnfExpr::Int64(i)
    UInt64(u) => KnfExpr::UInt64(u)
    Float(f) => KnfExpr::Float(f)
    Double(d) => KnfExpr::Double(d)
    Bool(b) => KnfExpr::Bool(b)
    String(s) => KnfExpr::String(s)
    _ => {
      println(
        "Compiler ICE: Top let expression Cannot support complex expression currently.",
      )
      panic()
    }
  }
  let top_let_name = self.new_name(name)
  let knf_top_let = KnfTopLet::{
    name: top_let_name,
    ty: ty.kind,
    is_mut,
    expr: knf_expr,
  }
  self.knf_top_lets.set(name, knf_top_let)
  knf_top_let
}

///|
pub impl Show for KnfTopLet with output(self, logger) {
  logger.write_string("let ")
  if self.is_mut {
    logger.write_string("mut ")
  }
  logger.write_string("\{self.name}: \{self.ty} = \{self.expr.stringify()};")
}

///|
pub(all) struct KnfStructDef {
  name : String
  // field name, is_mut, field type
  fields : Array[(String, Bool, TypeKind)]
}

pub fn KnfStructDef::get_field_idx(self: Self, field_name: String) -> Int? {
  self.fields.search_by( f => f.0 == field_name )
}

///|
pub fn Context::top_struct_def_to_knf(
  self : Self,
  struct_def : StructDef,
) -> KnfStructDef {
  let fields : Array[(String, Bool, TypeKind)] = Array::new()
  for field in struct_def.fields {
    fields.push((field.name, field.is_mut, field.ty.kind))
  }
  let knf_struct = KnfStructDef::{ name: struct_def.name, fields }
  self.knf_struct_defs.set(struct_def.name, knf_struct)
  knf_struct
}

///|
pub fn KnfStructDef::stringify(self : KnfStructDef) -> String {
  let sb = StringBuilder::new()
  sb.write_string("struct \{self.name} {\n")
  for field in self.fields {
    let (field_name, is_mut, field_ty) = field
    sb.write_string("  ")
    if is_mut {
      sb.write_string("mut ")
    }
    sb.write_string("\{field_name}: \{field_ty}\n")
  }
  sb.write_string("}")
  sb.to_string()
}

pub impl Show for KnfStructDef with output(self, logger) {
  logger.write_string(self.stringify())
}

///|
pub(all) struct KnfExternFunc {
  name : String
  ty : TypeKind
  params : Array[TypeKind]
}

///|
pub impl Show for KnfExternFunc with output(self, logger) {
  let params_str = self.params.map(t => t.to_string()).join(", ")
  logger.write_string("extern fn \{self.name}(\{params_str}) -> \{self.ty};")
}

///|
pub fn Context::top_extern_func_to_knf(
  self : Self,
  func : ExternFunction,
) -> KnfExternFunc {
  let params : Array[TypeKind] = func.params.map(param => param.ty.kind)
  let ty = func.ret_ty.kind
  let knf_ext = KnfExternFunc::{ name: func.fname, ty, params }
  self.knf_ext_funcs.set(func.fname, knf_ext)
  knf_ext
}

///|
pub(all) struct KnfFunction {
  name : String
  ty : TypeKind
  params : Array[(Name, TypeKind)]
  body : KnfBlock
  name_value_map : Map[Name, &@IR.Value]
  name_type_map : Map[Name, TypeKind]
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
  let knf_func = KnfFunction::{
    name: func.fname,
    ty,
    params,
    body,
    name_value_map: Map::new(),
    name_type_map: Map::new(),
  }
  self.knf_top_funcs.set(func.fname, knf_func)
  knf_func
}

///|
pub fn KnfFunction::stringify(self : KnfFunction) -> String {
  let sb = StringBuilder::new()
  let { name, ty, params, body, .. } = self
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
  if !(self.final_expr is Unit) {
    sb.write_string(indent_str)
    sb.write_string(self.final_expr.stringify(ident~))
    sb.write_string("\n")
  }
  sb.write_string(" ".repeat(ident - 2))
  sb.write_string("}")
  sb.to_string()
}

///|
pub fn KnfBlock::nested_stringify(self : KnfBlock) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{")
  let indent_str = " "
  for stmt in self.stmts {
    sb.write_string(indent_str)
    sb.write_string(stmt.stringify(ident=0))
  }
  if !(self.final_expr is Unit) {
    sb.write_string(indent_str)
    sb.write_string(self.final_expr.stringify())
    sb.write_string(indent_str)
  }
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
  While(KnfBlock, KnfBlock)
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
    ExprStmt({ kind: IfExpr(if_expr), ..}) => {
      let (stmts, expr) = self.if_expr_to_knf(if_expr)
      guard if_expr.ty is Some(ty) else {
        println(
          "Compiler ICE: If Expr must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      let name = if ty is Unit {
        Name::new_wild_card()
      } else {
        self.new_name("tmp")
      }
      let let_if = KnfStmt::Let(name, ty, expr)
      if ty is Unit {
        [..stmts, let_if]
      } else {
        [..stmts, let_if, KnfStmt::ExprStmt(Ident(name))]
      }
    }
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
    // let _ = expr;
    (Wildcard, ty, expr) => {
      let wild_card = Name::new_wild_card()
      [..stmts, KnfStmt::Let(wild_card, ty, expr)]
    }
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
    ArrayAccess(left_value, idx_expr) => {
      let (left_value_stmts, left_value_knf_name) = self.left_value_to_knf(
        left_value,
      )
      stmts.append(left_value_stmts)
      let (idx_stmts, idx_knf) = self.expr_to_knf(idx_expr)
      stmts.append(idx_stmts)
      let tmp_idx_name = match idx_knf {
        Ident(name) => name
        _ => {
          guard idx_expr.ty is Some(ty) else {
            println(
              "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
            )
            panic()
          }
          let name = self.new_name("tmp")
          stmts.push(KnfStmt::Let(name, ty, idx_knf))
          name
        }
      }
      stmts.push(KnfStmt::Let(tmp_idx_name, ty, expr_knf))
      stmts.push(KnfStmt::ArrayPut(left_value_knf_name, tmp_idx_name, expr_knf))
    }
    FieldAccess(obj_left_value, field_name) => {
      let (obj_stmts, obj_knf_name) = self.left_value_to_knf(obj_left_value)
      stmts.append(obj_stmts)
      stmts.push(KnfStmt::StructSet(obj_knf_name, field_name, expr_knf))
    }
  }
  stmts
}

///|
pub fn Context::left_value_to_knf(
  self : Self,
  left_value : LeftValue,
) -> (Array[KnfStmt], Name) {
  match left_value.kind {
    Ident(id) => {
      let name = self.get_knf_name(id)
      (Array::new(), name)
    }
    ArrayAccess(arr_left_value, index_expr) =>
      self.array_access_left_value_to_knf(arr_left_value, index_expr)
    FieldAccess(inner_left, field_name) =>
      self.field_access_left_value_to_knf(inner_left, field_name)
  }
}

///|
pub fn Context::array_access_left_value_to_knf(
  self : Self,
  arr_left_value : LeftValue,
  index_expr : Expr,
) -> (Array[KnfStmt], Name) {
  let (arr_stmts, arr_knf_name) = self.left_value_to_knf(arr_left_value)
  let (index_stmts, index_knf) = self.expr_to_knf(index_expr)
  let stmts = Array::new()
  stmts..append(arr_stmts)..append(index_stmts)
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
  let result_name = self.new_name("tmp")
  guard arr_left_value.ty is Some(ty) else {
    println(
      "Compiler ICE: Left value must have been inferred type in Type Checking phase.",
    )
    panic()
  }
  guard ty is Array(elem_ty) else {
    println("Compiler ICE: Left value must be an array type.")
    panic()
  }
  stmts.push(
    KnfStmt::Let(
      result_name,
      elem_ty,
      KnfExpr::ArrayGet(arr_knf_name, index_name),
    ),
  )
  (stmts, result_name)
}

///|
pub fn Context::field_access_left_value_to_knf(
  self : Self,
  obj_left_value : LeftValue,
  field_name : String,
) -> (Array[KnfStmt], Name) {
  let (obj_stmts, obj_knf_name) = self.left_value_to_knf(obj_left_value)
  let stmts = Array::new()
  stmts..append(obj_stmts)
  let result_name = self.new_name("tmp")
  guard obj_left_value.ty is Some(ty) else {
    println(
      "Compiler ICE: Left value must have been inferred type in Type Checking phase.",
    )
    panic()
  }
  guard ty is Defined(struct_name, _) else {
    println("Compiler ICE: Left value must be a struct type.")
    panic()
  }
  guard self.struct_defs.get(struct_name) is Some(struct_def) else {
    println("Compiler ICE: Struct definition not found.")
    panic()
  }
  guard struct_def.fields.iter().any(f => f.name == field_name) else {
    println(
      "Compiler ICE: Field \{field_name} not found in struct \{struct_name}.",
    )
    panic()
  }
  guard struct_def.get_field(field_name) is Some(field) else {
    println(
      "Compiler ICE: Field \{field_name} not found in struct \{struct_name}.",
    )
    panic()
  }
  let field_ty = field.ty.kind
  let stmt = 
    KnfStmt::Let(
      result_name,
      field_ty,
      KnfExpr::StructGet(obj_knf_name, field_name),
    )

  stmts.push(stmt)
  (stmts, result_name)
}

///|
///
/// Convert While Stmt to KnfStmt
///
/// ```mbt
/// let code =
///   #|fn foo() -> Int {
///   #|  let mut i = 0
///   #|  while i < 10 {
///   #|    i += 1
///   #|  }
///   #|  i
///   #|}
/// let ctx = Context::new(code)
/// ctx..tokenize()..parse()..typecheck()
/// let f = ctx.top_functions.get("foo").unwrap()
/// let knf_func = ctx.top_function_to_knf(f)
/// let expected =
///   #|fn foo() -> Int {
///   #|  let mut i: Int = 0;
///   #|  while { let tmp: Int = 10; i < tmp } do {
///   #|    let tmp$1: Int = 1;
///   #|    let tmp$2: Int = i + tmp$1;
///   #|    i = tmp$2;
///   #|  }
///   #|  i
///   #|}
/// inspect(knf_func, content=expected)
/// ```
pub fn Context::while_stmt_to_knf(
  self : Self,
  while_stmt : WhileStmt,
) -> Array[KnfStmt] {
  let { cond, body, .. } = while_stmt
  let (cond_stmts, cond_knf) = self.expr_to_knf(cond)
  let cond_block = KnfBlock::{ stmts: cond_stmts, final_expr: cond_knf }
  let body_block = self.block_to_knf(body)
  [KnfStmt::While(cond_block, body_block)]
}

///|
///
/// Note - Completely AI generated.
pub fn Context::for_stmt_to_knf(
  self : Self,
  for_stmt : ForStmt,
) -> Array[KnfStmt] {
  let result_stmts : Array[KnfStmt] = Array::new()

  // Process init statements - convert to let mut declarations
  for init in for_stmt.inits {
    let (var_name, init_expr) = init
    let name = self.new_name(var_name)
    let (expr_stmts, expr_knf) = self.expr_to_knf(init_expr)
    result_stmts.append(expr_stmts)
    guard init_expr.ty is Some(ty) else {
      println(
        "Compiler ICE: Init expression must have been inferred type in Type Checking phase.",
      )
      panic()
    }
    result_stmts.push(KnfStmt::LetMut(name, ty, expr_knf))
  }

  // Build condition block
  let cond_block = match for_stmt.cond {
    Some(cond_expr) => {
      let (cond_stmts, cond_knf) = self.expr_to_knf(cond_expr)
      KnfBlock::{ stmts: cond_stmts, final_expr: cond_knf }
    }
    None =>
      // If no condition, use true
      KnfBlock::{ stmts: Array::new(), final_expr: KnfExpr::Bool(true) }
  }

  // Build body block with original body + step statements
  let body_stmts : Array[KnfStmt] = Array::new()

  // Add original body statements
  let original_body_block = self.block_to_knf(for_stmt.body)
  body_stmts.append(original_body_block.stmts)
  if !(original_body_block.final_expr is Unit) {
    body_stmts.push(KnfStmt::ExprStmt(original_body_block.final_expr))
  }

  // Add step statements
  for step in for_stmt.steps {
    let (var_name, assign_op, step_expr) = step
    let assign_stmt = AssignStmt::{
      lineno: 0,
      column: 0,
      end_lineno: 0,
      end_column: 0,
      left_value: LeftValue::{
        lineno: 0,
        column: 0,
        end_lineno: 0,
        end_column: 0,
        kind: LeftValueKind::Ident(var_name),
        ty: None,
      },
      op: assign_op,
      expr: step_expr,
    }
    let step_stmts = self.assign_stmt_to_knf(assign_stmt)
    body_stmts.append(step_stmts)
  }
  let body_block = KnfBlock::{ stmts: body_stmts, final_expr: KnfExpr::Unit }

  // Create while statement
  result_stmts.push(KnfStmt::While(cond_block, body_block))
  result_stmts
}

///|
pub fn KnfStmt::stringify(self : KnfStmt, ident? : Int = 0) -> String {
  let sb = StringBuilder::new()
  match self {
    KnfStmt::Let(name, ty, expr) =>
      sb.write_string("let \{name}: \{ty} = \{expr.stringify(ident~)};")
    KnfStmt::LetMut(name, ty, expr) =>
      sb.write_string("let mut \{name}: \{ty} = \{expr.stringify(ident~)};")
    KnfStmt::Assign(name, expr) => sb.write_string("\{name.id} = \{expr};")
    KnfStmt::ArrayPut(array_name, index_name, expr) =>
      sb.write_string(
        "\{array_name}[\{index_name}] = \{expr.stringify(ident~)};",
      )
    KnfStmt::StructSet(struct_name, field_name, expr) =>
      sb.write_string(
        "\{struct_name}.\{field_name} = \{expr.stringify(ident~)};",
      )
    KnfStmt::While(cond, body) => {
      if cond.stmts.length() < 2 {
        sb.write_string("while \{cond.nested_stringify()} do ")
      } else {
        let cond_str = cond.stringify(ident=ident + 2)
        sb.write_string("while \{cond_str} do ")
      }
      sb.write_string(body.stringify(ident=ident + 2))
    }
    KnfStmt::ExprStmt(expr) => sb.write_string("\{expr.stringify(ident~)};")
    KnfStmt::Return(expr) =>
      sb.write_string("return \{expr.stringify(ident~)};")
    KnfStmt::ReturnVoid => sb.write_string("return;")
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
  If(KnfExpr, KnfBlock, KnfBlock)
  Not(Name)
  Neg(Name)
  Cast(from~: TypeKind, to~:TypeKind, Name)
  BitCast(from~: TypeKind, to~:TypeKind, Name)
  Call(Name, Array[Name])
  ArrayGet(Name, Name)
  TupleGet(Name, Int)
  CreateStruct(String)
  StructGet(Name, String)
  TupleLiteral(Array[Name])
  ArrayAlloc(TypeKind, Int)
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
    BinaryExpr(op, lhs, rhs) => self.binary_expr_to_knf(op, lhs, rhs)
    IfExpr(if_expr) => self.if_expr_to_knf(if_expr)
    NotExpr(expr) => {
      let (stmts, knf_expr) = self.expr_to_knf(expr)
      guard expr.ty is Some(ty) else {
        println(
          "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      let name = match knf_expr {
        Ident(name) => name
        _ => {
          let name = self.new_name("tmp")
          let s = KnfStmt::Let(name, ty, knf_expr)
          stmts.push(s)
          name
        }
      }
      let result_expr = KnfExpr::Not(name)
      (stmts, result_expr)
    }
    NegExpr(expr) => {
      let (stmts, knf_expr) = self.expr_to_knf(expr)
      guard expr.ty is Some(ty) else {
        println(
          "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      let name = match knf_expr {
        Ident(name) => name
        _ => {
          let name = self.new_name("tmp")
          let s = KnfStmt::Let(name, ty, knf_expr)
          stmts.push(s)
          name
        }
      }
      let result_expr = KnfExpr::Neg(name)
      (stmts, result_expr)
    }
  }
}

///|
pub fn Context::binary_expr_to_knf(
  self : Self,
  op : BinaryOp,
  lhs : Expr,
  rhs : Expr,
) -> (Array[KnfStmt], KnfExpr) {
  let (lhs_stmts, lhs_knf_expr) = self.expr_to_knf(lhs)
  let (rhs_stmts, rhs_knf_expr) = self.expr_to_knf(rhs)
  guard lhs.ty is Some(lhs_ty) && rhs.ty is Some(rhs_ty) else {
    println(
      "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
    )
    panic()
  }
  let stmts = Array::new()
  stmts..append(lhs_stmts)..append(rhs_stmts)
  let lhs_name = match lhs_knf_expr {
    Ident(name) => name
    _ => {
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, lhs_ty, lhs_knf_expr))
      name
    }
  }
  let rhs_name = match rhs_knf_expr {
    Ident(name) => name
    _ => {
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, rhs_ty, rhs_knf_expr))
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
  let (struct_stmts, struct_knf) = self.apply_expr_to_knf(struct_expr)
  let stmts = Array::new()
  stmts..append(struct_stmts)
  guard struct_expr.ty is Some(ty) else {
    println(
      "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
    )
    panic()
  }
  guard ty is Defined(struct_name, _) else {
    return self.builtin_type_field_access_to_knf(struct_knf, ty, field_name)
  }
  guard self.struct_defs.get(struct_name) is Some(struct_def) else {
    println("Compiler ICE: Struct definition not found.")
    panic()
  }
  guard struct_def.get_field(field_name) is Some({ ty, .. }) else {
    println(
      "Compiler ICE: Field \{field_name} not found in struct \{struct_name}.",
    )
    panic()
  }
  let acc_name = match struct_knf {
    Ident(name) => name
    _ => {
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, ty.kind, struct_knf))
      name
    }
  }
  let acc_expr = KnfExpr::StructGet(acc_name, field_name)
  (stmts, acc_expr)
}

pub fn Context::builtin_type_field_access_to_knf(
  self : Self,
  expr_knf : KnfExpr,
  ty : TypeKind,
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
  // Need to check if func_expr is satisfied like `a.func`
  match func_expr.kind {
    FieldAccess(obj_expr, field_name) => {
      return self.method_call_expr_to_knf(obj_expr, field_name, arg_exprs)
    }
    _ => ()
  }
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

pub fn Context::method_call_expr_to_knf(
  self : Self,
  obj_expr : ApplyExpr,
  method_name : String,
  arg_exprs : Array[Expr],
) -> (Array[KnfStmt], KnfExpr) {
  let (master_stmts, master_knf) = self.apply_expr_to_knf(obj_expr)
  let (arg_stmts, arg_names) = self.multiple_exprs_to_knf(arg_exprs)
  ignore(arg_names) // currently unused, will be used in future
  let stmts = Array::new()
  stmts..append(master_stmts)..append(arg_stmts)
  let master_name = match master_knf {
    Ident(name) => name
    _ => {
      guard obj_expr.ty is Some(ty) else {
        println(
          "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
        )
        panic()
      }
      let name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(name, ty, master_knf))
      name
    }
  }
  guard obj_expr.ty is Some(ty) else {
    println(
      "Compiler ICE: Expression must have been inferred type in Type Checking phase.",
    )
    panic()
  }
  match (ty, method_name) {
    (Int, "to_int64") => (stmts, Cast(from=Int, to=Int64, master_name))
    (Int, "to_uint") => (stmts, BitCast(from=Int, to=UInt, master_name))
    (Int, "to_uint64") => (stmts, Cast(from=Int, to=UInt64, master_name))
    (Int, "to_float") => (stmts, Cast(from=Int, to=Float, master_name))
    (Int, "to_double") => (stmts, Cast(from=Int, to=Double, master_name))
    (Int, "reinterpret_as_float") => (stmts, BitCast(from=Int, to=Float, master_name))
    (Int, "reinterpret_as_double") => (stmts, BitCast(from=Int, to=Double, master_name))
    (Int64, "to_int") => (stmts, Cast(from=Int64, to=Int, master_name))
    (Int64, "to_uint") => (stmts, Cast(from=Int64, to=UInt, master_name))
    (Int64, "to_uint64") => (stmts, BitCast(from=Int64, to=UInt64, master_name))
    (Int64, "to_float") => (stmts, Cast(from=Int64, to=Float, master_name))
    (Int64, "to_double") => (stmts, Cast(from=Int64, to=Double, master_name))
    (Int64, "reinterpret_as_float") => (stmts, BitCast(from=Int64, to=Float, master_name))
    (Int64, "reinterpret_as_double") => (stmts, BitCast(from=Int64, to=Double, master_name))
    (UInt, "to_int") => (stmts, BitCast(from=UInt, to=Int, master_name))
    (UInt, "to_int64") => (stmts, Cast(from=UInt, to=Int64, master_name))
    (UInt, "to_uint64") => (stmts, Cast(from=UInt, to=UInt64, master_name))
    (UInt, "to_float") => (stmts, Cast(from=UInt, to=Float, master_name))
    (UInt, "to_double") => (stmts, Cast(from=UInt, to=Double, master_name))
    (UInt, "reinterpret_as_float") => (stmts, BitCast(from=UInt, to=Float, master_name))
    (UInt, "reinterpret_as_double") => (stmts, BitCast(from=UInt, to=Double, master_name))
    (UInt64, "to_int") => (stmts, Cast(from=UInt64, to=Int, master_name))
    (UInt64, "to_int64") => (stmts, BitCast(from=UInt64, to=Int64, master_name))
    (UInt64, "to_uint") => (stmts, Cast(from=UInt64, to=UInt, master_name))
    (UInt64, "to_float") => (stmts, Cast(from=UInt64, to=Float, master_name))
    (UInt64, "to_double") => (stmts, Cast(from=UInt64, to=Double, master_name))
    (UInt64, "reinterpret_as_float") => (stmts, BitCast(from=UInt64, to=Float, master_name))
    (UInt64, "reinterpret_as_double") => (stmts, BitCast(from=UInt64, to=Double, master_name))
    (Float, "to_int") => (stmts, Cast(from=Float, to=Int, master_name))
    (Float, "to_int64") => (stmts, Cast(from=Float, to=Int64, master_name))
    (Float, "to_uint") => (stmts, Cast(from=Float, to=UInt, master_name))
    (Float, "to_uint64") => (stmts, Cast(from=Float, to=UInt64, master_name))
    (Float, "to_double") => (stmts, Cast(from=Float, to=Double, master_name))
    (Float, "reinterpret_as_int") => (stmts, BitCast(from=Float, to=Int, master_name))
    (Float, "reinterpret_as_int64") => (stmts, BitCast(from=Float, to=Int64, master_name))
    (Double, "to_int") => (stmts, Cast(from=Double, to=Int, master_name))
    (Double, "to_int64") => (stmts, Cast(from=Double, to=Int64, master_name))
    (Double, "to_uint") => (stmts, Cast(from=Double, to=UInt, master_name))
    (Double, "to_uint64") => (stmts, Cast(from=Double, to=UInt64, master_name))
    (Double, "to_float") => (stmts, Cast(from=Double, to=Float, master_name))
    (Double, "reinterpret_as_int") => (stmts, BitCast(from=Double, to=Int, master_name))
    (Double, "reinterpret_as_int64") => (stmts, BitCast(from=Double, to=Int64, master_name))
    _ => {
      println("Compiler ICE: Unimplemented method \{method_name} for type \{ty}.")
      panic()
    }
  }
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
      guard elements is [{ ty: Some(elem_ty), .. }, ..] else {
        println("Compiler ICE: Array elements must have type.")
        panic()
      }
      let array_expr = KnfExpr::ArrayAlloc(elem_ty, elements.length())
      let array_name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(array_name, Defined("Array", [elem_ty]), array_expr))
      for i in 0..<element_names.length() {
        let elem_name = element_names[i]
        let idx_name = self.new_name("tmp")
        stmts.push(KnfStmt::Let(idx_name, Int, KnfExpr::Int(i)))
        stmts.push(KnfStmt::ArrayPut(array_name, idx_name, KnfExpr::Ident(elem_name)))
      }
      KnfExpr::Ident(array_name)
    }
    StructConstruct(struct_name, items) => {
      guard self.struct_defs.get(struct_name) is Some(struct_def) else {
        println("Compiler ICE: Struct definition not found.")
        panic()
      }
      let field_names = struct_def.fields.map(f => f.name)
      let elements = items.map(item => item.1)
      let (element_stmts, element_names) = self.multiple_exprs_to_knf(elements)
      stmts.append(element_stmts)
      let struct_expr = KnfExpr::CreateStruct(struct_name)
      let var_name = self.new_name("tmp")
      stmts.push(KnfStmt::Let(var_name, Defined(struct_name.to_string(), []), struct_expr))
      for i in 0..<element_names.length() {
        let field_name = field_names[i]
        let elem_name = element_names[i]
        stmts.push(KnfStmt::StructSet(var_name, field_name, KnfExpr::Ident(elem_name)))
      }
      KnfExpr::Ident(var_name)
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
///
/// ```mbt
/// let code =
///   #|fn max(a: Int, b: Int) -> Int {
///   #|  let res = if a > b {
///   #|    a
///   #|  } else {
///   #|    b
///   #|  }
///   #|  res
///   #|}
/// let ctx = Context::new(code)
/// ctx..tokenize()..parse()..typecheck()
/// let f = ctx.top_functions.get("max").unwrap()
/// let knf_func = ctx.top_function_to_knf(f)
/// let expected =
///   #|fn max(a: Int, b: Int) -> Int {
///   #|  let res: Int = if a > b {
///   #|    a
///   #|  } else {
///   #|    b
///   #|  };
///   #|  res
///   #|}
/// inspect(knf_func, content=expected)
/// ```
pub fn Context::if_expr_to_knf(
  self : Self,
  if_expr : IfExpr,
) -> (Array[KnfStmt], KnfExpr) {
  let stmts = Array::new()
  let (cond_stmts, cond_knf) = self.expr_to_knf(if_expr.cond)
  stmts.append(cond_stmts)
  let then_block = self.block_to_knf(if_expr.then_block)
  let else_block = match if_expr.else_block {
    Some(Left(nested_if)) => {
      let (nested_stmts, nested_expr) = self.if_expr_to_knf(nested_if)
      KnfBlock::{ stmts: nested_stmts, final_expr: nested_expr }
    }
    Some(Right(block)) => self.block_to_knf(block)
    None => KnfBlock::{ stmts: Array::new(), final_expr: KnfExpr::Unit }
  }
  let if_knf = KnfExpr::If(cond_knf, then_block, else_block)
  (stmts, if_knf)
}

///|
pub fn KnfExpr::stringify(self : KnfExpr, ident? : Int = 0) -> String {
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
    Cast(from=from, to=to, name) => "cast \{name} (\{from} -> \{to})"
    BitCast(from=from, to=to, name) => "bitcast \{name} (\{from} -> \{to})"
    ArrayGet(array_name, index_name) => "\{array_name}[\{index_name}]"
    TupleGet(tuple_name, index) => "\{tuple_name}.\{index}"
    StructGet(struct_name, field_name) => "\{struct_name}.\{field_name}"
    ArrayAlloc(elem_ty, size) => "array_alloc \{elem_ty} \{size}"
    TupleLiteral(elements) => {
      let elements_str = elements.map(e => e.to_string()).join(", ")
      "(\{elements_str})"
    }
    If(cond, then_block, else_block) => {
      let cond_str = cond.stringify()
      let then_str = then_block.stringify(ident=ident + 2)
      if else_block.stmts.is_empty() && else_block.final_expr is Unit {
        "if \{cond_str} \{then_str}"
      } else {
        let else_str = else_block.stringify(ident=ident + 2)
        "if \{cond_str} \{then_str} else \{else_str}"
      }
    }
    CreateStruct(struct_name) => "alloc \{struct_name}"
  }
}

///|
pub impl Show for KnfExpr with output(self, logger) {
  logger.write_string(self.stringify())
}
