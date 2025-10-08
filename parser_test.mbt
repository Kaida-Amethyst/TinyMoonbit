///|
test "Type Parsing" {
  let code =
    #|Unit Int Int64 Bool UInt UInt64
    #|Float Double (Double, Int64)
    #|(Int) -> Int Array[Int] Point
    #|Map[K, V] Int
  let ctx = Context::new(code)
  ctx..tokenize()
  let { tokens, .. } = ctx
  let (ty, tok_view) = ctx.parse_type(tokens[:])
  assert_true(ty is { kind: Unit, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Int, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Int64, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Bool, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: UInt, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: UInt64, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Float, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Double, .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Tuple(_), .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Function(_), .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Array(_), .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Defined(_), .. })
  let (ty, tok_view) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Defined(_), .. })
  let (ty, _) = ctx.parse_type(tok_view)
  assert_true(ty is { kind: Int, .. })
}

///|
test "Param Parsing" {
  let code =
    #|a: Int b: Float
    #|c: Double foo: String 
    #|arr: Array[Double]
    #|map: Map[String, Int]
  let ctx = Context::new(code)
  ctx..tokenize()
  let { tokens, .. } = ctx
  let (param, tok_view) = ctx.parse_param(tokens[:])
  assert_true(param is { name: "a", ty: { kind: Int, .. }, .. })
  let (param, tok_view) = ctx.parse_param(tok_view)
  assert_true(param is { name: "b", ty: { kind: Float, .. }, .. })
  let (param, tok_view) = ctx.parse_param(tok_view)
  assert_true(param is { name: "c", ty: { kind: Double, .. }, .. })
  let (param, tok_view) = ctx.parse_param(tok_view)
  assert_true(param is { name: "foo", ty: { kind: String, .. }, .. })
  let (param, tok_view) = ctx.parse_param(tok_view)
  assert_true(
    param is { name: "arr", ty: { kind: Array({ kind: Double, .. }), .. }, .. },
  )
  let (param, _) = ctx.parse_param(tok_view)
  assert_true(param.name is "map")
  assert_true(
    param.ty.kind is Defined("Map", [{ kind: String, .. }, { kind: Int, .. }]),
  )
}

///|
test "Param List Parsing" {
  let code = "(a: Int, b: Float, c: Double,)"
  let ctx = Context::new(code)
  ctx..tokenize()
  let { tokens, .. } = ctx
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens]
  let (params, tok_view) = ctx.parse_param_list(tokens)
  assert_true(params.length() is 3)
  assert_true(params[0] is { name: "a", ty: { kind: Int, .. }, .. })
  assert_true(params[1] is { name: "b", ty: { kind: Float, .. }, .. })
  assert_true(params[2] is { name: "c", ty: { kind: Double, .. }, .. })
  assert_true(tok_view is [{ kind: Bracket(')'), .. }, ..])
}

test "AtomExpr Parsing" {
  let code = 
    #|42 3.14 true false "hello"
    #|foo bar

  let ctx = Context::new(code)
  ctx..tokenize()
  let { tokens, .. } = ctx

  let (a, tok_view) = ctx.parse_atom_expr(tokens[:])
  assert_true(a is { kind: Int(42), .. })
  let (a, tok_view) = ctx.parse_atom_expr(tok_view)
  assert_true(a is { kind: Double(3.14), .. })
  let (a, tok_view) = ctx.parse_atom_expr(tok_view)
  assert_true(a is { kind: Bool(true), .. })
  let (a, tok_view) = ctx.parse_atom_expr(tok_view)
  assert_true(a is { kind: Bool(false), .. })
  let (a, tok_view) = ctx.parse_atom_expr(tok_view)
  assert_true(a is { kind: String("hello"), .. })
  let (a, tok_view) = ctx.parse_atom_expr(tok_view)
  assert_true(a is { kind: Ident("foo"), .. })
  let (a, _) = ctx.parse_atom_expr(tok_view)
  assert_true(a is { kind: Ident("bar"), .. })
}

test "ApplyExpr Parsing" {
  let code = 
    #|42 true
    #|x y
    #|arr[1] vec[7]
    #|tup.2 pt.8
    #|obj.field list.next
    #|add(1, 2) fact(3)

  let ctx = Context::new(code)
  ctx..tokenize()
  let { tokens, .. } = ctx

  let (e, tok_view) = ctx.parse_apply_expr(tokens[:])
  assert_true(e.kind is AtomExpr(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is AtomExpr(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is AtomExpr(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is AtomExpr(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is ArrayAccess(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is ArrayAccess(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is TupleAccess(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is TupleAccess(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is FieldAccess(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is FieldAccess(_))
  let (e, tok_view) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is Call(_))
  let (e, _) = ctx.parse_apply_expr(tok_view)
  assert_true(e.kind is Call(_))
}
