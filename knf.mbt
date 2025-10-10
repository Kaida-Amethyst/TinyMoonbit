///|
pub struct Name {
  id : String
  slot : Int
}

pub fn Context::new_name(self: Self, n: String) -> Name {
  match self.name_env.get(n) {
    Some({ id, slot }) => {
      let name = Name::{id: id, slot: slot + 1}
      self.name_env.set(n, name)
      name
    }
    None => {
      let name = Name::{id: n, slot: 0}
      self.name_env.set(n, name)
      name
    }
  }
}

pub fn Context::get_knf_name(self: Self, n: String) -> Name {
  match self.name_env.get(n) {
    Some(name) => name
    None => {
      println("Compiler ICE: Name \{n} not found in name environment.")
      panic()
    }
  }
}

pub impl Show for Name with output(self, logger) {
  if self.slot == 0 {
    logger.write_string(self.id)
    return
  }
  logger.write_string("\{self.id}.\{self.slot}")
}

pub(all) struct KnfTopLet {
  name: Name
  ty: TypeKind
  expr: KnfExpr
}

pub(all) struct KnfStructDef {
  name: String
  fields: Array[(String, TypeKind)]
}

///|
pub(all) struct KnfFunction {
  name : String
  ty : TypeKind
  params : Array[(Name, TypeKind)]
  body : KnfBlock
}

pub fn Context::top_function_to_knf(self: Self, func: TopFunction) -> KnfFunction {
  self.push_name_env()
  // Convert parameters
  let params: Array[(Name, TypeKind)] = Array::new()
  for param in func.param_list {
    let { name, ty, ..} = param
    let name = self.new_name(name)
    params.push((name, ty.kind))
  }

  let ty = func.ret_ty.kind
  let body = self.block_to_knf(func.body)
  self.pop_name_env()
  KnfFunction::{name: func.fname, ty, params, body}
}

pub fn KnfFunction::stringify(self: KnfFunction) -> String {
  let sb = StringBuilder::new()
  let {name, ty, params, body} = self
  sb.write_string("fn \{name} (")
  let params_str = params.map(
    pair => {
      let (n, t) = pair
      "\{n.id}: \{t}"
    }
  ).join(", ")
  sb.write_string(params_str)
  sb.write_string(") -> \{ty} ")
  sb.write_string(body.stringify(ident=2))
  sb.to_string()
}

///|
pub(all) struct KnfBlock {
  stmts : Array[KnfStmt]
  final_expr : KnfExpr
}

pub fn Context::block_to_knf(self: Self, block: BlockExpr) -> KnfBlock {
  let stmts: Array[KnfStmt] = Array::new()
  for stmt in block.stmts {
    let knf_stmt = self.stmt_to_knf(stmt)
    stmts.append(knf_stmt)
  }
  let final_expr = KnfExpr::Unit
  KnfBlock::{ stmts, final_expr }
}

pub fn KnfBlock::stringify(self: KnfBlock, ident~: Int) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\n")
  let indent_str = " ".repeat(ident)
  for stmt in self.stmts {
    sb.write_string(indent_str)
    sb.write_string(stmt.stringify(ident~))
    sb.write_string("\n")
  }
  sb.write_string(" ".repeat(ident - 2))
  sb.write_string("}")
  sb.to_string()
}

///|
pub(all) enum KnfStmt {
  Let(Name, TypeKind, KnfExpr)
  LetMut(Name, TypeKind, KnfExpr)
  Assign(Name, KnfExpr)
  ArrayPut(Name, Name, KnfExpr)
  StructSet(Name, String, KnfExpr)
  If(KnfExpr, KnfBlock, KnfBlock)
  While(KnfExpr, KnfBlock)
  ExprStmt(KnfExpr)
  Return(KnfExpr)
  ReturnVoid
}

pub fn Context::stmt_to_knf(self: Self, stmt: Stmt) -> Array[KnfStmt] {
  match stmt.kind {
    LetStmt(let_stmt) => self.let_stmt_to_knf(let_stmt)
    LetMutStmt({name, ty, expr, ..}) => {
      let name = self.new_name(name)
      let (stmts, expr) = self.expr_to_knf(expr)
      guard ty is Some(ty) else {
        println("Compiler ICE: Let Mut Stmt must have been inferred type in Type Checking phase.")
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

pub fn Context::let_stmt_to_knf(self: Self, let_stmt: LetStmt) -> Array[KnfStmt] {
  let {pattern, ty, expr, ..} = let_stmt
  let (stmts, expr) = self.expr_to_knf(expr)
  match (pattern.kind, ty, expr) {
    (Wildcard, _, expr) => {
      // let _ = expr;
      [..stmts, KnfStmt::ExprStmt(expr)]
    }
    (Ident(name), Some(ty), expr) => {
      let name = self.new_name(name)
      [..stmts, KnfStmt::Let(name, ty.kind, expr)]
    }
    (Tuple(pats), ty, TupleLiteral(tup)) => {
      ...
    }
    (Tuple(pats), ty, expr) => {
      ...
    }
    _ => {
      println("Compiler ICE: Unsupported pattern in let statement in KNF phase.")
      panic()
    }
  }
}

//pub struct AssignStmt {
//  lineno : Int
//  column : Int
//  end_lineno : Int
//  end_column : Int
//  left_value : LeftValue
//  op : AssignOp
//  expr : Expr
//} derive(Show, Eq)
//pub struct LeftValue {
//  lineno : Int
//  column : Int
//  end_lineno : Int
//  end_column : Int
//  kind : LeftValueKind
//} derive(Show, Eq)
//
/////|
//pub enum LeftValueKind {
//  Ident(String)
//  ArrayAccess(LeftValue, Expr)
//  FieldAccess(LeftValue, String)
//} derive(Show, Eq)
pub fn Context::assign_stmt_to_knf(self: Self, assign_stmt: AssignStmt) -> Array[KnfStmt] {
  ... 
}

pub fn Context::while_stmt_to_knf(self: Self, while_stmt: WhileStmt) -> Array[KnfStmt] {
  ...
}

pub fn Context::for_stmt_to_knf(self: Self, for_stmt: ForStmt) -> Array[KnfStmt] {
  ...
}

pub fn KnfStmt::stringify(self: KnfStmt, ident~: Int) -> String {
  let sb = StringBuilder::new()
  match self {
    KnfStmt::Let(name, ty, expr) => {
      sb.write_string("let \{name}: \{ty} = \{expr.stringify()};")
    }
    KnfStmt::LetMut(name, ty, expr) => {
      sb.write_string("let mut \{name}: \{ty} = \{expr.stringify()};")
    }
    KnfStmt::Assign(name, expr) => {
      sb.write_string("\{name.id} = \{expr.stringify()};")
    }
    KnfStmt::ArrayPut(array_name, index_name, expr) => {
      sb.write_string("\{array_name.id}[\{index_name.id}] = \{expr.stringify()};")
    }
    //KnfStmt::StructPut(struct_name, field_name, expr) => {
    //  sb.write_string("\{struct_name.id}.\{field_name} = \{expr.stringify()};")
    //}
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
    KnfStmt::ExprStmt(expr) => {
      sb.write_string("\{expr.stringify()};")
    }
    KnfStmt::Return(expr) => {
      sb.write_string("return \{expr.stringify()};")
    }
    KnfStmt::ReturnVoid => {
      sb.write_string("return;")
    }
    KnfStmt::StructSet(struct_name, field_name, expr) => {
      sb.write_string("\{struct_name}.\{field_name} = \{expr.stringify()};")
    }
  }
  sb.to_string()
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

pub fn Context::expr_to_knf(self: Self, expr: Expr) -> (Array[KnfStmt], KnfExpr) {
  match expr.kind {
    ApplyExpr(apply_expr) => self.apply_expr_to_knf(apply_expr)
    BlockExpr(block_expr) => {
      let {stmts, final_expr } = self.block_to_knf(block_expr)
      (stmts, final_expr)
    }
    BinaryExpr(op, lhs, rhs) => {
      guard expr.ty is Some(ty) else {
        println("Compiler ICE: Expression must have been inferred type in Type Checking phase.")
        panic()
      }
      self.binary_expr_to_knf(op, lhs, rhs, ty)
    }
    IfExpr(if_expr) => self.if_expr_to_knf(if_expr)
  }
}

pub fn Context::binary_expr_to_knf(self: Self, op: BinaryOp, lhs: Expr, rhs: Expr, ty: TypeKind) -> (Array[KnfStmt], KnfExpr) {
  let (lhs_stmts, lhs_knf_expr) = self.expr_to_knf(lhs)
  let (rhs_stmts, rhs_knf_expr) = self.expr_to_knf(rhs)
  let stmts = Array::new()
  stmts..append(lhs_stmts) ..append(rhs_stmts)
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

//pub struct ApplyExpr {
//  lineno : Int
//  column : Int
//  end_lineno : Int
//  end_column : Int
//  mut ty : TypeKind?
//  kind : ApplyExprKind
//} derive(Show, Eq)
//
/////|
//pub enum ApplyExprKind {
//  AtomExpr(AtomExpr)
//  ArrayAccess(ApplyExpr, Expr)
//  FieldAccess(ApplyExpr, String)
//  TupleAccess(ApplyExpr, Int)
//  Call(ApplyExpr, Array[Expr])
//} derive(Show, Eq)
pub fn Context::apply_expr_to_knf(self: Self, apply_expr: ApplyExpr) -> (Array[KnfStmt], KnfExpr) {
  match apply_expr.kind {
    AtomExpr(atom_expr) => self.atom_expr_to_knf(atom_expr)
    ArrayAccess(array_expr, index_expr) => self.array_access_to_knf(array_expr, index_expr)
    FieldAccess(struct_expr, field_name) => self.field_access_to_knf(struct_expr, field_name)
    TupleAccess(tuple_expr, idx) => self.tuple_access_to_knf(tuple_expr, idx)
    Call(func_expr, arg_exprs) => self.call_expr_to_knf(func_expr, arg_exprs)
  }
}

pub fn Context::array_access_to_knf(self: Self, array_expr: ApplyExpr, index_expr: Expr) -> (Array[KnfStmt], KnfExpr) {
  ...
}

pub fn Context::field_access_to_knf(self: Self, struct_expr: ApplyExpr, field_name: String) -> (Array[KnfStmt], KnfExpr) {
  ...
}

pub fn Context::tuple_access_to_knf(self: Self, tuple_expr: ApplyExpr, idx: Int) -> (Array[KnfStmt], KnfExpr) {
  ...
}

pub fn Context::call_expr_to_knf(self: Self, func_expr: ApplyExpr, arg_exprs: Array[Expr]) -> (Array[KnfStmt], KnfExpr) {
  ...
}

pub fn Context::atom_expr_to_knf(
  self: Self,
  atom_expr: AtomExpr
) -> (Array[KnfStmt], KnfExpr) {
  let stmts: Array[KnfStmt] = Array::new()
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

pub fn Context::multiple_exprs_to_knf(self: Self, exprs: Array[Expr]) -> (Array[KnfStmt], Array[Name]) {
  let stmts: Array[KnfStmt] = Array::new()
  let names: Array[Name] = Array::new()
  for expr in exprs {
    let (expr_stmts, expr_knf) = self.expr_to_knf(expr)
    stmts.append(expr_stmts)
    let name = match expr_knf {
      Ident(name) => name
      _ => {
        guard expr.ty is Some(ty) else {
          println("Compiler ICE: Expression must have been inferred type in Type Checking phase.")
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

pub fn Context::if_expr_to_knf(self: Self, if_expr: IfExpr) -> (Array[KnfStmt], KnfExpr) {
  ...
}

pub fn KnfExpr::stringify(self: KnfExpr) -> String {
  match self {
    KnfExpr::Unit => "()"
    KnfExpr::Int(v) => v.to_string()
    KnfExpr::UInt(v) => v.to_string()
    KnfExpr::Int64(v) => v.to_string()
    KnfExpr::UInt64(v) => v.to_string()
    KnfExpr::Float(v) => v.to_string()
    KnfExpr::Double(v) => v.to_string()
    KnfExpr::Bool(v) => v.to_string()
    KnfExpr::String(v) => "\"\{v}\""
    KnfExpr::Ident(name) => name.to_string()
    KnfExpr::Binary(op, left, right) => "\{left} \{op} \{right}"
    KnfExpr::Not(name) => "!\{name}"
    KnfExpr::Neg(name) => "-\{name}"
    KnfExpr::Call(func_name, args) => {
      let args_str = args.map(arg => arg.to_string()).join(", ")
      "\{func_name}(\{args_str})"
    }
    KnfExpr::ArrayGet(array_name, index_name) => "\{array_name}[\{index_name}]"
    KnfExpr::TupleGet(tuple_name, index) => "\{tuple_name}.\{index}"
    KnfExpr::ArrayLiteral(elements) => {
      let elements_str = elements.map(e => e.to_string()).join(", ")
      "[\{elements_str}]"
    }
    KnfExpr::TupleLiteral(elements) => {
      let elements_str = elements.map(e => e.to_string()).join(", ")
      "(\{elements_str})"
    }
    KnfExpr::If(cond_name, then_block, else_block) => {
      let sb = StringBuilder::new()
      sb.write_string("if \{cond_name} ")
      sb.write_string(then_block.stringify(ident=2))
      if else_block.stmts.length() > 0 {
        sb.write_string(" else ")
        sb.write_string(else_block.stringify(ident=2))
      }
      sb.to_string()
    }
    KnfExpr::CreateStruct(struct_name) => "new \{struct_name}"
  }
}
