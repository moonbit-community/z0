///|
fn bool_const(manager : @ast.AstManager, name : String) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
fn context_u_const(
  manager : @ast.AstManager,
  sort : @util.SortId,
  name : String,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, sort)
  manager.mk_app(decl, [])
}

///|
fn context_unary_app(
  manager : @ast.AstManager,
  decl : @util.FuncDeclId,
  arg : @util.ExprId,
) -> @util.ExprId raise {
  manager.mk_app(decl, [arg])
}

///|
fn context_result_text(result : SmtContextResult) -> String {
  match result {
    SmtContextSat(_) => "sat"
    SmtContextUnsat => "unsat"
    SmtContextUnknown(reason) => "unknown:\{reason}"
  }
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
fn smt_assumption_result_text(
  manager : @ast.AstManager,
  result : SolverAssumptionResult,
) -> String {
  match result {
    AssumptionSat => "sat"
    AssumptionUnsat(core, _) => {
      let text = [ for expr in core => manager.pretty(expr) ].join(",")
      "unsat:\{text}"
    }
    AssumptionUnknown(reason) => "unknown: \{reason}"
  }
}

///|
test "smt_context_repeated_check_reuses_sat_core_and_root_clauses" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let core_id = context.sat_core_id()
  inspect(context_result_text(context.check_sat()), content="sat")
  let after_first = context.root_clause_count()
  inspect(context_result_text(context.check_sat()), content="sat")
  inspect(context.sat_core_id(), content="\{core_id}")
  inspect(context.root_clause_count(), content="\{after_first}")
}

///|
test "smt_internalizer_reuses_bool_literal_cache" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let context = SmtContext::new(manager)
  let first = context.internalize_bool_text(p)
  let second = context.internalize_bool_text(p)
  inspect(first, content="b1")
  inspect(second, content="b1")
  inspect(context.sat_var_count(), content="1")
}

///|
test "smt_context_egraph_euf_detects_congruence_conflict" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = context_u_const(manager, u, "a")
  let b = context_u_const(manager, u, "b")
  let f = manager.declare_fun("f", [u], u)
  let f_a = context_unary_app(manager, f, a)
  let f_b = context_unary_app(manager, f, b)
  let context = SmtContext::new(manager)
  context.assert_expr(manager.mk_eq(a, b))
  context.assert_expr(manager.mk_distinct([f_a, f_b]))
  inspect(context_result_text(context.check_sat()), content="unsat")
}

///|
test "smt_context_egraph_euf_scoped_pop_restores_diseq_conflict" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = context_u_const(manager, u, "a")
  let b = context_u_const(manager, u, "b")
  let context = SmtContext::new(manager)
  context.assert_expr(manager.mk_eq(a, b))
  context.push()
  context.assert_expr(manager.mk_distinct([a, b]))
  inspect(context_result_text(context.check_sat()), content="unsat")
  context.pop(1)
  inspect(context_result_text(context.check_sat()), content="sat")
}

///|
test "smt_solver_root_bool_checks_use_persistent_context" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(manager)
  solver.assert_expr(p)
  let core_id = solver.context_sat_core_id()
  inspect(smt_result_text(solver.check_sat()), content="sat")
  let after_first = solver.context_root_clause_count()
  inspect(smt_result_text(solver.check_sat()), content="sat")
  inspect(solver.context_sat_core_id(), content="\{core_id}")
  inspect(solver.context_root_clause_count(), content="\{after_first}")
}

///|
test "smt_solver_scoped_bool_checks_use_persistent_context" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(manager)
  solver.assert_expr(p)
  inspect(smt_result_text(solver.check_sat()), content="sat")
  let root_count = solver.context_root_clause_count()
  solver.push(1)
  solver.assert_expr(manager.mk_not(p))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
  inspect(solver.context_root_clause_count() > root_count, content="true")
  solver.pop(1)
  inspect(smt_result_text(solver.check_sat()), content="sat")
  inspect(solver.context_root_clause_count(), content="\{root_count}")
}

///|
test "smt_solver_pending_outer_assertion_survives_scoped_check" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(manager)
  solver.assert_expr(p)
  solver.push(1)
  inspect(smt_result_text(solver.check_sat()), content="sat")
  solver.pop(1)
  solver.assert_expr(manager.mk_not(p))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
}

///|
test "smt_solver_bool_macro_uses_persistent_internalizer" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let r = bool_const(manager, "r")
  ignore(
    manager.define_bool_macro(
      "conjecture",
      manager.mk_implies(
        manager.mk_and([manager.mk_implies(p, q), manager.mk_implies(q, r)]),
        manager.mk_implies(p, r),
      ),
    ),
  )
  let solver = Solver::new(manager)
  solver.assert_expr(manager.mk_not(manager.mk_macro_ref("conjecture")))
  inspect(smt_result_text(solver.check_sat()), content="unsat")
  inspect(solver.context_root_clause_count() > 0, content="true")
}

///|
test "smt_solver_check_sat_assuming_rolls_back_non_literal_assumption_clauses" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let solver = Solver::new(manager)
  solver.assert_expr(p)
  inspect(smt_result_text(solver.check_sat()), content="sat")
  let root_count = solver.context_root_clause_count()
  let assumption = manager.mk_and([q, manager.mk_not(p)])
  inspect(
    smt_assumption_result_text(manager, solver.check_sat_assuming([assumption])),
    content="unsat:(and q (not p))",
  )
  inspect(solver.context_root_clause_count(), content="\{root_count}")
  inspect(smt_result_text(solver.check_sat()), content="sat")
}
