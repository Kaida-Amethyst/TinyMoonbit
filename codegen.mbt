
pub fn Context::llvm_codegen(self: Self) -> @IR.Module raise {
  let llvm_ctx = @IR.Context::new()
  let llvm_mod = llvm_ctx.addModule("demo") // TODO: use source file name

  // codegen for external functions
  for _, ext_fn in self.knf_ext_funcs {
    self.codegen_knf_ext_func(llvm_ctx, llvm_mod, ext_fn)
  }

  // gen function value for all top functions
  for _, top_fn in self.knf_top_funcs {
    self.codegen_knf_func_for_func_value(llvm_ctx, llvm_mod, top_fn)
  }

  llvm_mod
}

pub fn Context::codegen_knf_ext_func(self: Self, llvm_ctx: @IR.Context, llvm_mod: @IR.Module, ext_fn: KnfExternFunc) -> Unit raise {
  let argTys = ext_fn.params.map(p => codegen_for_type(p, llvm_ctx))
  let retTy = codegen_for_type(ext_fn.ty, llvm_ctx)
  let fty = llvm_ctx.getFunctionType(retTy, argTys)
  let fval = llvm_mod.addFunction(fty, ext_fn.name.to_string())
  self.llvm_funcs.set(ext_fn.name.to_string(), fval)
}

pub fn Context::codegen_knf_func_for_func_value(self: Self, llvm_ctx: @IR.Context, llvm_mod: @IR.Module, top_fn: KnfFunction) -> Unit raise {
  let argTys = top_fn.params.map(p => {
    let (_, p) = p;
    codegen_for_type(p, llvm_ctx)}
  )
  let retTy = codegen_for_type(top_fn.ty, llvm_ctx)
  let fty = llvm_ctx.getFunctionType(retTy, argTys)
  let fval = llvm_mod.addFunction(fty, top_fn.name.to_string())
  self.llvm_funcs.set(top_fn.name.to_string(), fval)
}

fn codegen_for_type(tykind: TypeKind, llvm_ctx: @IR.Context) -> &@IR.Type {
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
