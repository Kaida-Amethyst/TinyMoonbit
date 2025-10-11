extern fn print_int(n: Int) -> Unit = "print_int";

fn f() -> Int {
  12345
}

fn main {
  let y = [3, 3, 3]
  let x = 67890
  print_int(if y[0] == 3 { f() + y[1] + x } else { 7 })
}
