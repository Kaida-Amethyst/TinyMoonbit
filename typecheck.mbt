///|
pub suberror TypeCheckError String derive(Show)

pub fn Context::typecheck_program(self: Self, prog: Program) -> Unit raise TypeCheckError {
  if false {
    raise TypeCheckError("not implemented")
  }

  // 1. collect all function signatures
  for ext in prog.extern_functions {
    let { params, ret_ty, fname, .. } = ext
    let param_tys = params.map(p => p.ty)
    let fty : TypeKind = Function(param_tys, ret_ty)
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
    let param_tys = param_list.map(p => p.ty)
    let fty : TypeKind = Function(param_tys, ret_ty)
    self.type_env.set(fname, fty)
  }
}
