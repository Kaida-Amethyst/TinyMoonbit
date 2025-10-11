
extern fn print_int(n: Int) -> Unit = "print_int";

fn f(n: Int) -> Unit {
  print_int(n)
  if n > 0 {
    let a = [f]
    let a0 = a[0];
    a0(n - 1)
  }
}

fn main{
  f(9)
}
