///|
pub fn Context::llvm_codegen(self : Self) -> @IR.Module raise {
  let { llvm_ctx, llvm_mod, .. } = self

  // codegen for external functions
  for _, ext_fn in self.knf_ext_funcs {
    self.codegen_knf_ext_func(ext_fn)
  }

  // gen function value for all top functions
  for _, top_fn in self.knf_top_funcs {
    self.codegen_knf_func_for_func_value(top_fn)
  }

  // codegen function
  for _, top_fn in self.knf_top_funcs {
    self.codegen_knf_func(top_fn)
  }
  llvm_mod
}

///|
pub fn Context::codegen_knf_ext_func(
  self : Self,
  ext_fn : KnfExternFunc,
) -> Unit raise {
  let { llvm_ctx, llvm_mod, .. } = self
  let argTys = ext_fn.params.map(p => codegen_for_type(p, llvm_ctx))
  let retTy = codegen_for_type(ext_fn.ty, llvm_ctx)
  let fty = llvm_ctx.getFunctionType(retTy, argTys)
  let fval = llvm_mod.addFunction(fty, ext_fn.name.to_string())
  self.llvm_funcs.set(ext_fn.name.to_string(), fval)
}

///|
pub fn Context::codegen_knf_func_for_func_value(
  self : Self,
  top_fn : KnfFunction,
) -> Unit raise {
  let { llvm_ctx, llvm_mod, .. } = self
  let argTys = top_fn.params.map(p => {
    let (_, p) = p
    codegen_for_type(p, llvm_ctx)
  })
  //let retTy = codegen_for_type(top_fn.ty, llvm_ctx)
  let retTy = if top_fn.name is "main" {
    (llvm_ctx.getInt32Ty() : &@IR.Type)
  } else {
    codegen_for_type(top_fn.ty, llvm_ctx)
  }
  let fty = llvm_ctx.getFunctionType(retTy, argTys)
  let fval = llvm_mod.addFunction(fty, top_fn.name.to_string())
  self.llvm_funcs.set(top_fn.name.to_string(), fval)
}

///|
pub fn Context::codegen_knf_func(
  self : Self,
  top_fn : KnfFunction,
) -> Unit raise {
  let { builder, .. } = self
  let fval = self.llvm_funcs.get(top_fn.name).unwrap()
  let { name_value_map, name_type_map, .. } = top_fn
  for i, pair in top_fn.params {
    let (name, _) = pair
    let llvm_param = fval.getArg(i).unwrap()
    name_value_map.set(name, llvm_param)
  }
  let entry_bb = fval.addBasicBlock(name="entry")
  builder.setInsertPoint(entry_bb)
  let { stmts, final_expr } = top_fn.body
  for stmt in stmts {
    self.codegen_knf_stmt(stmt, name_value_map, name_type_map)
  }
  match final_expr {
    Unit => ()
    e => {
      let ret_val = self.codegen_knf_expr(e, name_value_map, name_type_map)
      println(ret_val)
      if !(ret_val.getType().asTypeEnum() is VoidType(_)) {
        let _ = builder.createRet(ret_val)

      }
    }
  }
  if top_fn.name is "main" {
    let _ = builder.createRet(self.llvm_ctx.getConstInt32(0))

  }
}

///|
pub fn Context::codegen_knf_stmt(
  self : Self,
  stmt : KnfStmt,
  name_value_map : Map[Name, &@IR.Value],
  name_type_map : Map[Name, TypeKind],
) -> Unit raise {
  match stmt {
    Let(name, ty, expr) => {
      let expr_val = self.codegen_knf_expr(expr, name_value_map, name_type_map)
      if !name.is_wild_card() {
        name_value_map.set(name, expr_val)
        name_type_map.set(name, ty)
      }
    }
    LetMut(name, ty, expr) => {
      let llvm_ty = codegen_for_type(ty, self.llvm_ctx)
      let alloca = self.builder.createAlloca(llvm_ty)
      let expr_val = self.codegen_knf_expr(expr, name_value_map, name_type_map)
      let _ = self.builder.createStore(expr_val, alloca)
      name_value_map.set(name, alloca)
      name_type_map.set(name, ty)
    }
    Assign(name, right_name) => {
      let var_ptr = name_value_map.get(name).unwrap()
      guard var_ptr.getType().asTypeEnum() is PointerType(_) else {
        println("Compiler ICE: trying to assign to a non-mutable variable")
        panic()
      }
      let expr_val = name_value_map.get(right_name).unwrap()
      let _ = self.builder.createStore(expr_val, var_ptr)

    }
    ArrayPut(_) => {
      println("codegen for array put not implemented yet")
      panic()
    }
    ExprStmt(expr) => {
      let _ = self.codegen_knf_expr(expr, name_value_map, name_type_map)

    }
    While(_, _) => {
      println("codegen for while not implemented yet")
      panic()
    }
    StructSet(_) => {
      println("codegen for struct set not implemented yet")
      panic()
    }
    Return(expr) => {
      let ret_val = self.codegen_knf_expr(expr, name_value_map, name_type_map)
      let _ = self.builder.createRet(ret_val)

    }
    ReturnVoid => {
      let _ = self.builder.createRetVoid()

    }
  }
}

///|
pub fn Context::codegen_knf_expr(
  self : Self,
  expr : KnfExpr,
  name_value_map : Map[Name, &@IR.Value],
  name_type_map : Map[Name, TypeKind],
) -> &@IR.Value raise {
  match expr {
    Unit => {
      println("codegen for unit expression not implemented yet")
      panic()
    }
    Int(i) => (self.llvm_ctx.getConstInt32(i) : &@IR.Value)
    Int64(i) => self.llvm_ctx.getConstInt64(i)
    UInt(u) => self.llvm_ctx.getConstInt32(u.reinterpret_as_int())
    UInt64(u) => self.llvm_ctx.getConstInt64(u.reinterpret_as_int64())
    Float(f) => self.llvm_ctx.getConstFloat(f)
    Double(d) => self.llvm_ctx.getConstDouble(d)
    Ident(name) => {
      guard name_value_map.get(name) is Some(val) else {
        println("Compiler ICE: variable not found in name_value_map")
        panic()
      }
      let ty = name_type_map.get(name).unwrap()
      let llvm_ty = codegen_for_type(ty, self.llvm_ctx)
      match val.getType().asTypeEnum() {
        PointerType(_) => self.builder.createLoad(llvm_ty, val)
        _ => val
      }
    }
    Bool(b) =>
      match b {
        true => self.llvm_ctx.getConstTrue()
        false => self.llvm_ctx.getConstFalse()
      }
    String(_) => {
      println("codegen for string literal not implemented yet")
      panic()
    }
    Binary(op, left_name, right_name) =>
      self.codegen_knf_binary_expr(
        op, left_name, right_name, name_value_map, name_type_map,
      )
    Not(_) => {
      println("codegen for not expression not implemented yet")
      panic()
    }
    Neg(_) => {
      println("codegen for neg expression not implemented yet")
      panic()
    }
    If(_, _, _) => {
      println("codegen for if expression not implemented yet")
      panic()
    }
    ArrayGet(_) => {
      println("codegen for array get not implemented yet")
      panic()
    }
    Call(fname, arg_names) => {
      guard self.llvm_funcs.get(fname.to_string()) is Some(func) else {
        println("Compiler ICE: function not found in llvm_funcs")
        panic()
      }
      let arg_vals = arg_names.map(arg_name => {
        guard name_value_map.get(arg_name) is Some(val) else {
          println("Compiler ICE: variable not found in name_value_map")
          panic()
        }
        let ty = name_type_map.get(arg_name).unwrap()
        let llvm_ty = codegen_for_type(ty, self.llvm_ctx)
        match val.getType().asTypeEnum() {
          PointerType(_) => self.builder.createLoad(llvm_ty, val)
          _ => val
        }
      })
      self.builder.createCall(func, arg_vals)
    }
    CreateStruct(_) => {
      println("codegen for create struct not implemented yet")
      panic()
    }
    TupleGet(_) => {
      println("codegen for tuple get not implemented yet")
      panic()
    }
    ArrayLiteral(_) => {
      println("codegen for array literal not implemented yet")
      panic()
    }
    TupleLiteral(_) => {
      println("codegen for tuple literal not implemented yet")
      panic()
    }
  }
}

///|
pub fn Context::codegen_knf_binary_expr(
  self : Self,
  op : BinaryOp,
  left_name : Name,
  right_name : Name,
  name_value_map : Map[Name, &@IR.Value],
  name_type_map : Map[Name, TypeKind],
) -> &@IR.Value raise {
  guard name_value_map.get(left_name) is Some(left_val) else {
    println("Compiler ICE: variable not found in name_value_map")
    panic()
  }
  guard name_value_map.get(right_name) is Some(right_val) else {
    println("Compiler ICE: variable not found in name_value_map")
    panic()
  }
  match op {
    Add => self.builder.createAdd(left_val, right_val)
    Sub => self.builder.createSub(left_val, right_val)
    Mul => self.builder.createMul(left_val, right_val)
    Div => {
      guard name_type_map.get(left_name) is Some(ty) else {
        println("Compiler ICE: variable type not found in name_type_map")
        panic()
      }
      match ty {
        Int | Int64 => self.builder.createSDiv(left_val, right_val)
        UInt | UInt64 => self.builder.createUDiv(left_val, right_val)
        Float => self.builder.createFDiv(left_val, right_val)
        Double => self.builder.createFDiv(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for division")
          panic()
        }
      }
    }
    Mod => {
      guard name_type_map.get(left_name) is Some(ty) else {
        println("Compiler ICE: variable type not found in name_type_map")
        panic()
      }
      match ty {
        Int | Int64 => self.builder.createSRem(left_val, right_val)
        UInt | UInt64 => self.builder.createURem(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for modulus")
          panic()
        }
      }
    }
    //Eq => self.builder.createICmpEQ(left_val, right_val)
    Eq => {
      guard name_type_map.get(left_name) is Some(ty) else {
        println("Compiler ICE: variable type not found in name_type_map")
        panic()
      }
      match ty {
        Int | Int64 | UInt | UInt64 =>
          self.builder.createICmpEQ(left_val, right_val)
        Float | Double => self.builder.createFCmpUEQ(left_val, right_val)
        Bool => self.builder.createICmpEQ(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for equality comparison")
          panic()
        }
      }
    }
    NE => {
      guard name_type_map.get(left_name) is Some(ty) else {
        println("Compiler ICE: variable type not found in name_type_map")
        panic()
      }
      match ty {
        Int | Int64 | UInt | UInt64 =>
          self.builder.createICmpNE(left_val, right_val)
        Float | Double => self.builder.createFCmpUNE(left_val, right_val)
        Bool => self.builder.createICmpNE(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for inequality comparison")
          panic()
        }
      }
    }
    LT => {
      guard name_type_map.get(left_name) is Some(ty) else {
        println("Compiler ICE: variable type not found in name_type_map")
        panic()
      }
      match ty {
        Int | Int64 => self.builder.createICmpSLT(left_val, right_val)
        UInt | UInt64 => self.builder.createICmpULT(left_val, right_val)
        Float | Double => self.builder.createFCmpULT(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for less-than comparison")
          panic()
        }
      }
    }
    LE => {
      guard name_type_map.get(left_name) is Some(ty) else {
        println("Compiler ICE: variable type not found in name_type_map")
        panic()
      }
      match ty {
        Int | Int64 => self.builder.createICmpSLE(left_val, right_val)
        UInt | UInt64 => self.builder.createICmpULE(left_val, right_val)
        Float | Double => self.builder.createFCmpULE(left_val, right_val)
        _ => {
          println(
            "Compiler ICE: unsupported type for less-than-or-equal comparison",
          )
          panic()
        }
      }
    }
    GT => {
      guard name_type_map.get(left_name) is Some(ty) else {
        println("Compiler ICE: variable type not found in name_type_map")
        panic()
      }
      match ty {
        Int | Int64 => self.builder.createICmpSGT(left_val, right_val)
        UInt | UInt64 => self.builder.createICmpUGT(left_val, right_val)
        Float | Double => self.builder.createFCmpUGT(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for greater-than comparison")
          panic()
        }
      }
    }
    GE => {
      guard name_type_map.get(left_name) is Some(ty) else {
        println("Compiler ICE: variable type not found in name_type_map")
        panic()
      }
      match ty {
        Int | Int64 => self.builder.createICmpSGE(left_val, right_val)
        UInt | UInt64 => self.builder.createICmpUGE(left_val, right_val)
        Float | Double => self.builder.createFCmpUGE(left_val, right_val)
        _ => {
          println(
            "Compiler ICE: unsupported type for greater-than-or-equal comparison",
          )
          panic()
        }
      }
    }
    And => self.builder.createAnd(left_val, right_val)
    Or => self.builder.createOr(left_val, right_val)
    BitAnd => self.builder.createAnd(left_val, right_val)
    BitOr => self.builder.createOr(left_val, right_val)
    ShiftLeft => self.builder.createShl(left_val, right_val)
    ShiftRight => {
      guard name_type_map.get(left_name) is Some(ty) else {
        println("Compiler ICE: variable type not found in name_type_map")
        panic()
      }
      match ty {
        Int | Int64 => self.builder.createAShr(left_val, right_val)
        UInt | UInt64 => self.builder.createLShr(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for shift right operation")
          panic()
        }
      }
    }
  }
}

///|
fn codegen_for_type(tykind : TypeKind, llvm_ctx : @IR.Context) -> &@IR.Type {
  match tykind {
    Unit => (llvm_ctx.getVoidTy() : &@IR.Type)
    Int => llvm_ctx.getInt32Ty()
    Int64 => llvm_ctx.getInt64Ty()
    UInt => llvm_ctx.getInt32Ty()
    UInt64 => llvm_ctx.getInt64Ty()
    Float => llvm_ctx.getFloatTy()
    Double => llvm_ctx.getDoubleTy()
    Bool => llvm_ctx.getInt1Ty()
    String => llvm_ctx.getPtrTy()
    Tuple(_) => llvm_ctx.getPtrTy()
    Array(_) => llvm_ctx.getPtrTy()
    Function(_, _) => llvm_ctx.getPtrTy()
    Defined(_) => {
      println("codegen for defined type not implemented yet")
      panic()
    }
  }
}
