///|
test "ast_has_builtin_bool_sort" {
  let manager = AstManager::new()
  inspect(manager.bool_sort(), content="sort#0")
  inspect(manager.int_sort(), content="sort#1")
}

///|
test "ast_declare_uninterpreted_sort_arity_zero" {
  let manager = AstManager::new()
  let sort = manager.declare_sort("U", 0)
  inspect(sort, content="sort#2")
}

///|
test "ast_rejects_unsupported_sort_arity" {
  let manager = AstManager::new()
  try {
    ignore(manager.declare_sort("Vec", 1))
    inspect("missing diagnostic", content="diagnostic")
  } catch {
    @unsupported_error.UnsupportedError(_, _) as error =>
      inspect(error, content="unsupported: sort arity is not supported")
    _ => inspect("wrong diagnostic", content="unsupported")
  }
}

///|
test "ast_declare_bool_const" {
  let manager = AstManager::new()
  let decl = manager.declare_const("p", manager.bool_sort())
  inspect(decl, content="decl#0")
}

///|
test "ast_declare_uninterpreted_function" {
  let manager = AstManager::new()
  let u = manager.declare_sort("U", 0)
  let decl = manager.declare_fun("f", [u], u)
  inspect(decl, content="decl#0")
}

///|
test "ast_scope_pop_removes_declaration" {
  let manager = AstManager::new()
  manager.push_scope()
  ignore(manager.declare_const("p", manager.bool_sort()))
  manager.pop_scope(1)
  inspect(manager.lookup_decl("p") is None, content="true")
}

///|
test "ast_scope_pop_removes_macro" {
  let manager = AstManager::new()
  let truth = manager.mk_bool(true)
  manager.push_scope()
  ignore(manager.define_bool_macro("m", truth))
  manager.pop_scope(1)
  inspect(manager.lookup_macro("m") is None, content="true")
}

///|
test "ast_hash_conses_same_expr" {
  let manager = AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let n0 = manager.mk_not(p)
  let n1 = manager.mk_not(p)
  inspect(n0 == n1, content="true")
}

///|
test "ast_rejects_bad_bool_argument_sort" {
  let manager = AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a_decl = manager.declare_const("a", u)
  let a = manager.mk_app(a_decl, [])
  try {
    ignore(manager.mk_not(a))
    inspect("missing diagnostic", content="diagnostic")
  } catch {
    @type_error.TypeError(_, _) as error =>
      inspect(error, content="type: expected Bool argument")
    _ => inspect("wrong diagnostic", content="type")
  }
}

///|
test "ast_pretty_prints_bool_term" {
  let manager = AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let q_decl = manager.declare_const("q", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let q = manager.mk_app(q_decl, [])
  let not_q = manager.mk_not(q)
  let term = manager.mk_and([p, not_q])
  inspect(manager.pretty(term), content="(and p (not q))")
}
