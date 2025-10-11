
extern fn print_int(i: Int) -> Unit = "print_int";

fn array_sum(a: Array[Int]) -> Int {
  let mut sum = 0;
  for i = 0; i< 5; i = i + 1 {
    sum = sum + a[i];
  }
  sum
}

fn main {
  let a = [1, 2, 3, 4, 5];
  let sum = array_sum(a);
  print_int(sum)
}
