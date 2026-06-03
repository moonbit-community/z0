///|
fn combo_arch_case_names() -> Array[String] {
  [
    "arith-lite-sat-unsat", "euf-arith-shared-enode", "euf-fake-shared-enode", "euf-arith-fake-lifecycle",
    "missing-euf-negative",
  ]
}

///|
test "combo_arch_enumerates_nonempty_phase11_cases" {
  let names = combo_arch_case_names()
  assert_true(names.length() > 0)
  inspect(names.length(), content="5")
}

///|
test "combo_arch_arith_lite_sat_unsat_and_unsupported_paths" {
  let sat = @arith_lite.ArithLiteProblem::new()
  sat.assert_ge_const("x", 1)
  sat.assert_le_const("x", 3)
  inspect(sat.check().to_text(), content="sat")
  let unsat = @arith_lite.ArithLiteProblem::new()
  unsat.assert_ge_const("x", 4)
  unsat.assert_le_const("x", 2)
  inspect(unsat.check().to_text(), content="unsat:x:lower>2")
  let unsupported = @arith_lite.ArithLiteProblem::new()
  unsupported.reject_fragment("arith_lite:add")
  inspect(
    unsupported.check().to_text(),
    content="unsupported:unsupported-fragment(arith_lite:add)",
  )
}

///|
test "combo_arch_euf_arith_and_fake_share_enode_attachments" {
  let egraph = @egraph.EGraph::new()
  let expr = @util.ExprId::new(100)
  let enode = egraph.mk_enode(expr, [], 0)
  let euf_id = @ids.TheoryId::new(1)
  let arith_id = @ids.TheoryId::new(2)
  let fake_id = @ids.TheoryId::new(3)
  egraph.attach_theory_var(enode, euf_id, @ids.TheoryVar::new(10))
  egraph.attach_theory_var(enode, arith_id, @ids.TheoryVar::new(20))
  egraph.attach_theory_var(enode, fake_id, @ids.TheoryVar::new(30))
  inspect(egraph.theory_var_text(enode, euf_id), content="v#10")
  inspect(egraph.theory_var_text(enode, arith_id), content="v#20")
  inspect(egraph.theory_var_text(enode, fake_id), content="v#30")
  inspect(egraph.theory_attachments(enode).length(), content="3")
}

///|
test "combo_arch_fact_lifecycle_reaches_arith_and_fake_plugins" {
  let view = @theory_core.TheoryContextView::new(scope_depth=1)
  let actions = @theory_core.TheoryActions::noop()
  let arith_id = @ids.TheoryId::new(4)
  let fake_id = @ids.TheoryId::new(5)
  let family = @ast.FamilyId::new(40)
  let arith = @arith_lite.arith_lite_theory_plugin(arith_id, family)
  let fake_harness = @fake_combo.FakeComboHarness::new(fake_id, family)
  let fake = fake_harness.plugin()
  let expr = @util.ExprId::new(77)
  match arith.internalize_term(view, actions, family, expr) {
    @theory_core.TheoryHandled(term) => {
      inspect(term.owner(), content="th#4")
      inspect(term.to_int(), content="77")
    }
    _ => fail("expected arith_lite to internalize the matching family")
  }
  let eq = @theory_core.EqFact::new(fake_id, 8, scope_generation=1)
  let diseq = @theory_core.DiseqFact::new(fake_id, 9, scope_generation=1)
  fake.new_eq(view, actions, eq)
  fake.new_diseq(view, actions, diseq)
  fake.init_search(view, actions)
  match fake.theory_check(view, actions) {
    @theory_core.TheoryCheckContinue => ()
    _ => fail("expected fake_combo check to request another round")
  }
  fake.init_model(view, actions)
  fake.finalize_model(view, actions)
  inspect(
    fake_harness.log_text(),
    content="new-eq:th#5:8,new-diseq:th#5:9,init-search,check,init-model,finalize-model",
  )
}

///|
test "combo_arch_missing_euf_is_typed_unknown_negative_control" {
  let reason = @util.ReasonUnknown::IncompleteTheory("euf/egraph required")
  inspect(reason.to_text(), content="incomplete-theory(euf/egraph required)")
}

///|
test "combo_arch_factories_are_selectable_without_importing_smt" {
  ignore(@default_factory.default_factory())
  ignore(@smt_adapter.default_factory())
  let arith_factory = @arith_lite.arith_lite_theory_factory(
    @ids.TheoryId::new(6),
    @ast.FamilyId::new(60),
  )
  let fake_factory = @fake_combo.fake_combo_theory_factory(
    @ids.TheoryId::new(7),
    @ast.FamilyId::new(70),
  )
  let euf_factory = @euf_solver.euf_theory_factory(
    @ids.TheoryId::new(8),
    @ast.FamilyId::new(80),
  )
  inspect(arith_factory.descriptor().name(), content="arith_lite")
  inspect(fake_factory.descriptor().name(), content="fake_combo")
  inspect(euf_factory.descriptor().name(), content="euf")
}
