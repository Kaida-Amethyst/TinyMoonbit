///|
pub struct CodeGen {
  parser_prog : @parser.Program
  llvm_ctx : @IR.LLVMContext
  llvm_prog : @IR.Program
  builder : @IR.IRBuilder
}

///|
pub fn CodeGen::init(parser_prog : @parser.Program) -> CodeGen {
  let llvm_ctx = @IR.LLVMContext::new()
  let llvm_prog = @IR.Program::new("tinymoonbit", llvm_ctx)
  let builder = @IR.IRBuilder::new()
  CodeGen::{ parser_prog, llvm_ctx, llvm_prog, builder }
}

///|
pub fn CodeGen::dump(self : Self) -> Unit {
  self.llvm_prog.dump()
}

///|
traitalias @IR.Type

///|
fn CodeGen::convert_parser_type_to_llvm_type(
  self : Self,
  ty : @parser.Type
) -> &Type {
  let ctx = self.llvm_ctx
  match ty {
    Unit => ctx.getVoidTy() as &Type
    Bool => ctx.getInt1Ty()
    Int | UInt => ctx.getInt32Ty()
    Int64 | UInt64 => ctx.getInt64Ty()
    Float => ctx.getFloatTy()
    Double => ctx.getDoubleTy()
    Ptr(_) => ctx.getPtrTy()
    Array(_) => ctx.getPtrTy()
    Struct(sname) =>
      ctx
      .getStructTypeByName(sname)
      .or_else(() => {
        println("Error: Struct type not found: \{sname}")
        panic()
      })
  }
}

///|
fn CodeGen::getFunction(self : Self, name : String) -> @IR.Function? {
  match self.llvm_prog.functions.get(name) {
    Some(func) => Some(func)
    None => {
      println("CodeGen Error: Function not found: \{name}")
      panic()
    }
  }
}

///|
traitalias @IR.Value

///|
priv struct Env {
  gen : CodeGen
  parser_func : @parser.Function
  llvm_func : @IR.Function
  parent : Env?
  symbols : Map[String, &Value]
}

///|
fn Env::new(
  gen : CodeGen,
  parser_func : @parser.Function,
  llvm_func : @IR.Function
) -> Env {
  Env::{ gen, parser_func, llvm_func, parent: None, symbols: Map::new() }
}

///|
fn Env::subenv(self : Self) -> Env {
  Env::{
    gen: self.gen,
    parser_func: self.parser_func,
    llvm_func: self.llvm_func,
    parent: Some(self),
    symbols: Map::new(),
  }
}

///|
fn Env::get_symbol(self : Self, name : String) -> &Value? {
  match self.symbols.get(name) {
    Some(value) => Some(value)
    None =>
      match self.parent {
        Some(parent_env) => parent_env.get_symbol(name)
        None => None
      }
  }
}

///|
pub fn CodeGen::emitProg(self : Self) -> Unit raise Error {
  // collect struct definitions and functions types
  self.parser_prog.structs
  .values()
  .each(struct_def => self.emitStructDef(struct_def))
  let llvm_funcs = Map::new()
  self.parser_prog.functions.each((name, func) => llvm_funcs.set(
    name,
    self.genFuncVal(func),
  ))
  self.parser_prog.externs.each((name, func) => llvm_funcs.set(
    name,
    self.genFuncVal(func),
  ))
  for func_name in self.parser_prog.functions.keys() {
    let parser_func = self.parser_prog.functions
      .get(func_name)
      .or_else(() => {
        println("Error: Function not found: \{func_name}")
        panic()
      })
    let llvm_func = llvm_funcs
      .get(func_name)
      .or_else(() => {
        println("Error: LLVM function not found: \{func_name}")
        panic()
      })
    let env = Env::new(self, parser_func, llvm_func)
    env.emitFunc()
  }
}

///|
fn CodeGen::emitStructDef(
  self : Self,
  struct_def : @parser.StructDef
) -> Unit raise Error {
  // 将结构体字段类型转换为LLVM类型
  let field_types = struct_def.fields.map(field => {
    let (_, ty) = field
    self.convert_parser_type_to_llvm_type(ty)
  })

  // 创建LLVM结构体类型并自动注册到context中
  let _ = self.llvm_ctx.getStructType(field_types, name=struct_def.name)

}

///|
fn CodeGen::genFuncVal(
  self : Self,
  func : @parser.Function
) -> @IR.Function raise Error {
  let param_tys = func.params.map(param_ty => {
    let (_, ty) = param_ty
    self.convert_parser_type_to_llvm_type(ty)
  })
  let ret_ty = self.convert_parser_type_to_llvm_type(func.ret_ty)
  let func_ty = self.llvm_ctx.getFunctionType(ret_ty, param_tys)
  self.llvm_prog.addFunction(func_ty, func.name)
}

///|
fn Env::emitFunc(self : Self) -> Unit raise {
  let llvm_func = self.llvm_func
  let parser_func = self.parser_func
  let builder = self.gen.builder
  let entry = llvm_func.addBasicBlock(name="entry")
  builder.setInsertPoint(entry)
  parser_func.params.eachi((i, name_ty) => {
    let (name, ty) = name_ty
    let param_val = llvm_func.getArg(i).unwrap()
    let ty = self.gen.convert_parser_type_to_llvm_type(ty)
    let alloca = builder.createAlloca(ty)
    let _ = builder.createStore(param_val, alloca)
    self.symbols.set(name, alloca)
  })
  parser_func.body.each(stmt => self.emitStmt(stmt))
}

///|
fn Env::emitStmt(self : Self, stmt : @parser.Stmt) -> Unit raise Error {
  match stmt {
    Let(name, ty, None) => {
      let data_ty = self.gen.convert_parser_type_to_llvm_type(ty)
      let alloca = self.gen.builder.createAlloca(data_ty)
      self.symbols.set(name, alloca)
    }
    Let(name, ty, Some(expr)) => {
      let data_ty = self.gen.convert_parser_type_to_llvm_type(ty)
      let alloca = self.gen.builder.createAlloca(data_ty)
      self.symbols.set(name, alloca)
      let value = self.emitExpr(expr)
      let _ = self.gen.builder.createStore(value, alloca)

    }
    Assign(left_val, expr) => {
      let ptr = self.emitLeftValue(left_val)
      let value = self.emitExpr(expr)
      let _ = self.gen.builder.createStore(value, ptr)

    }
    If(cond, then_stmts, []) => {
      let cond_val = self.emitExpr(cond)
      let then_block = self.llvm_func.addBasicBlock()
      let merge_block = self.llvm_func.addBasicBlock()
      let _ = self.gen.builder.createCondBr(cond_val, then_block, merge_block)
      self.gen.builder.setInsertPoint(then_block)
      let then_env = self.subenv()
      then_stmts.each(s => then_env.emitStmt(s))
      let _ = self.gen.builder.createBr(merge_block)
      self.gen.builder.setInsertPoint(merge_block)
    }
    If(cond, then_stmts, else_stmts) => {
      let cond_val = self.emitExpr(cond)
      let then_block = self.llvm_func.addBasicBlock()
      let else_block = self.llvm_func.addBasicBlock()
      let merge_block = self.llvm_func.addBasicBlock()
      let _ = self.gen.builder.createCondBr(cond_val, then_block, else_block)
      self.gen.builder.setInsertPoint(then_block)
      let then_env = self.subenv()
      then_stmts.each(s => then_env.emitStmt(s))
      let _ = self.gen.builder.createBr(merge_block)
      self.gen.builder.setInsertPoint(else_block)
      let else_env = self.subenv()
      else_stmts.each(s => else_env.emitStmt(s))
      let _ = self.gen.builder.createBr(merge_block)
      self.gen.builder.setInsertPoint(merge_block)
    }
    While(cond, stmts) => {
      let cond_block = self.llvm_func.addBasicBlock()
      let body_block = self.llvm_func.addBasicBlock()
      let merge_block = self.llvm_func.addBasicBlock()
      let cond_val = self.emitExpr(cond)
      let _ = self.gen.builder.createCondBr(cond_val, body_block, merge_block)
      self.gen.builder.setInsertPoint(body_block)
      let body_env = self.subenv()
      stmts.each(s => body_env.emitStmt(s))
      let _ = self.gen.builder.createBr(cond_block)
      self.gen.builder.setInsertPoint(merge_block)
    }
    Return(None) => {
      let _ = self.gen.builder.createRetVoid()

    }
    Return(Some(expr)) => {
      let value = self.emitExpr(expr)
      let _ = self.gen.builder.createRet(value)

    }
    Expr(expr) => {
      let _ = self.emitExpr(expr)

    }
  }
  //_ => {
  //  println("Error: Unsupported statement: \{stmt}");
  //  panic()
  //}
}

///|
fn Env::emitLeftValue(
  self : Self,
  left_val : @parser.LeftValue
) -> &Value raise {
  match left_val {
    Var(name, ..) => {
      let addr = self
        .get_symbol(name)
        .or_else(() => {
          println("Error: Variable not found: \{name}")
          panic()
        })
      addr
    }
    ArrayGet(array_val, index_expr, ty=Some(ele_ty)) => {
      let array_ptr = self.emitLeftValue(array_val)
      let index_val = self.emitExpr(index_expr)
      let ele_ty = self.gen.convert_parser_type_to_llvm_type(ele_ty)
      let element_ptr = self.gen.builder.createGEP(array_ptr, ele_ty, [
        index_val,
      ])
      element_ptr
    }
    StructAccess(struct_val, field_name, ..) => {
      let struct_ptr = self.emitLeftValue(struct_val)

      // 需要根据左值的类型信息来获取结构体定义
      let struct_type_name = match struct_val {
        Var(_, ty=Some(Struct(sname))) => sname
        StructAccess(_, _, ty=Some(Struct(sname))) => sname
        ArrayGet(_, _, ty=Some(Struct(sname))) => sname
        _ => {
          println("Error: Cannot determine struct type for field access")
          panic()
        }
      }
      let struct_def = self.gen.parser_prog.structs
        .get(struct_type_name)
        .or_else(() => {
          println("Error: Struct definition not found: \{struct_type_name}")
          panic()
        })
      let field_index = struct_def
        .get_field_index(field_name)
        .or_else(() => {
          println(
            "Error: Field \{field_name} not found in struct \{struct_type_name}",
          )
          panic()
        })

      // 获取LLVM结构体类型
      let llvm_struct_type = self.gen.llvm_ctx
        .getStructTypeByName(struct_type_name)
        .or_else(() => {
          println("Error: LLVM struct type not found: \{struct_type_name}")
          panic()
        })

      // 创建GEP指令：第一个索引0是解引用指针，第二个索引是字段索引
      let zero = self.gen.llvm_ctx.getConstInt32(0)
      let field_idx = self.gen.llvm_ctx.getConstInt32(field_index)
      let field_ptr = self.gen.builder.createGEP(
        struct_ptr,
        llvm_struct_type as &Type,
        [zero, field_idx],
      )
      field_ptr
    }
    _ => {
      println("Error: Unsupported left value: \{left_val}")
      panic()
    }
  }
}

///|
fn Env::emitExpr(self : Self, expr : @parser.Expr) -> &Value raise {
  match expr {
    Apply(apply_expr, ..) => self.emitApplyExpr(apply_expr)
    Neg(expr, ty=Some(Int | Int64 as ty)) => {
      let value = self.emitExpr(expr)
      //let zero = self.gen.llvm_ctx.getConstInt32(0) as &Value;
      let zero = match ty {
        Int => self.gen.llvm_ctx.getConstInt32(0)
        _ => self.gen.llvm_ctx.getConstInt64(0)
      }
      self.gen.builder.createSub(zero, value)
    }
    Neg(expr, ty=Some(Float | Double as ty)) => {
      let value = self.emitExpr(expr)
      let zero = match ty {
        Float => self.gen.llvm_ctx.getConstFloat(0.0)
        _ => self.gen.llvm_ctx.getConstDouble(0.0)
      }
      // should be FNeg
      self.gen.builder.createFSub(zero, value)
    }
    Neg(_, ..) => {
      println("Error: Unsupported negation type")
      panic()
    }
    Add(lhs, rhs, ty=Some(Int | Int64 | UInt | UInt64)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createAdd(lhs_val, rhs_val)
    }
    Add(lhs, rhs, ty=Some(Float | Double)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createFAdd(lhs_val, rhs_val)
    }
    Add(_, ..) => {
      println("Error: Unsupported addition type")
      panic()
    }
    Sub(lhs, rhs, ty=Some(Int | Int64 | UInt | UInt64)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createSub(lhs_val, rhs_val)
    }
    Sub(lhs, rhs, ty=Some(Float | Double)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createFSub(lhs_val, rhs_val)
    }
    Sub(_, ..) => {
      println("Error: Unsupported subtraction type")
      panic()
    }
    Mul(lhs, rhs, ty=Some(Int | Int64 | UInt | UInt64)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createMul(lhs_val, rhs_val)
    }
    Mul(lhs, rhs, ty=Some(Float | Double)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createFMul(lhs_val, rhs_val)
    }
    Mul(_, ..) => {
      println("Error: Unsupported multiplication type")
      panic()
    }
    Div(lhs, rhs, ty=Some(Int | Int64)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createSDiv(lhs_val, rhs_val)
    }
    Div(lhs, rhs, ty=Some(UInt | UInt64)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createUDiv(lhs_val, rhs_val)
    }
    Div(lhs, rhs, ty=Some(Float | Double)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createFDiv(lhs_val, rhs_val)
    }
    Div(_, ..) => {
      println("Error: Unsupported division type")
      panic()
    }
    Rem(lhs, rhs, ty=Some(Int | Int64)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createSRem(lhs_val, rhs_val)
    }
    Rem(lhs, rhs, ty=Some(UInt | UInt64)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createURem(lhs_val, rhs_val)
    }
    Rem(lhs, rhs, ty=Some(Float | Double)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createFRem(lhs_val, rhs_val)
    }
    Rem(_, ..) => {
      println("Error: Unsupported remainder type")
      panic()
    }
    Eq(lhs, rhs) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      match lhs_val.getType().asTypeEnum() {
        Int32Type(_) | Int64Type(_) =>
          self.gen.builder.createICmpEQ(lhs_val, rhs_val)
        FloatType(_) | DoubleType(_) =>
          self.gen.builder.createFCmpOEQ(lhs_val, rhs_val)
        _ => {
          println("Error: Unsupported type for equality")
          panic()
        }
      }
    }
    Ne(lhs, rhs) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      match lhs_val.getType().asTypeEnum() {
        Int32Type(_) | Int64Type(_) =>
          self.gen.builder.createICmpNE(lhs_val, rhs_val)
        FloatType(_) | DoubleType(_) =>
          self.gen.builder.createFCmpONE(lhs_val, rhs_val)
        _ => {
          println("Error: Unsupported type for inequality")
          panic()
        }
      }
    }
    Lt(lhs, rhs) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      match lhs_val.getType().asTypeEnum() {
        Int32Type(_) | Int64Type(_) =>
          self.gen.builder.createICmpSLT(lhs_val, rhs_val)
        FloatType(_) | DoubleType(_) =>
          self.gen.builder.createFCmpOLT(lhs_val, rhs_val)
        _ => {
          println("Error: Unsupported type for less than")
          panic()
        }
      }
    }
    Le(lhs, rhs) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      match lhs_val.getType().asTypeEnum() {
        Int32Type(_) | Int64Type(_) =>
          self.gen.builder.createICmpSLE(lhs_val, rhs_val)
        FloatType(_) | DoubleType(_) =>
          self.gen.builder.createFCmpOLE(lhs_val, rhs_val)
        _ => {
          println("Error: Unsupported type for less than or equal")
          panic()
        }
      }
    }
    Gt(lhs, rhs) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      match lhs_val.getType().asTypeEnum() {
        Int32Type(_) | Int64Type(_) =>
          self.gen.builder.createICmpSGT(lhs_val, rhs_val)
        FloatType(_) | DoubleType(_) =>
          self.gen.builder.createFCmpOGT(lhs_val, rhs_val)
        _ => {
          println("Error: Unsupported type for greater than")
          panic()
        }
      }
    }
    Ge(lhs, rhs) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      match lhs_val.getType().asTypeEnum() {
        Int32Type(_) | Int64Type(_) =>
          self.gen.builder.createICmpSGE(lhs_val, rhs_val)
        FloatType(_) | DoubleType(_) =>
          self.gen.builder.createFCmpOGE(lhs_val, rhs_val)
        _ => {
          println("Error: Unsupported type for greater than or equal")
          panic()
        }
      }
    }
    And(lhs, rhs) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createAnd(lhs_val, rhs_val)
    }
    Or(lhs, rhs) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createOr(lhs_val, rhs_val)
    }
    Shl(lhs, rhs, ..) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createShl(lhs_val, rhs_val)
    }
    Shr(lhs, rhs, ty=Some(UInt | UInt64)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createLShr(lhs_val, rhs_val)
    }
    Shr(lhs, rhs, ty=Some(Int | Int64)) => {
      let lhs_val = self.emitExpr(lhs)
      let rhs_val = self.emitExpr(rhs)
      self.gen.builder.createAShr(lhs_val, rhs_val)
    }
    Shr(_, ..) => {
      println("Error: Unsupported shift right type")
      panic()
    }
  }
}

///|
fn Env::emitApplyExpr(
  self : Self,
  apply_expr : @parser.ApplyExpr
) -> &Value raise {
  match apply_expr {
    Atom(atom_expr, ..) => self.emitAtomExpr(atom_expr)
    ArrayGet(array_val, index_expr, ty=Some(ele_ty)) => {
      let array_ptr = self.emitApplyExpr(array_val)
      let index_val = self.emitExpr(index_expr)
      let ele_ty = self.gen.convert_parser_type_to_llvm_type(ele_ty)
      let element_ptr = self.gen.builder.createGEP(array_ptr, ele_ty, [
        index_val,
      ])
      self.gen.builder.createLoad(ele_ty, element_ptr)
    }
    StructAccess(struct_val, field_name, ..) => {
      let struct_ptr = self.emitApplyExpr(struct_val)

      // 需要根据Apply表达式的类型信息来获取结构体定义
      let struct_type_name = match struct_val {
        Atom(Var(_, ty=Some(Struct(sname))), ..) => sname
        StructAccess(_, _, ty=Some(Struct(sname))) => sname
        ArrayGet(_, _, ty=Some(Struct(sname))) => sname
        _ => {
          println("Error: Cannot determine struct type for field access")
          panic()
        }
      }
      let struct_def = self.gen.parser_prog.structs
        .get(struct_type_name)
        .or_else(() => {
          println("Error: Struct definition not found: \{struct_type_name}")
          panic()
        })
      let field_index = struct_def
        .get_field_index(field_name)
        .or_else(() => {
          println(
            "Error: Field \{field_name} not found in struct \{struct_type_name}",
          )
          panic()
        })
      let field_type = struct_def
        .get_field_type(field_name)
        .or_else(() => {
          println("Error: Field type not found for \{field_name}")
          panic()
        })

      // 获取LLVM结构体类型
      let llvm_struct_type = self.gen.llvm_ctx
        .getStructTypeByName(struct_type_name)
        .or_else(() => {
          println("Error: LLVM struct type not found: \{struct_type_name}")
          panic()
        })

      // 创建GEP指令获取字段指针
      let zero = self.gen.llvm_ctx.getConstInt32(0)
      let field_idx = self.gen.llvm_ctx.getConstInt32(field_index)
      let field_ptr = self.gen.builder.createGEP(
        struct_ptr,
        llvm_struct_type as &Type,
        [zero, field_idx],
      )

      // 加载字段值
      let field_llvm_type = self.gen.convert_parser_type_to_llvm_type(
        field_type,
      )
      self.gen.builder.createLoad(field_llvm_type, field_ptr)
    }
    Cast(left, cast_ty) => {
      let value = self.emitApplyExpr(left)
      let target_ty = self.gen.convert_parser_type_to_llvm_type(cast_ty)
      match (value.getType().asTypeEnum(), target_ty.asTypeEnum()) {
        // Integer to float
        (Int32Type(_), FloatType(float_ty)) =>
          self.gen.builder.createSIToFP(value, float_ty)
        (Int32Type(_), DoubleType(double_ty)) =>
          self.gen.builder.createSIToFP(value, double_ty)
        (Int64Type(_), FloatType(float_ty)) =>
          self.gen.builder.createSIToFP(value, float_ty)
        (Int64Type(_), DoubleType(double_ty)) =>
          self.gen.builder.createSIToFP(value, double_ty)

        // Float to integer
        (FloatType(_), Int32Type(int32_ty)) =>
          self.gen.builder.createFPToSI(value, int32_ty)
        (FloatType(_), Int64Type(int64_ty)) =>
          self.gen.builder.createFPToSI(value, int64_ty)
        (DoubleType(_), Int32Type(int32_ty)) =>
          self.gen.builder.createFPToSI(value, int32_ty)
        (DoubleType(_), Int64Type(int64_ty)) =>
          self.gen.builder.createFPToSI(value, int64_ty)

        // Float to float
        (FloatType(_), DoubleType(double_ty)) =>
          self.gen.builder.createFPExt(value, double_ty)
        (DoubleType(_), FloatType(float_ty)) =>
          self.gen.builder.createFPTrunc(value, float_ty)

        // Integer to integer
        (Int32Type(_), Int64Type(int64_ty)) =>
          self.gen.builder.createSExt(value, int64_ty)
        (Int64Type(_), Int32Type(int32_ty)) =>
          self.gen.builder.createTrunc(value, int32_ty)

        // Same type
        (from_ty, to_ty) if from_ty == to_ty => value
        _ => {
          println(
            "Error: Unsupported cast from \{value.getType()} to \{target_ty}",
          )
          panic()
        }
      }
    }
    _ => {
      println("Error: Unsupported apply expression: \{apply_expr}")
      panic()
    }
  }
}

///|
fn Env::emitAtomExpr(self : Self, atomExpr : @parser.AtomExpr) -> &Value raise {
  let ctx = self.gen.llvm_ctx
  match atomExpr {
    Bool(true) => {
      ctx.getConstTrue() as &Value
    }
    Bool(false) => ctx.getConstFalse()
    Int(v) => ctx.getConstInt32(v)
    UInt(v) => ctx.getConstInt32(v.reinterpret_as_int())
    Int64(v) => ctx.getConstInt64(v)
    UInt64(v) => ctx.getConstInt64(v.reinterpret_as_int64())
    Float(v) => ctx.getConstFloat(v.to_double())
    Double(v) => ctx.getConstDouble(v)
    Var(name, ty=Some(ty)) => {
      let addr = self
        .get_symbol(name)
        .or_else(() => {
          println("Error: Variable not found: \{name}")
          panic()
        })
      let ty = self.gen.convert_parser_type_to_llvm_type(ty)
      self.gen.builder.createLoad(ty, addr)
    }
    Ref(name, ..) => // type must be a pointer type
      self.symbols
      .get(name)
      .or_else(() => {
        println("Error: Reference not found: \{name}")
        panic()
      })
    TypeSizeof(ty) => {
      let v = self.gen
        .convert_parser_type_to_llvm_type(ty)
        .getScalarSizeInBits()
      self.gen.llvm_ctx.getConstInt32(v.reinterpret_as_int())
    }
    ExprSizeof(_) => {
      println("Error: ExprSizeof not implemented yet")
      panic()
    }
    Array(exprs, ty=Some(Array(ele_ty))) => {
      let ele_ty = self.gen.convert_parser_type_to_llvm_type(ele_ty)
      let array_size = exprs.length().reinterpret_as_uint()
      let arr_ty = self.gen.llvm_ctx.getArrayType(ele_ty, array_size)
      let array_ptr = self.gen.builder.createAlloca(arr_ty)
      exprs.eachi((i, expr) => {
        let value = self.emitExpr(expr)
        let index = self.gen.llvm_ctx.getConstInt32(i)
        let element_ptr = self.gen.builder.createGEP(array_ptr, ele_ty, [index])
        let _ = self.gen.builder.createStore(value, element_ptr)

      })
      array_ptr
    }
    Paren(expr, ..) => self.emitExpr(expr)
    Call(func_name, args, ..) => {
      let llvm_func = self.gen
        .getFunction(func_name)
        .or_else(() => {
          println("Error: LLVM function not found: \{func_name}")
          panic()
        })
      let args_vals = args.map(arg => self.emitExpr(arg))
      self.gen.builder.createCall(llvm_func, args_vals) as &Value
    }
    _ => {
      println("Error: Unsupported atom expression: \{atomExpr}")
      panic()
    }
  }
}
