///|
fn bool_const(manager : @ast.AstManager, name : String) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

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
) -> @util.ExprId raise {
  manager.mk_app(decl, [arg])
}

///|
fn smt_result_text(result : SolverResult) -> String {
  match result {
    Sat => "sat"
    Unsat => "unsat"
    Unknown(reason) => "unknown: \{reason}"
  }
}

///|
test "smt_bool_sat" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(manager)
  solver.assert_expr(p)
  inspect(smt_result_text(solver.check_sat()), content="sat")
}

///|
test "smt_bool_unsat" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let not_p = manager.mk_not(p)
  let solver = Solver::new(manager)
  solver.assert_expr(p)
  solver.assert_expr(not_p)
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_euf_congruence_unsat" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let f = manager.declare_fun("f", [u], u)
  let f_a = unary_app(manager, f, a)
  let f_b = unary_app(manager, f, b)
  let equal_ab = manager.mk_eq(a, b)
  let distinct_f = manager.mk_distinct([f_a, f_b])
  let solver = Solver::new(manager)
  solver.assert_expr(equal_ab)
  solver.assert_expr(distinct_f)
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_euf_conflict_is_learned_inside_cdcl" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let c = u_const(manager, u, "c")
  let f = manager.declare_fun("f", [u], u)
  let f_a = unary_app(manager, f, a)
  let f_c = unary_app(manager, f, c)
  let solver = Solver::new(manager)
  solver.assert_expr(manager.mk_eq(a, b))
  solver.assert_expr(manager.mk_eq(b, c))
  solver.assert_expr(manager.mk_distinct([f_a, f_c]))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_euf_unconstrained_disequality_sat" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let distinct = manager.mk_distinct([a, b])
  let solver = Solver::new(manager)
  solver.assert_expr(distinct)
  inspect(smt_result_text(solver.check_sat()), content="sat")
}

///|
test "smt_mixed_conjunction_bool_conjunct_participates" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = Solver::new(manager)
  solver.assert_expr(manager.mk_and([p, manager.mk_distinct([a, b])]))
  solver.assert_expr(manager.mk_not(p))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_mixed_conjunction_euf_conjunct_participates" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = Solver::new(manager)
  solver.assert_expr(manager.mk_and([p, manager.mk_distinct([a, b])]))
  solver.assert_expr(manager.mk_eq(a, b))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_nested_mixed_conjunction_conjuncts_participate" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = Solver::new(manager)
  solver.assert_expr(
    manager.mk_and([p, manager.mk_and([q, manager.mk_distinct([a, b])])]),
  )
  solver.assert_expr(manager.mk_eq(a, b))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_negated_or_mixed_conjunction_bool_conjunct_participates" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = Solver::new(manager)
  solver.assert_expr(
    manager.mk_not(manager.mk_or([manager.mk_not(p), manager.mk_eq(a, b)])),
  )
  solver.assert_expr(manager.mk_not(p))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_negated_or_mixed_conjunction_euf_conjunct_participates" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = Solver::new(manager)
  solver.assert_expr(
    manager.mk_not(
      manager.mk_or([manager.mk_not(p), manager.mk_distinct([a, b])]),
    ),
  )
  solver.assert_expr(manager.mk_distinct([a, b]))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_negated_implies_mixed_conjunction_euf_conjunct_participates" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = Solver::new(manager)
  solver.assert_expr(manager.mk_not(manager.mk_implies(p, manager.mk_eq(a, b))))
  solver.assert_expr(manager.mk_eq(a, b))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_push_pop_assertions" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let not_p = manager.mk_not(p)
  let solver = Solver::new(manager)
  solver.assert_expr(p)
  solver.push(1)
  solver.assert_expr(not_p)
  let during = smt_result_text(solver.check_sat())
  solver.pop(1)
  let after = smt_result_text(solver.check_sat())
  inspect("\{during}->\{after}", content="unsat->sat")
}

///|
test "smt_get_model_bool_const" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(manager)
  solver.assert_expr(p)
  inspect(smt_result_text(solver.check_sat()), content="sat")
  inspect(
    solver.get_model().unwrap().format(),
    content="(\n  (define-fun p () Bool\n    true)\n)",
  )
}
