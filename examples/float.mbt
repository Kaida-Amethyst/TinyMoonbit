
extern fn print_int(n: Int) -> Unit = "print_int";
extern fn int_of_float(f: Float) -> Int = "int_of_float";
extern fn float_of_int(n: Int) -> Float = "float_of_int";
extern fn abs_float(f: Float) -> Float = "abs_float";
extern fn sqrt(f: Float) -> Float = "sqrt";
extern fn sin(f: Float) -> Float = "sin";
extern fn cos(f: Float) -> Float = "cos";

fn main {
  print_int(
    int_of_float(
      (sin(cos(sqrt(abs_float(-12.3)))) + 4.5 - 6.7 * 8.9 / 1.23456789) * float_of_int(1000000)
    )
  )
}
