///|
test "AtomExpr TypeCheck Test" {
  let code =
    #|1 3.14 "hello" x
  let ctx = Context::new(code)
  ctx..tokenize()
  let { tokens, .. } = ctx
  ctx.set_env("x", Int)

  // Test
  let (a, tok_view) = ctx.parse_atom_expr(tokens[:])
  let _ = ctx.type_check_atom_expr(a)
  assert_true(a.ty is Some(Int))
  let (a, tok_view) = ctx.parse_atom_expr(tok_view)
  let _ = ctx.type_check_atom_expr(a)
  assert_true(a.ty is Some(Double))
  let (a, tok_view) = ctx.parse_atom_expr(tok_view)
  let _ = ctx.type_check_atom_expr(a)
  assert_true(a.ty is Some(String))
  let (a, _) = ctx.parse_atom_expr(tok_view)
  let _ = ctx.type_check_atom_expr(a)
  assert_true(a.ty is Some(Int))
}

///|
test "ApplyExpr TypeCheck Test" {
  let code =
    #|arr[3] fib(5.0)
  let ctx = Context::new(code)
  ctx..tokenize()
  let { tokens, .. } = ctx
  ctx.set_env("arr", Array(Bool))
  ctx.set_env("fib", Function([Double], Double))

  // Test
  let (a, tok_view) = ctx.parse_apply_expr(tokens[:])
  let _ = ctx.type_check_apply_expr(a)
  assert_true(a.ty is Some(Bool))
  let (a, _) = ctx.parse_apply_expr(tok_view)
  let _ = ctx.type_check_apply_expr(a)
  assert_true(a.ty is Some(Double))
}
