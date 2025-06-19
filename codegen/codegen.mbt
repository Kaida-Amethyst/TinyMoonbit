
pub struct CodeGen {
  parser_prog: @parser.Program
  llvm_ctx: @IR.LLVMContext
  llvm_prog: @IR.Program
  builder: @IR.IRBuilder
}

pub fn CodeGen::init(parser_prog: @parser.Program) -> CodeGen {
  let llvm_ctx = @IR.LLVMContext::new();
  let llvm_prog = @IR.Program::new("tinymoonbit", llvm_ctx);
  let builder = @IR.IRBuilder::new();
  CodeGen::{ parser_prog, llvm_ctx, llvm_prog, builder }
}

traitalias @IR.Type

fn CodeGen::convert_parser_type_to_llvm_type(self: Self, ty: @parser.Type) -> &Type {
  let ctx = self.llvm_ctx;
  match ty {
    Unit => ctx.getVoidTy() as &Type
    Bool => ctx.getInt1Ty()
    Int | UInt => ctx.getInt32Ty()
    Int64 | UInt64 => ctx.getInt64Ty()
    Float => ctx.getFloatTy()
    Double => ctx.getDoubleTy()
    Ptr(_) => ctx.getPtrTy()
    Array(_) => ctx.getPtrTy()
    Struct(sname) => ctx.getStructTypeByName(sname).or({
      println("Error: Struct type not found: \{sname}");
      panic()
    })
  }
}

traitalias @IR.Value

struct Env {
  gen: CodeGen
  parser_func: @parser.Function
  llvm_func: @IR.Function
  parent: Env?
  symbols: Map[String, &Value]
}

fn Env::new(gen:CodeGen, parser_func: @parser.Function, llvm_func: @IR.Function) -> Env {
  Env::{ gen, parser_func, llvm_func, parent: None, symbols: Map::new() }
}

fn Env::subenv(self: Self) -> Env {
  Env::{
    gen: self.gen,
    parser_func: self.parser_func,
    llvm_func: self.llvm_func,
    parent: Some(self),
    symbols: Map::new()
  }
}

pub fn CodeGen::run(self: Self) -> Unit raise Error {
  // collect struct definitions and functions types
  self.parser_prog.structs.values().each(
    struct_def => self.runOnStructDef(struct_def)
  )

  let llvm_funcs = Map::new()
  self.parser_prog.functions.each(
    (name, func) => llvm_funcs.set(name, self.genFuncVal(func))
  )

  for func_name in self.parser_prog.functions.keys() {
    let parser_func = self.parser_prog.functions.get(func_name).or({
      println("Error: Function not found: \{func_name}");
      panic()
    });

    let llvm_func = llvm_funcs.get(func_name).or({
      println("Error: LLVM function not found: \{func_name}");
      panic()
    });

    let env = Env::new(self, parser_func, llvm_func);
    env.runOnFunc();
  }
}

pub fn CodeGen::runOnStructDef(self: Self, struct_def: @parser.StructDef) -> Unit {
}

pub fn CodeGen::genFuncVal(self: Self, func: @parser.Function) -> @IR.Function raise Error {
  let param_tys = func.params.map(
    param_ty => {let (_, ty) = param_ty; self.convert_parser_type_to_llvm_type(ty)}
  );
  let ret_ty = self.convert_parser_type_to_llvm_type(func.ret_ty);
  let func_ty = self.llvm_ctx.getFunctionType(ret_ty, param_tys);

  self.llvm_prog.addFunction(func_ty, func.name);
}

pub fn Env::runOnFunc(self: Self) -> Unit raise Error {
  let llvm_func = self.llvm_func;
  let parser_func = self.parser_func;
  let builder = self.gen.builder;
  let entry = llvm_func.addBasicBlock(name="entry")
  builder.setInsertPoint(entry);

  parser_func.params.eachi(
    (i, name_ty) => {
      let (name, _) = name_ty;
      let param_val = llvm_func.getArg(i).unwrap()
      self.symbols.set(name, param_val);
    }
  );

  parser_func.body.each(stmt => self.runOnStmt(stmt));
}

pub fn Env::runOnStmt(self: Self, stmt: @parser.Stmt) -> Unit raise Error {
  match stmt {
    Let(name, ty, None) => {
      let data_ty = self.gen.convert_parser_type_to_llvm_type(ty);
      let alloca = self.gen.builder.createAlloca(data_ty);
      self.symbols.set(name, alloca);
    }
    Let(name, ty, Some(expr)) => {
      let data_ty = self.gen.convert_parser_type_to_llvm_type(ty);
      let alloca = self.gen.builder.createAlloca(data_ty);
      self.symbols.set(name, alloca);

      let value = self.runOnExpr(expr);
      let _ = self.gen.builder.createStore(value, alloca);
    }
    Assign(left_val, expr) => {
      let ptr = self.runOnLeftValue(left_val);
      let value = self.runOnExpr(expr);
      let _ =self.gen.builder.createStore(value, ptr);
    }
    If(cond, then_stmts, []) => {
      let cond_val = self.runOnExpr(cond);
      let then_block = self.llvm_func.addBasicBlock();
      let merge_block = self.llvm_func.addBasicBlock();

      let _ = self.gen.builder.createCondBr(cond_val, then_block, merge_block);

      self.gen.builder.setInsertPoint(then_block);
      let then_env = self.subenv();
      then_stmts.each(s => then_env.runOnStmt(s))
      let _ = self.gen.builder.createBr(merge_block);

      self.gen.builder.setInsertPoint(merge_block);
    }
    If(cond, then_stmts, else_stmts) => {
      let cond_val = self.runOnExpr(cond);
      let then_block = self.llvm_func.addBasicBlock();
      let else_block = self.llvm_func.addBasicBlock();
      let merge_block = self.llvm_func.addBasicBlock();

      let _ = self.gen.builder.createCondBr(cond_val, then_block, else_block);

      self.gen.builder.setInsertPoint(then_block);
      let then_env = self.subenv();
      then_stmts.each(s => then_env.runOnStmt(s)); 
      let _ = self.gen.builder.createBr(merge_block);

      self.gen.builder.setInsertPoint(else_block);
      let else_env = self.subenv();
      else_stmts.each(s => else_env.runOnStmt(s));
      let _ = self.gen.builder.createBr(merge_block);

      self.gen.builder.setInsertPoint(merge_block);
    }
    While(cond, stmts) => {
      let cond_block = self.llvm_func.addBasicBlock();
      let body_block = self.llvm_func.addBasicBlock();
      let merge_block = self.llvm_func.addBasicBlock();

      let cond_val = self.runOnExpr(cond);
      let _ = self.gen.builder.createCondBr(cond_val, body_block, merge_block);

      self.gen.builder.setInsertPoint(body_block);
      let body_env = self.subenv();
      stmts.each(s => body_env.runOnStmt(s));
      let _ = self.gen.builder.createBr(cond_block);

      self.gen.builder.setInsertPoint(merge_block);
    }
    Return(None) => {
      let _ = self.gen.builder.createRetVoid();
    }
    Return(Some(expr)) => {
      let value = self.runOnExpr(expr);
      let _ = self.gen.builder.createRet(value);
    }
  }
}

pub fn Env::runOnLeftValue(self: Self, left_val: @parser.LeftValue) -> &Value raise Error {
}

pub fn Env::runOnExpr(self: Self, expr: @parser.Expr) -> &Value raise Error {
}

pub fn Env::runOnApplyExpr(self: Self, apply_expr: @parser.ApplyExpr) -> &Value raise Error {
}

pub fn Env::runOnAtomExpr(self: Self, atomExpr: @parser.AtomExpr) -> &Value raise Error {
}
