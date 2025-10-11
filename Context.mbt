///|
pub suberror ParseError (Token, String) derive(Show)

///|
pub struct Context {
  code : String
  tokens : Array[Token]
  fatal_errors : Array[ParseError] // stop type check
  normal_errors : Array[ParseError] // stop codegen
  top_functions : Map[String, TopFunction]
  extern_functions : Map[String, ExternFunction]
  top_lets : Map[String, TopLet]
  struct_defs : Map[String, StructDef]
  builtin_non_struct_fields: Map[TypeKind, Map[String, TypeKind]]
  // enum_defs : Array[EnumDef]

  // Type Check Phase
  mut type_env : Env[String, TypeKind]
  mut current_func : TopFunction?

  // Knf Phase
  mut name_env : Env[String, Name]
  knf_top_lets : Map[String, KnfTopLet]
  knf_ext_funcs : Map[String, KnfExternFunc]
  knf_top_funcs : Map[String, KnfFunction]
  knf_struct_defs : Map[String, KnfStructDef]
  // knf_enum_defs: Map[String, KnfEnumDef]

  // codegen phase
  llvm_ctx : @IR.Context
  llvm_mod : @IR.Module
  builder : @IR.IRBuilder
  llvm_funcs : Map[String, @IR.Function]
  llvm_struct_tys: Map[String, @IR.StructType]
  llvm_global_values : Map[String, &@IR.GlobalValue]

  //
  source_file : String
}

///|
pub fn Context::new(code : String, source_file? : String = "demo") -> Context {
  let llvm_ctx = @IR.Context::new()
  let llvm_mod = llvm_ctx.addModule(source_file)
  let builder = llvm_ctx.createBuilder()
  let builtin_non_struct_fields = init_builtin_non_struct_fields()
  Context::{
    code,
    tokens: Array::new(),
    fatal_errors: Array::new(),
    normal_errors: Array::new(),
    top_functions: Map::new(),
    extern_functions: Map::new(),
    struct_defs: Map::new(),
    builtin_non_struct_fields,
    top_lets: Map::new(),
    type_env: Env::new(),
    current_func: None,
    name_env: Env::new(),
    knf_top_lets: Map::new(),
    knf_ext_funcs: Map::new(),
    knf_top_funcs: Map::new(),
    knf_struct_defs: Map::new(),
    llvm_funcs: Map::new(),
    llvm_struct_tys: Map::new(),
    llvm_global_values: Map::new(),
    llvm_ctx,
    llvm_mod,
    builder,
    source_file,
  }
}

fn init_builtin_non_struct_fields() -> Map[TypeKind, Map[String, TypeKind]] {
  let builtin_non_struct_fields :Map[TypeKind, Map[String, TypeKind]] = Map::new()

  // Int: to_float, to_int64, to_uint64, to_uint, to_double
  // reinterpret_as_float, reinterpret_as_uint
  let int_fields: Map[String, TypeKind] = Map::new()
  int_fields.set("to_float", Function([], Float))
  int_fields.set("to_int64", Function([], Int64))
  int_fields.set("to_uint64", Function([], UInt64))
  int_fields.set("to_uint", Function([], UInt))
  int_fields.set("to_double", Function([], Double))
  int_fields.set("reinterpret_as_float", Function([], Float))
  int_fields.set("reinterpret_as_uint", Function([], UInt))
  builtin_non_struct_fields.set(Int, int_fields)

  // Int64: to_float, to_int, to_uint64, to_uint, to_double
  // reinterpret_as_double, reinterpret_as_uint64
  let int64_fields: Map[String, TypeKind] = Map::new()
  int64_fields.set("to_float", Function([], Float))
  int64_fields.set("to_int", Function([], Int))
  int64_fields.set("to_uint64", Function([], UInt64))
  int64_fields.set("to_uint", Function([], UInt))
  int64_fields.set("to_double", Function([], Double))
  int64_fields.set("reinterpret_as_double", Function([], Double))
  int64_fields.set("reinterpret_as_uint64", Function([], UInt64))
  builtin_non_struct_fields.set(Int64, int64_fields)

  // Float: to_int, to_int64, to_uint64, to_uint, to_double
  // reinterpret_as_int, reinterpret_as_uint
  let float_fields: Map[String, TypeKind] = Map::new()
  float_fields.set("to_int", Function([], Int))
  float_fields.set("to_int64", Function([], Int64))
  float_fields.set("to_uint64", Function([], UInt64))
  float_fields.set("to_uint", Function([], UInt))
  float_fields.set("to_double", Function([], Double))
  float_fields.set("reinterpret_as_int", Function([], Int))
  float_fields.set("reinterpret_as_uint", Function([], UInt))
  builtin_non_struct_fields.set(Float, float_fields)

  // Double: to_int, to_int64, to_uint64, to_uint, to_float
  // reinterpret_as_int64, reinterpret_as_uint64
  let double_fields: Map[String, TypeKind] = Map::new()
  double_fields.set("to_int", Function([], Int))
  double_fields.set("to_int64", Function([], Int64))
  double_fields.set("to_uint64", Function([], UInt64))
  double_fields.set("to_uint", Function([], UInt))
  double_fields.set("to_float", Function([], Float))
  double_fields.set("reinterpret_as_int64", Function([], Int64))
  double_fields.set("reinterpret_as_uint64", Function([], UInt64))
  builtin_non_struct_fields.set(Double, double_fields)

  // UInt: to_float, to_int64, to_uint64, to_int, to_double
  // reinterpret_as_float, reinterpret_as_int
  let uint_fields: Map[String, TypeKind] = Map::new()
  uint_fields.set("to_float", Function([], Float))
  uint_fields.set("to_int64", Function([], Int64))
  uint_fields.set("to_uint64", Function([], UInt64))
  uint_fields.set("to_int", Function([], Int))
  uint_fields.set("to_double", Function([], Double))
  uint_fields.set("reinterpret_as_float", Function([], Float))
  uint_fields.set("reinterpret_as_int", Function([], Int))
  builtin_non_struct_fields.set(UInt, uint_fields)

  // UInt64: to_float, to_int64, to_uint, to_int, to_double
  // reinterpret_as_double, reinterpret_as_int64
  let uint64_fields: Map[String, TypeKind] = Map::new()
  uint64_fields.set("to_float", Function([], Float))
  uint64_fields.set("to_int64", Function([], Int64))
  uint64_fields.set("to_uint", Function([], UInt))
  uint64_fields.set("to_int", Function([], Int))
  uint64_fields.set("to_double", Function([], Double))
  uint64_fields.set("reinterpret_as_double", Function([], Double))
  uint64_fields.set("reinterpret_as_int64", Function([], Int64))
  builtin_non_struct_fields.set(UInt64, uint64_fields)

  builtin_non_struct_fields
}

///|
pub fn Context::print_knf(self : Self) -> Unit {
  let s = self.print_knf_to_string()
  println(s)
}

pub fn Context::print_knf_to_string(self : Self) -> String {
  let sb = StringBuilder::new()
  for top_let in self.knf_top_lets.values() {
    sb.write_string("\{top_let}\n\n")
  }
  for struct_def in self.knf_struct_defs.values() {
    sb.write_string("\{struct_def}\n\n")
  }
  for ext_func in self.knf_ext_funcs.values() {
    sb.write_string("\{ext_func}\n\n")
  }
  for top_func in self.knf_top_funcs.values() {
    sb.write_string("\{top_func}\n\n")
  }
  sb.to_string()
}

///|
///
/// TODO: rename to `push_type_env`
pub fn Context::push_env(self : Self) -> Unit {
  self.type_env = self.type_env.sub_env()
}

///|
///
/// TODO: rename to `pop_type_env`
pub fn Context::pop_env(self : Self) -> Unit {
  self.type_env = self.type_env.parent.unwrap()
}

///|
///
/// TODO: rename to `set_type_env`
pub fn Context::set_env(self : Self, k : String, v : TypeKind) -> Unit {
  self.type_env.set(k, v)
}

///|
pub fn Context::get_ident_type(self : Self, k : String) -> TypeKind? {
  self.type_env.get(k)
}

///|
pub fn Context::push_name_env(self : Self) -> Unit {
  self.name_env = self.name_env.sub_env()
}

///|
pub fn Context::pop_name_env(self : Self) -> Unit {
  self.name_env = self.name_env.parent.unwrap()
}

///|
pub fn Context::print_error(self : Self, err : ParseError) -> Unit {
  let ParseError((tok, msg)) = err
  let err_msg = self.get_error_msg(tok, msg)
  println(err_msg)
}

///|
pub fn Context::get_error_msg(self : Self, tok : Token, msg : String) -> String {
  let lineno = tok.lineno
  let column = tok.column
  let source_file = self.source_file
  let str_builder = StringBuilder::new()
  let color = @color.Red

  // 第一行：文件名、行号和列号
  let head_line = @color.taint(
    "[\{source_file}:\{lineno}:\{column}] Error:",
    @color.Magenta,
  )
  str_builder.write_string("\{head_line}\n")

  // 第二行：空行
  str_builder.write_string("\{lineno-1}|")
  if lineno > 1 {
    let prev_line = self.get_code_line(lineno - 1)
    str_builder.write_string("\{prev_line}\n")
  } else {
    str_builder.write_string("\n")
  }

  // 第三行：找到包含当前token的代码行
  let code_line = self.get_code_line(lineno)
  str_builder.write_string("\{lineno}|\{code_line}\n")

  // 第四行：在column位置打印`^`，然后打印msg
  let mut indent = "" // 与代码行的缩进保持一致
  for _ in 1..<column {
    indent += " "
  }
  let msg = @color.taint("^ \{msg}", color)
  str_builder.write_string("\{lineno+1}|\{indent}\{msg}\n")
  str_builder.to_string()
}

///|
fn Context::get_code_line(self : Self, lineno : Int) -> String {
  let mut lineno = lineno
  let sb = StringBuilder::new()
  for c in self.code {
    if c == '\n' {
      lineno -= 1
      if lineno == 0 {
        return sb.to_string()
      }
    } else if lineno == 1 {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
pub fn compile(code: String, source_file? : String = "demo") -> @IR.Module raise {
  let ctx = Context::new(code, source_file~)
  ctx..tokenize()
     ..parse()
     ..typecheck()
     ..knf_transform()
     
  ctx.llvm_codegen()
}
