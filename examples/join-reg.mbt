extern fn print_int(n: Int) -> Unit = "print_int";

fn f() -> Int {
  123
}

fn g() -> Int {
  456
}

fn h() -> Int {
  789
}

fn main {
  let x = f();
  let y = g();
  let res = if h() == 0 { x - y } else { y - x }
  print_int(res + x + y)
}
