
extern fn print_int(i: Int) -> Unit = "print_int";

fn ret42() -> Int {
  42
}

fn main {
  let v = ret42();
  print_int(v)
}
