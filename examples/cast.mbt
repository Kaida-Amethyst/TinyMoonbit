
extern fn print_float(f: Float) -> Unit = "print_float"

fn main {
  let mut a = 42
  print_float(a.to_float())
}
