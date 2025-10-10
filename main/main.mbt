/////|
//fnalias @TinyMoonbit.lex
//
/////|
//typealias @TinyMoonbit.(Program, TypeCheck, CodeGen)
//
/////|
//let code1 : String =
//  #| extern fn print_int(x : Int) -> Unit;
//  #|
//  #| fn fib(n : Int) -> Int {
//  #|   if n <= 1 {
//  #|     return n;
//  #|   }
//  #|   return fib(n - 1) + fib(n - 2);
//  #| }
//  #|
//  #| fn main {
//  #|   print_int(fib(10));
//  #| }
//
/////|
//let code2 : String =
//  #|extern fn print_int(x: Int) -> Unit;
//  #|
//  #|fn caltz(n: Int, cnt: Int) -> Int {
//  #|  if n == 1 {
//  #|    return cnt;
//  #|  }
//  #|  if n % 2 == 0 {
//  #|    return caltz(n / 2, cnt + 1);
//  #|  }
//  #|  return caltz(3*n + 1, cnt + 1);
//  #|}
//  #|
//  #|fn main {
//  #|  let n : Int = caltz(23, 0);
//  #|  print_int(n);
//  #|}
//
/////|
//let code3 : String =
//  #|extern fn malloc(size: Int) -> Ptr[Unit];
//  #|extern fn print_int(x: Int) -> Unit;
//  #|extern fn print_endline() -> Unit;
//  #|
//  #|fn vec_muladd(a: Ptr[Int], b: Ptr[Int], c: Ptr[Int], len: Int) -> Ptr[Int] {
//  #|  let i: Int = 0;
//  #|  let dst : Ptr[Int] = malloc(sizeof(Int) * len) as Ptr[Int];
//  #|  while i < len {
//  #|    dst[i] = a[i] * b[i] + c[i];
//  #|  }
//  #|  return dst;
//  #|}
//  #|
//  #|fn main {
//  #|  let a : Array[Int] = [1, 2, 3, 4, 5];
//  #|  let b: Array[Int] = [6, 7, 8, 9, 10];
//  #|  let c: Array[Int] = [10, 11, 12, 13, 14];
//  #|
//  #|  let d : Ptr[Int] = vec_muladd(a as Ptr[Int], b as Ptr[Int], c as Ptr[Int], 5);
//  #|  let i : Int = 0;
//  #|  while i < 5 {
//  #|    print_int(d[i]);
//  #|    print_endline();
//  #|  }
//  #|}
//
/////|
//fn test_code(code : String) -> Unit raise {
//  let prog = Program::parse(lex(code))
//  let _ = TypeCheck::check_prog(prog)
//  let codegen = CodeGen::init(prog)
//  match (try? codegen.emitProg()) {
//    Ok(_) => ()
//    Err(e) => println("Error during code generation: \{e}")
//  }
//  codegen.dump()
//}
//
/////|
//fn main {
//  match (try? test_code(code1)) {
//    Ok(_) => ()
//    Err(e) => println("Error during test execution: \{e}")
//  }
//  //let code = "fn add(x: Int, y: Int) -> Int { return x + y; }";
//  //let prog = (try? Program::parse(lex(code))).unwrap()
//  //let _ = (try? TypeCheck::check_prog(prog)).unwrap()
//  //println(prog.to_json().stringify())
//}
//

///|
//test {
//  ignore(code1)
//  ignore(code2)
//  ignore(code3)
//}

fn main {
  let help_info =
    #|Usage: tmbt [options]
    #|
    #|Options:
    #|  -h, --help            Show this help message
    #|  -f, --file <file>     Specify the input TinyMoonbit source file (Must provide)
    #|  -stop-after=parse     Stop after parsing
  let args = @env.args()
  if args.contains("-h") || args.contains("--help") {
    println(help_info)
    return
  }
  let fidx = args.search_by(arg => arg is "-f" || arg is "--file")
  let code = match fidx {
    Some(idx) if idx + 1 < args.length() => {
      let filename = args[idx + 1]
      let code = @fs.read_file_to_string(filename) catch {
        err => {
          println("Error reading file '\{filename}': \{err}")
          return
        }
      }
      code
    }
    Some(_) => {
      println("Error: No file specified after -f/--file option.")
      return
    }
    None => {
      println(
        "Error: No input file specified. Use -f or --file to specify the source file.",
      )
      println(help_info)
      return
    }
  }
  let ctx = @TinyMoonBit.Context::new(code)
  ctx.tokenize() catch {
    err => {
      println("Lexing error: \{err}")
      return
    }
  }
  ctx.parse() catch {
    err => {
      ctx.print_error(err)
      return
    }
  }
  if args.contains("-stop-after=parse") {
    println("Parsed AST:")
    println(ctx.top_lets)
    println(ctx.extern_functions)
    println(ctx.top_functions)
    println(ctx.struct_defs)
    return
  }

  // dummy
  println(ctx.top_lets)
  println(ctx.extern_functions)
  println(ctx.top_functions)
  println(ctx.struct_defs)
}
