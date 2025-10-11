extern fn print_int(n: Int) -> Unit = "print_int";

fn gcd(m: Int, n: Int) -> Int {
  if m == 0 {
    n
  } else {
    if m <= n {
      gcd(m, n - m)
    } else {
      gcd(n, m - n)
    }
  }
}

fn main {
  print_int(gcd(21600, 337500))
}
