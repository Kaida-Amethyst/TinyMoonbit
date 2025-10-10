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
  // enum_defs : Array[EnumDef]

  // Type Check Phase
  mut type_env : Env[String, TypeKind]
  mut current_func : TopFunction?

  // Knf Phase
  mut name_env : Env[String, Name]

  //
  source_file : String
}

///|
pub fn Context::new(code : String, source_file? : String = "demo") -> Context {
  Context::{
    code,
    tokens: Array::new(),
    fatal_errors: Array::new(),
    normal_errors: Array::new(),
    top_functions: Map::new(),
    extern_functions: Map::new(),
    struct_defs: Map::new(),
    top_lets: Map::new(),
    type_env: Env::new(),
    current_func: None,
    name_env: Env::new(),
    source_file,
  }
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
