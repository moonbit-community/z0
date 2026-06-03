///|
test "arith_lite_bounds_detect_small_integer_conflicts" {
  let problem = ArithLiteProblem::new()
  problem.assert_ge_const("x", 3)
  problem.assert_le_const("x", 2)
  inspect(problem.check().to_text(), content="unsat:x:lower>2")
}

///|
test "arith_lite_equalities_and_bounds_accept_consistent_fragment" {
  let problem = ArithLiteProblem::new()
  problem.assert_eq_const("x", 3)
  problem.assert_ge_const("x", 1)
  problem.assert_le_const("x", 5)
  inspect(problem.check().to_text(), content="sat")
}

///|
test "arith_lite_reports_unsupported_out_of_fragment_terms" {
  let problem = ArithLiteProblem::new()
  problem.reject_fragment("arith_lite:add")
  inspect(
    problem.check().to_text(),
    content="unsupported:unsupported-fragment(arith_lite:add)",
  )
}

///|
test "arith_lite_theory_plugin_implements_core_contract" {
  let id = @ids.TheoryId::new(20)
  let family = @ast.FamilyId::new(30)
  let plugin = arith_lite_theory_plugin(id, family)
  let view = @theory_core.TheoryContextView::new(scope_depth=2)
  let actions = @theory_core.TheoryActions::noop()
  let expr = @util.ExprId::new(7)
  match plugin.internalize_term(view, actions, family, expr) {
    @theory_core.TheoryHandled(term) => {
      inspect(term.owner(), content="th#20")
      inspect(term.to_int(), content="7")
      inspect(term.scope_generation(), content="2")
    }
    _ => fail("expected arith_lite to handle terms in its family")
  }
  match plugin.theory_check(view, actions) {
    @theory_core.TheoryCheckDone => ()
    _ => fail("expected arith_lite check to be done")
  }
  inspect(
    plugin.collect_statistics().value_text("arith_lite.checks"),
    content="counter:1",
  )
}
