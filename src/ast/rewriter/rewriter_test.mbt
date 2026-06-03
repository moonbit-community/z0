///|
fn bool_const(manager : @ast.AstManager, value : Bool) -> @util.ExprId {
  manager.mk_bool(value)
}

///|
fn bool_const_decl(
  manager : @ast.AstManager,
  name : String,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
test "rewrite_not_true_to_false" {
  let manager = @ast.AstManager::new()
  let expr = manager.mk_not(bool_const(manager, true))
  let rewritten = rewrite_bool(manager, expr)
  inspect(manager.pretty(rewritten), content="false")
}

///|
test "rewrite_bool_result_carries_ast_local_metadata" {
  let manager = @ast.AstManager::new()
  let expr = manager.mk_not(bool_const(manager, true))
  let result = rewrite_bool_result(manager, expr)
  inspect(manager.pretty(result.result()), content="false")
  inspect(result.proof_text(), content="none")
  inspect(result.dependency_text(), content="none")
  inspect(result.unsupported_text(), content="none")
}

///|
test "rewrite_and_with_false_to_false" {
  let manager = @ast.AstManager::new()
  let p = bool_const_decl(manager, "p")
  let expr = manager.mk_and([p, bool_const(manager, false)])
  let rewritten = rewrite_bool(manager, expr)
  inspect(manager.pretty(rewritten), content="false")
}

///|
test "rewrite_or_with_true_to_true" {
  let manager = @ast.AstManager::new()
  let p = bool_const_decl(manager, "p")
  let expr = manager.mk_or([p, bool_const(manager, true)])
  let rewritten = rewrite_bool(manager, expr)
  inspect(manager.pretty(rewritten), content="true")
}

///|
test "rewrite_implies_to_or_form" {
  let manager = @ast.AstManager::new()
  let p = bool_const_decl(manager, "p")
  let q = bool_const_decl(manager, "q")
  let expr = manager.mk_implies(p, q)
  let rewritten = rewrite_bool(manager, expr)
  inspect(manager.pretty(rewritten), content="(or (not p) q)")
}

///|
test "rewrite_xor_constants" {
  let manager = @ast.AstManager::new()
  let p = bool_const_decl(manager, "p")
  let expr = manager.mk_xor(bool_const(manager, true), p)
  let rewritten = rewrite_bool(manager, expr)
  inspect(manager.pretty(rewritten), content="(not p)")
}

///|
test "rewrite_arith_compare_constants" {
  let manager = @ast.AstManager::new()
  let one = manager.mk_int(1)
  let two = manager.mk_int(2)
  inspect(
    manager.pretty(rewrite_bool(manager, manager.mk_lt(one, two))),
    content="true",
  )
  inspect(
    manager.pretty(rewrite_bool(manager, manager.mk_ge(one, two))),
    content="false",
  )
}

///|
test "expand_nullary_bool_macro" {
  let manager = @ast.AstManager::new()
  let p = bool_const_decl(manager, "p")
  ignore(manager.define_bool_macro("m", p))
  let macro_ref = manager.mk_macro_ref("m")
  let expanded = expand_macros(manager, macro_ref)
  inspect(manager.pretty(expanded), content="p")
}

///|
test "expand_macro_inside_assertion" {
  let manager = @ast.AstManager::new()
  let p = bool_const_decl(manager, "p")
  ignore(manager.define_bool_macro("m", p))
  let macro_ref = manager.mk_macro_ref("m")
  let expr = manager.mk_not(macro_ref)
  let expanded = expand_macros(manager, expr)
  inspect(manager.pretty(expanded), content="(not p)")
}
