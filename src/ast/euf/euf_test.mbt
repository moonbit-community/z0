///|
fn u_const(
  manager : @ast.AstManager,
  sort : @util.SortId,
  name : String,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, sort)
  manager.mk_app(decl, [])
}

///|
fn unary_app(
  manager : @ast.AstManager,
  decl : @util.FuncDeclId,
  arg : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  manager.mk_app(decl, [arg])
}

///|
fn euf_status_text(status : EufStatus) -> String {
  match status {
    EufSat => "sat"
    EufUnsat => "unsat"
  }
}

///|
test "euf_equal_constants_are_same_class" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = EufSolver::new(manager)
  solver.assert_equal(a, b)
  inspect(solver.same_class(a, b), content="true")
}

///|
test "euf_unconstrained_disequality_is_sat" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = EufSolver::new(manager)
  solver.assert_disequal(a, b)
  inspect(euf_status_text(solver.check()), content="sat")
}

///|
test "euf_congruence_conflict_unsat" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let f = manager.declare_fun("f", [u], u)
  let f_a = unary_app(manager, f, a)
  let f_b = unary_app(manager, f, b)
  let solver = EufSolver::new(manager)
  solver.assert_equal(a, b)
  solver.assert_disequal(f_a, f_b)
  inspect(euf_status_text(solver.check()), content="unsat")
}

///|
test "euf_distinct_pair_conflict_unsat" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = EufSolver::new(manager)
  solver.assert_equal(a, b)
  solver.assert_disequal(a, b)
  inspect(euf_status_text(solver.check()), content="unsat")
}

///|
test "euf_push_pop_restores_classes" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let c = u_const(manager, u, "c")
  let solver = EufSolver::new(manager)
  solver.assert_equal(a, b)
  solver.push_scope()
  solver.assert_equal(b, c)
  let during = solver.same_class(a, c)
  solver.pop_scope(1)
  let after = solver.same_class(a, c)
  inspect("\{during}->\{after}", content="true->false")
}
