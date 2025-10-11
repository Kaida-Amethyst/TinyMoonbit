
extern fn sqrt(x: Double) -> Double = "sqrt"
extern fn print_double(x: Double) -> Unit = "print_double"

struct Triangle {
  a: Double
  b: Double
  c: Double
}

fn area(t: Triangle) -> Double {
  let s = (t.a + t.b + t.c) / 2.0
  sqrt(s * (s - t.a) * (s - t.b) * (s - t.c))
}

fn main {
  let t = Triangle::{ a: 3.0, b: 4.0, c: 5.0 }
  let a = area(t)
  print_double(a)
}
