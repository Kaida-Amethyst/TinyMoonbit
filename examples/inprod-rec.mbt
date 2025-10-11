extern fn print_int(n: Int) -> Unit = "print_int";
extern fn truncate(x: Double) -> Int = "truncate";

fn inprod(v1: Array[Double], v2: Array[Double], i: Int) -> Double {
  if 0 <= i {
    v1[i] * v2[i] + inprod(v1, v2, i - 1)
  } else {
    0.0
  }
}

fn main {
  let v1 = [1.23, 1.23, 1.23];
  let v2 = [4.56, 4.56, 4.56];
  print_int(truncate(1000000.0 * inprod(v1, v2, 2)))
}
