
```moonbit skip
extern fn print_int(x:Int) -> Unit ;

fn fib(n : Int) -> Int {
  if n <= 1 {
    return n;
  }
  return fib(n - 1) + fib(n - 2);
}

fn main {
  print_int(fib(33));
}
```

```moonbit skip
extern fn print_int(x: Int) -> Unit;

fn caltz(n: Int, cnt: Int) -> Int {
  if n == 1 {
    return cnt;
  }
  if n % 2 == 0 {
    return caltz(n / 2, cnt + 1);
  }
  return caltz(3*n + 1, cnt + 1)
}

fn main {
  let n = caltz(23);
  print_int(n)
}
```

```moonbit skip
fn vec_muladd(a: Ptr[Int], b: Ptr[Int], c: Ptr[Int], len: Int) -> Ptr[Int] {
  let i: Int = 0;
  let dst : Ptr[Int] = malloc(sizeof(Int) * len) as Ptr[Int]
  while i < len {
    dst[i] = a[i] * b[i] + c[i];
  }
  return dst
}

fn main {
  let a : Array[Int] = [1, 2, 3, 4, 5];
  let b: Array[Int] = [6, 7, 8, 9, 10];
  let c: Array[Int] = [10, 11, 12, 13, 14];

  let d : Ptr[Int] = vec_muladd(a as Ptr[Int], b as Ptr[Int], c as Ptr[Int], 5);
  let i : Int = 0
  while i < 5 {
    print_int(d);
    print_endline();
  }
}
```

```moonbit skip
struct Complex {
  real: Double;
  imag: Double;
}

fn complex_add(a : Ptr[Complex], b: Ptr[Complex]) -> Ptr[Complex] {
  let c : Ptr[Complex] = malloc(sizeof(Complex)) as Ptr[Complex];
  c[0].real = a[0].real + b[0].real;
  c[0].imag = a[0].real + b[0].imag;
  return c;
}

fn main {
  let a : Complex;
  let b : Complex;

  a.real = 1.0;
  a.imag = 2.0;

  b.real = 1.0;
  b.imag = 2.0;

  let c: Ptr[Complex] = complex_add(ref a, ref b)

  print_double(c[0].real);
  print_endline();
  print_double(c[0].imag);
  print_endline();

  free(c);
}
```

```moonbit skip
struct Location {
  x : Double;
  y : Double;
}

struct Sprite {
  loc: Location;
}

fn step_forword_x(hero: Ptr[Sprite]) -> Unit {
  if hero[0].loc.x >= 400.0 {
    return ;
  }

  hero[0].loc.x = hero[0].loc.x + 1;
}

fn main {
  let s: Sprite;

  s.loc.x = 100.0;
  s.loc.y = 200.0;

  step_forword_x(ref s);

  println(s.loc.x);
}
```
