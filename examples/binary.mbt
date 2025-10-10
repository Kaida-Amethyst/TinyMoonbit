
fn foo(a: Int, b: Int, c: Int, d: Int) -> Int {
  let t = a + b
  let k = c * d
  let g = t - k
  let m = a / 2

  if t > k {
    g + m 
  } else {
    g - m
  }
}

fn main {
  let _ = foo(10, 20, 5, 3)
}
