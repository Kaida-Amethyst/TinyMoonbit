
extern fn print_int(i: Int) -> Unit = "print_int";

fn sum(start: Int, end: Int, step: Int) -> Int {
  let mut total = 0
  for i = start; i <= end; i = i +step {
    total += i
  }
  total
}

fn main {
  let result = sum(1, 2, 3, 4, 5)
  print_int(result)
}
