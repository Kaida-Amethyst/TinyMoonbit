///|
pub struct Name {
  id : String
  slot : Int
}

pub fn Context::new_name(self: Self, n: String) -> Name {
  let name_cnt = self.name_counter.get(n).unwrap_or(0)
  let name = Name::{id: n, slot: name_cnt}
  self.name_counter.set(n, name_cnt + 1)
  name
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
  let params: Array[(Name, TypeKind)] = Array::new()
  for param in func.param_list {
    let { name, ty, ..} = param
    let name = self.new_name(name)
    params.push((name, ty.kind))
  }

  let ty = func.ret_ty.kind
  let body = self.block_to_knf(func.body)
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
}

pub fn Context::block_to_knf(self: Self, block: BlockExpr) -> KnfBlock {
  let stmts: Array[KnfStmt] = Array::new()
  for stmt in block.stmts {
    let knf_stmt = self.stmt_to_knf(stmt)
    stmts.append(knf_stmt)
  }
  KnfBlock::{stmts}
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
  Not(Name)
  Neg(Name)
  Call(Name, Array[Name])
  ArrayGet(Name, Name)
  TupleGet(Name, Int)
  ArrayLiteral(Array[Name])
  TupleLiteral(Array[Name])
}

pub fn Context::expr_to_knf(self: Self, expr: Expr) -> (Array[KnfStmt], KnfExpr) {
  ...
}

pub fn KnfExpr::stringify(self: KnfExpr) -> String {
  match self {
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
  }
}
