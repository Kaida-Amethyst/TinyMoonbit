extern "C" fn print_int(n: Int) -> Unit = "print_int"

fn max(a: Int, b: Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

fn main {
  let a = 10
  let b = 20
  let m = max(a, b)
  print_int(m)
}
