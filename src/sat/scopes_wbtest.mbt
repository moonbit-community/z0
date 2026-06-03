///|
fn assumption_result_text(result : AssumptionCheckResult) -> String {
  match result {
    AssumptionSat(_) => "sat"
    AssumptionUnsat(core) => "unsat:\{core.text()}"
    AssumptionUnknown(reason) => "unknown:\{reason}"
  }
}

///|
test "sat_core_user_pop_deletes_guarded_scope_clauses" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  solver.user_push()
  ignore(solver.add_clause(Clause::unit(Literal::pos(p))))
  inspect(solver.user_scope_depth(), content="1")
  inspect(solver.inspect_state().root_clauses, content="1")
  inspect(result_text(solver.check()), content="sat")
  solver.user_pop(1)
  inspect(solver.user_scope_depth(), content="0")
  inspect(solver.inspect_state().root_clauses, content="0")
  inspect(solver.inspect_state().deleted_clauses, content="1")
  ignore(solver.add_clause(Clause::unit(Literal::neg(p))))
  inspect(result_text(solver.check()), content="sat")
}

///|
test "sat_core_pop_removes_learned_clauses_that_reference_popped_guards" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  solver.user_push()
  ignore(solver.add_clause(Clause::unit(Literal::pos(p))))
  ignore(solver.add_clause(Clause::unit(Literal::neg(p))))
  inspect(result_text(solver.check()), content="unsat")
  inspect(solver.inspect_state().learned_clauses > 0, content="true")
  solver.user_pop(1)
  let after_pop = solver.inspect_state()
  inspect(after_pop.root_clauses, content="0")
  inspect(after_pop.learned_clauses, content="0")
  inspect(result_text(solver.check()), content="sat")
}

///|
test "sat_core_assumption_core_contains_only_input_assumptions" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let q = solver.add_var()
  ignore(solver.add_clause(Clause::new([Literal::pos(p), Literal::pos(q)])))
  inspect(
    assumption_result_text(solver.check_with_assumptions([Literal::neg(p)])),
    content="sat",
  )
  inspect(
    assumption_result_text(
      solver.check_with_assumptions([Literal::neg(p), Literal::neg(q)]),
    ),
    content="unsat:[not b1, not b2]",
  )
}

///|
test "sat_core_assumption_core_drops_irrelevant_assumptions" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let q = solver.add_var()
  ignore(solver.add_clause(Clause::unit(Literal::pos(p))))
  inspect(
    assumption_result_text(
      solver.check_with_assumptions([Literal::neg(p), Literal::neg(q)]),
    ),
    content="unsat:[not b1]",
  )
}
