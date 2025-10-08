
pub struct Name {
  id: String
  slot: Int
}

pub(all) struct KnfFunction {
  name: String
  ty: TypeKind
  params: Array[KnfParam]
  body: KnfBlock
}

pub(all) struct KnfParam {
  name: String
  ty: TypeKind
}

pub(all) struct KnfBlock {
  stmts: Array[KnfStmt]
}

pub(all) enum KnfStmt {
  Let(Name, String, TypeKind, KnfExpr)
  LetMut(Name, Name, TypeKind, KnfExpr)
  Assign(Name, KnfExpr)
  ArrayPut(Name, Name, KnfExpr)
  //StructPut(Name, String, KnfExpr)
  If(KnfExpr, KnfBlock, KnfBlock)
  While(KnfExpr, KnfBlock)
  ExprStmt(KnfExpr)
}

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
  ArrayLiteral(Array[Name], TypeKind)
  TupleLiteral(Array[Name])
}
