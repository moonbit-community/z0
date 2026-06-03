///|
fn result_text(result : SatCoreResult) -> String {
  match result {
    SatCoreSat(_) => "sat"
    SatCoreUnsat => "unsat"
    SatCoreUnknown(reason) => "unknown:\{reason}"
  }
}

///|
test "sat_core_literals_clauses_and_events_are_sat_local" {
  let p = BoolVar::new(1)
  let q = BoolVar::new(2)
  inspect(p, content="b1")
  inspect(Literal::pos(p), content="b1")
  inspect(Literal::neg(q).negate(), content="b2")
  inspect(Literal::from_index(3), content="not b2")
  let clause = Clause::new([Literal::pos(p), Literal::pos(p), Literal::neg(q)])
  inspect(clause, content="[b1, not b2]")
  inspect(
    Clause::new([Literal::pos(p), Literal::neg(p)]).is_tautology(),
    content="true",
  )
  let db = ClauseDb::new()
  let id = db.add_root_clause(clause)
  inspect(id, content="clause#0")
  inspect(db.root_clause_count(), content="1")
  inspect(db.learned_clause_count(), content="0")
  inspect(db.event_log_text(), content="add clause#0 asserted input")
}

///|
test "sat_core_repeated_check_preserves_learned_activity_and_phase" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let q = solver.add_var()
  ignore(solver.add_clause(Clause::new([Literal::pos(p), Literal::pos(q)])))
  ignore(solver.add_clause(Clause::new([Literal::pos(p), Literal::neg(q)])))
  ignore(solver.add_clause(Clause::new([Literal::neg(p), Literal::pos(q)])))
  ignore(solver.add_clause(Clause::new([Literal::neg(p), Literal::neg(q)])))
  inspect(result_text(solver.check()), content="unsat")
  let first = solver.inspect_state()
  inspect(first.learned_clauses > 0, content="true")
  inspect(first.decisions > 0, content="true")
  solver.reset_search_state()
  let after_reset = solver.inspect_state()
  inspect(after_reset.learned_clauses == first.learned_clauses, content="true")
  inspect(after_reset.activity_text == first.activity_text, content="true")
  inspect(after_reset.phase_text == first.phase_text, content="true")
  inspect(result_text(solver.check()), content="unsat")
  let repeated = solver.inspect_state()
  inspect(repeated.learned_clauses >= first.learned_clauses, content="true")
}

///|
test "sat_core_statistics_report_persistent_solver_state" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  ignore(solver.add_clause(Clause::unit(Literal::pos(p))))
  inspect(result_text(solver.check()), content="sat")
  let snapshot = solver.inspect_state()
  inspect(snapshot.vars, content="1")
  inspect(snapshot.root_clauses, content="1")
  inspect(snapshot.decisions, content="0")
  inspect(snapshot.propagations, content="1")
  let stats = solver.collect_statistics()
  inspect(
    stats.keys_text(),
    content="sat.core.vars,sat.core.clauses,sat.core.decisions,sat.core.propagations,sat.core.deleted_clauses,sat.core.learned_clauses",
  )
}
