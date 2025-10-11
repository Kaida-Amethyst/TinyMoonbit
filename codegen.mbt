///|
pub fn Context::llvm_codegen(self : Self) -> @IR.Module raise {
  // codegen for struct types
  for _, struct_def in self.knf_struct_defs {
    self.codegen_knf_struct_def(struct_def)
  }

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
  self.llvm_mod
}

///|
pub fn Context::codegen_knf_struct_def(
  self : Self,
  struct_def : KnfStructDef,
) -> Unit raise {
  let { llvm_ctx, .. } = self
  let field_tys = struct_def.fields.map(f => {
    let (_, _, field_ty) = f
    codegen_for_type(field_ty, llvm_ctx)
  })
  let struct_name = struct_def.name.to_string()
  let struct_ty = llvm_ctx.getStructType(
    field_tys,
    name=struct_def.name.to_string(),
  )
  self.llvm_struct_tys.set(struct_name, struct_ty)
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
    let (name, ty) = pair
    let llvm_param = fval.getArg(i).unwrap()
    name_value_map.set(name, llvm_param)
    name_type_map.set(name, ty)
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
    ArrayPut(array_name, index_name, value_expr) => {
      let array_val = name_value_map.get(array_name).unwrap()
      let array_ty = name_type_map.get(array_name).unwrap()
      let index_val = name_value_map.get(index_name).unwrap()

      // Load index if it's a pointer (mutable variable)
      let index_ty = name_type_map.get(index_name).unwrap()
      let index_val = match index_val.getType().asTypeEnum() {
        PointerType(_) => {
          let llvm_ty = codegen_for_type(index_ty, self.llvm_ctx)
          self.builder.createLoad(llvm_ty, index_val)
        }
        _ => index_val
      }

      // Get the value to store
      let value_val = self.codegen_knf_expr(
        value_expr, name_value_map, name_type_map,
      )

      // Arrays are stored as pointers, so we need to GEP to get the element pointer
      let elem_ty = match array_ty {
        Array(elem_ty) => elem_ty
        _ => {
          println("Compiler ICE: ArrayPut expects array type")
          panic()
        }
      }

      // Create GEP to get pointer to element
      let elem_ptr = self.builder.createGEP(
        array_val,
        codegen_for_type(elem_ty, self.llvm_ctx),
        [index_val],
      )

      // Store the value
      let _ = self.builder.createStore(value_val, elem_ptr)

    }
    ExprStmt(expr) => {
      let _ = self.codegen_knf_expr(expr, name_value_map, name_type_map)

    }
    While(cond_block, body_block) => {
      // Get the current function
      let curr_bb = self.builder.getInsertBlock()
      let func = curr_bb.getParent()

      // Create basic blocks for while loop
      let cond_bb = func.addBasicBlock()
      let body_bb = func.addBasicBlock()
      let exit_bb = func.addBasicBlock()

      // Jump to condition block
      let _ = self.builder.createBr(cond_bb)

      // Generate condition block
      self.builder.setInsertPoint(cond_bb)
      // Evaluate the condition expression
      let cond_val = self.codegen_knf_block(
        cond_block, name_value_map, name_type_map,
      )

      // The condition value should be the final expression of the condition block
      match cond_val {
        Some(cv) => {
          // Create conditional branch based on condition result
          let _ = self.builder.createCondBr(cv, body_bb, exit_bb)

        }
        None => {
          // If no condition value, this is an error
          println("Compiler ICE: While condition must return a boolean value")
          panic()
        }
      }

      // Generate body block
      self.builder.setInsertPoint(body_bb)
      let _ = self.codegen_knf_block(body_block, name_value_map, name_type_map)
      // After body, jump back to condition
      let body_end_bb = self.builder.getInsertBlock()
      if body_end_bb.getTerminator().is_empty() {
        let _ = self.builder.createBr(cond_bb)

      }

      // Move to exit block for subsequent code
      self.builder.setInsertPoint(exit_bb)
    }
    StructSet(struct_name, field_name, value_expr) => {
      let struct_val = name_value_map.get(struct_name).unwrap()
      let struct_ty = name_type_map.get(struct_name).unwrap()

      // Get the value to store
      let value_val = self.codegen_knf_expr(
        value_expr, name_value_map, name_type_map,
      )

      // Get struct definition to find field index
      guard struct_ty is Defined(type_name, _) else {
        println("Compiler ICE: StructSet expects struct type")
        panic()
      }
      guard self.knf_struct_defs.get(type_name) is Some(struct_def) else {
        println("Compiler ICE: Struct definition not found for \{type_name}")
        panic()
      }

      // Find field index
      let field_idx = struct_def.get_field_idx(field_name)
      guard field_idx is Some(field_index) else {
        println(
          "Compiler ICE: Field \{field_name} not found in struct \{type_name}",
        )
        panic()
      }

      // Create GEP to get pointer to field
      let zero = self.llvm_ctx.getConstInt32(0)
      let field_idx = self.llvm_ctx.getConstInt32(field_index)
      guard self.llvm_struct_tys.get(type_name) is Some(struct_llvm_ty) else {
        println("Compiler ICE: LLVM struct type not found for \{type_name}")
        panic()
      }
      let field_ptr = self.builder.createGEP(struct_val, struct_llvm_ty, [
        zero, field_idx,
      ])

      // Store the value
      let _ = self.builder.createStore(value_val, field_ptr)

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
pub fn Context::codegen_knf_block(
  self : Self,
  block : KnfBlock,
  name_value_map : Map[Name, &@IR.Value],
  name_type_map : Map[Name, TypeKind],
) -> &@IR.Value? raise {
  // Generate all statements in the block
  for stmt in block.stmts {
    self.codegen_knf_stmt(stmt, name_value_map, name_type_map)
  }

  // Generate the final expression and return its value
  match block.final_expr {
    Unit => None // No value to return for Unit type
    expr => {
      let val = self.codegen_knf_expr(expr, name_value_map, name_type_map)
      // Check if the value is actually void type
      if val.getType().asTypeEnum() is VoidType(_) {
        None
      } else {
        Some(val)
      }
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

      // Arrays and structs are kept as pointers
      match ty {
        Array(_) | Defined(_, _) => val
        _ =>
          // For scalar types, load if it's a pointer (mutable variable)
          match val.getType().asTypeEnum() {
            PointerType(_) => {
              let llvm_ty = codegen_for_type(ty, self.llvm_ctx)
              self.builder.createLoad(llvm_ty, val)
            }
            _ => val
          }
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
    Not(val_name) => {
      let val = name_value_map.get(val_name).unwrap()
      let ty = name_type_map.get(val_name).unwrap()
      let llvm_ty = codegen_for_type(ty, self.llvm_ctx)
      let val = match val.getType().asTypeEnum() {
        PointerType(_) => self.builder.createLoad(llvm_ty, val)
        _ => val
      }
      // use xor
      let one = self.llvm_ctx.getConstTrue()
      self.builder.createXor(val, one)
    }
    Neg(val_name) => {
      let val = name_value_map.get(val_name).unwrap()
      let ty = name_type_map.get(val_name).unwrap()
      let llvm_ty = codegen_for_type(ty, self.llvm_ctx)
      let val = match val.getType().asTypeEnum() {
        PointerType(_) => self.builder.createLoad(llvm_ty, val)
        _ => val
      }
      match ty {
        Int | Int64 | UInt | UInt64 => {
          let zero = self.llvm_ctx.getConstInt32(0)
          self.builder.createSub(zero, val)
        }
        Float | Double => {
          // TODO: use createFNeg when it available
          self.builder.createFNeg(val)
        }
        _ => {
          println("Compiler ICE: unsupported type for negation")
          panic()
        }
      }
    }
    If(cond_expr, then_block, else_block) =>
      self.codegen_knf_if_expr(
        cond_expr, then_block, else_block, name_value_map, name_type_map,
      )
    ArrayGet(array_name, index_name) => {
      let array_val = name_value_map.get(array_name).unwrap()
      let array_ty = name_type_map.get(array_name).unwrap()
      let index_val = name_value_map.get(index_name).unwrap()

      // Load index if it's a pointer (mutable variable)
      let index_ty = name_type_map.get(index_name).unwrap()
      let index_val = match index_val.getType().asTypeEnum() {
        PointerType(_) => {
          let llvm_ty = codegen_for_type(index_ty, self.llvm_ctx)
          self.builder.createLoad(llvm_ty, index_val)
        }
        _ => index_val
      }

      // Arrays are stored as pointers, so we need to GEP to get the element pointer
      // then load the value
      guard array_ty is Array(elem_ty) else {
        println("Compiler ICE: ArrayGet expects array type")
        panic()
      }

      // Create GEP to get pointer to element
      let elem_ptr = self.builder.createGEP(
        array_val,
        codegen_for_type(elem_ty, self.llvm_ctx),
        [index_val],
      )

      // Load the element value
      let elem_llvm_ty = codegen_for_type(elem_ty, self.llvm_ctx)
      self.builder.createLoad(elem_llvm_ty, elem_ptr)
    }
    Call(fname, arg_names) =>
      self.codegen_knf_call_expr(
        fname, arg_names, name_value_map, name_type_map,
      )
    CreateStruct(struct_name) => {
      guard self.llvm_struct_tys.get(struct_name) is Some(struct_ty) else {
        println("Compiler ICE: struct type not found in llvm_struct_tys")
        panic()
      }
      let struct_ptr = self.builder.createAlloca(struct_ty)
      (struct_ptr : &@IR.Value)
    }
    TupleGet(_) => {
      println("codegen for tuple get not implemented yet")
      panic()
    }
    StructGet(obj_name, field_name) =>
      self.codegen_for_struct_get(
        obj_name, field_name, name_value_map, name_type_map,
      )
    ArrayAlloc(elem_ty, size) => {
      // Allocate array on the stack
      let elem_llvm_ty = codegen_for_type(elem_ty, self.llvm_ctx)
      let array_ty = self.llvm_ctx.getArrayType(elem_llvm_ty, size)
      let array_ptr = self.builder.createAlloca(array_ty)
      (array_ptr : &@IR.Value)
    }
    TupleLiteral(_) => {
      println("codegen for tuple literal not implemented yet")
      panic()
    }
    Cast(from=from, to=to, name) => self.codegen_for_cast_expr(
      from, to, name, name_value_map, name_type_map,
    )
    BitCast(from=_, to=to, name) => {
      guard name_value_map.get(name) is Some(from_val) else {
        println("Compiler ICE: variable not found in name_value_map")
        panic()
      }
      let data_layout = self.llvm_mod.getDataLayout()
      let from_ty_bit_size = data_layout.getTypeAllocSizeInBits(from_val.getType())
      let to_ty = codegen_for_type(to, self.llvm_ctx)
      let to_ty_bit_size = data_layout.getTypeAllocSizeInBits(to_ty)
      guard from_ty_bit_size == to_ty_bit_size else {
        println("Compiler ICE: BitCast types must have the same size")
        panic()
      }
      guard to_ty.tryAsPrimitiveType() is Some(to_ty) else {
        println("Compiler ICE: BitCast to type must be a primitive type")
        panic()
      }
      self.builder.createBitCast(from_val, to_ty)
    }
  }
}

///|
pub fn Context::codegen_for_struct_get(
  self : Self,
  obj_name : Name,
  field_name : String,
  name_value_map : Map[Name, &@IR.Value],
  name_type_map : Map[Name, TypeKind],
) -> &@IR.Value raise {
  let obj_val = name_value_map.get(obj_name).unwrap()
  let obj_ty = name_type_map.get(obj_name).unwrap()

  // Get struct definition to find field index
  guard obj_ty is Defined(struct_name, _) else {
    println("Compiler ICE: StructGet expects struct type")
    panic()
  }
  guard self.knf_struct_defs.get(struct_name) is Some(struct_def) else {
    println("Compiler ICE: Struct definition not found for \{struct_name}")
    panic()
  }

  // Find field index
  let mut field_index = -1
  for i, field in struct_def.fields {
    let (fname, _, _) = field
    if fname == field_name {
      field_index = i
      break
    }
  }
  guard field_index >= 0 else {
    println(
      "Compiler ICE: Field \{field_name} not found in struct \{struct_name}",
    )
    panic()
  }

  // Get field type
  let (_, _, field_ty) = struct_def.fields[field_index]

  // Create GEP to get pointer to field
  // For structs, we need two indices: [0, field_index]
  let zero = self.llvm_ctx.getConstInt32(0)
  let field_idx = self.llvm_ctx.getConstInt32(field_index)
  guard self.llvm_struct_tys.get(struct_name) is Some(struct_llvm_ty) else {
    println("Compiler ICE: LLVM struct type not found for \{struct_name}")
    panic()
  }
  let field_ptr = self.builder.createGEP(obj_val, struct_llvm_ty, [
    zero, field_idx,
  ])

  // Load the field value
  let field_llvm_ty = codegen_for_type(field_ty, self.llvm_ctx)
  self.builder.createLoad(field_llvm_ty, field_ptr)
}

///|
pub fn Context::codegen_knf_if_expr(
  self : Self,
  cond_expr : KnfExpr,
  then_block : KnfBlock,
  else_block : KnfBlock,
  name_value_map : Map[Name, &@IR.Value],
  name_type_map : Map[Name, TypeKind],
) -> &@IR.Value raise {
  // Evaluate the condition
  let cond_val = self.codegen_knf_expr(cond_expr, name_value_map, name_type_map)

  // Get the current function
  let curr_bb = self.builder.getInsertBlock()
  let func = curr_bb.getParent()

  // Create basic blocks for then, else, and merge
  let then_bb = func.addBasicBlock()
  let else_bb = func.addBasicBlock()
  let merge_bb = func.addBasicBlock()

  // Create conditional branch
  let _ = self.builder.createCondBr(cond_val, then_bb, else_bb)

  // Generate then block
  self.builder.setInsertPoint(then_bb)
  let then_val = self.codegen_knf_block(
    then_block, name_value_map, name_type_map,
  )
  // Get the block we ended up in (might be different due to nested control flow)
  let then_end_bb = self.builder.getInsertBlock()
  // Only create branch if the block doesn't already have a terminator
  if then_end_bb.getTerminator().is_empty() {
    let _ = self.builder.createBr(merge_bb)

  }

  // Generate else block
  self.builder.setInsertPoint(else_bb)
  let else_val = self.codegen_knf_block(
    else_block, name_value_map, name_type_map,
  )
  // Get the block we ended up in
  let else_end_bb = self.builder.getInsertBlock()
  // Only create branch if the block doesn't already have a terminator
  if else_end_bb.getTerminator().is_empty() {
    let _ = self.builder.createBr(merge_bb)

  }

  // Move to merge block
  self.builder.setInsertPoint(merge_bb)

  // If both branches return values (not Unit/void), create a PHI node
  match (then_val, else_val) {
    (Some(tv), Some(ev)) => {
      // Both branches return values, create PHI node
      let phi = self.builder.createPHI(tv.getType())
      phi.addIncoming(tv, then_end_bb)
      phi.addIncoming(ev, else_end_bb)
      (phi : &@IR.Value) // Cast PHINode to Value
    }
    // One or both branches don't return a value (Unit type)
    // Return a dummy value since we need to return something
    // This should only happen when the if expression is used for side effects
    _ => (self.llvm_ctx.getConstInt32(0) : &@IR.Value)
  }
}

///|
pub fn Context::codegen_knf_call_expr(
  self : Self,
  fname : Name,
  arg_names : Array[Name],
  name_value_map : Map[Name, &@IR.Value],
  name_type_map : Map[Name, TypeKind],
) -> &@IR.Value raise {
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

    // Arrays and structs are passed by reference (as pointers)
    // Only load scalar values from pointers (mutable variables)
    match ty {
      Array(_) | Defined(_, _) =>
        // Arrays and structs are always passed as pointers
        val
      _ =>
        // For scalar types, load if it's a pointer (mutable variable)
        match val.getType().asTypeEnum() {
          PointerType(_) => {
            let llvm_ty = codegen_for_type(ty, self.llvm_ctx)
            self.builder.createLoad(llvm_ty, val)
          }
          _ => val
        }
    }
  })
  self.builder.createCall(func, arg_vals)
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

  // Load values if they are pointers (mutable variables)
  let left_ty = name_type_map.get(left_name).unwrap()
  let right_ty = name_type_map.get(right_name).unwrap()
  let left_val = match left_val.getType().asTypeEnum() {
    PointerType(_) => {
      let llvm_ty = codegen_for_type(left_ty, self.llvm_ctx)
      self.builder.createLoad(llvm_ty, left_val)
    }
    _ => left_val
  }
  let right_val = match right_val.getType().asTypeEnum() {
    PointerType(_) => {
      let llvm_ty = codegen_for_type(right_ty, self.llvm_ctx)
      self.builder.createLoad(llvm_ty, right_val)
    }
    _ => right_val
  }
  match op {
    Add =>
      match left_ty {
        Float | Double => self.builder.createFAdd(left_val, right_val)
        _ => self.builder.createAdd(left_val, right_val)
      }
    Sub =>
      match left_ty {
        Float | Double => self.builder.createFSub(left_val, right_val)
        _ => self.builder.createSub(left_val, right_val)
      }
    Mul =>
      match left_ty {
        Float | Double => self.builder.createFMul(left_val, right_val)
        _ => self.builder.createMul(left_val, right_val)
      }
    Div =>
      match left_ty {
        Int | Int64 => self.builder.createSDiv(left_val, right_val)
        UInt | UInt64 => self.builder.createUDiv(left_val, right_val)
        Float => self.builder.createFDiv(left_val, right_val)
        Double => self.builder.createFDiv(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for division")
          panic()
        }
      }
    Mod =>
      match left_ty {
        Int | Int64 => self.builder.createSRem(left_val, right_val)
        UInt | UInt64 => self.builder.createURem(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for modulus")
          panic()
        }
      }
    Eq =>
      match left_ty {
        Int | Int64 | UInt | UInt64 =>
          self.builder.createICmpEQ(left_val, right_val)
        Float | Double => self.builder.createFCmpUEQ(left_val, right_val)
        Bool => self.builder.createICmpEQ(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for equality comparison")
          panic()
        }
      }
    NE =>
      match left_ty {
        Int | Int64 | UInt | UInt64 =>
          self.builder.createICmpNE(left_val, right_val)
        Float | Double => self.builder.createFCmpUNE(left_val, right_val)
        Bool => self.builder.createICmpNE(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for inequality comparison")
          panic()
        }
      }
    LT =>
      match left_ty {
        Int | Int64 => self.builder.createICmpSLT(left_val, right_val)
        UInt | UInt64 => self.builder.createICmpULT(left_val, right_val)
        Float | Double => self.builder.createFCmpULT(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for less-than comparison")
          panic()
        }
      }
    LE =>
      match left_ty {
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
    GT =>
      match left_ty {
        Int | Int64 => self.builder.createICmpSGT(left_val, right_val)
        UInt | UInt64 => self.builder.createICmpUGT(left_val, right_val)
        Float | Double => self.builder.createFCmpUGT(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for greater-than comparison")
          panic()
        }
      }
    GE =>
      match left_ty {
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
    And => self.builder.createAnd(left_val, right_val)
    Or => self.builder.createOr(left_val, right_val)
    BitAnd => self.builder.createAnd(left_val, right_val)
    BitOr => self.builder.createOr(left_val, right_val)
    ShiftLeft => self.builder.createShl(left_val, right_val)
    ShiftRight =>
      match left_ty {
        Int | Int64 => self.builder.createAShr(left_val, right_val)
        UInt | UInt64 => self.builder.createLShr(left_val, right_val)
        _ => {
          println("Compiler ICE: unsupported type for shift right operation")
          panic()
        }
      }
  }
}

fn Context::codegen_for_cast_expr(
  self : Self,
  from : TypeKind,
  to : TypeKind,
  name : Name,
  name_value_map : Map[Name, &@IR.Value],
  name_type_map : Map[Name, TypeKind],
) -> &@IR.Value raise {
  guard name_value_map.get(name) is Some(val) else {
    println("Compiler ICE: variable not found in name_value_map")
    panic()
  }
  let ty = name_type_map.get(name).unwrap()

  // Load value if it's a pointer (mutable variable)
  let val = match val.getType().asTypeEnum() {
    PointerType(_) => {
      let llvm_ty = codegen_for_type(ty, self.llvm_ctx)
      self.builder.createLoad(llvm_ty, val)
    }
    _ => val
  }

  match (from, to) {
    (Int, Float) => self.builder.createSIToFP(val, self.llvm_ctx.getFloatTy())
    (Int, Double) => self.builder.createSIToFP(val, self.llvm_ctx.getDoubleTy())
    (UInt, Float) => self.builder.createUIToFP(val, self.llvm_ctx.getFloatTy())
    (UInt, Double) => self.builder.createUIToFP(val, self.llvm_ctx.getDoubleTy())
    (Float, Int) => self.builder.createFPToSI(val, self.llvm_ctx.getInt32Ty())
    (Double, Int) => self.builder.createFPToSI(val, self.llvm_ctx.getInt32Ty())
    (Float, UInt) => self.builder.createFPToUI(val, self.llvm_ctx.getInt32Ty())
    (Double, UInt) => self.builder.createFPToUI(val, self.llvm_ctx.getInt32Ty())
    (Int, Int64) => self.builder.createSExt(val, self.llvm_ctx.getInt64Ty())
    (UInt, UInt64) => self.builder.createZExt(val, self.llvm_ctx.getInt64Ty())
    (Int64, Int) => self.builder.createTrunc(val, self.llvm_ctx.getInt32Ty())
    (UInt64, UInt) => self.builder.createTrunc(val, self.llvm_ctx.getInt32Ty())
    _ => {
      println("Compiler ICE: unsupported cast from \{from} to \{to}")
      panic()
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
    Defined(_, _) =>
      // For structs, we return a pointer type since structs are passed by reference
      llvm_ctx.getPtrTy()
  }
}
