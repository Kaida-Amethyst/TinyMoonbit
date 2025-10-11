
extern fn print_int(n: Int) -> Unit = "print_int"

fn fib(n: Int) -> Int {
  if n <= 1 {
    return n;
  }
  fib(n - 1) + fib(n - 2)
}

fn main {
  let n = 10
  let res = fib(n)
  print_int(res)
}
