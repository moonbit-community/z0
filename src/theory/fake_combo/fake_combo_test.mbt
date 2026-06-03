///|
test "fake_combo_harness_records_shared_lifecycle_callbacks" {
  let id = @ids.TheoryId::new(21)
  let family = @ast.FamilyId::new(31)
  let harness = FakeComboHarness::new(id, family)
  let plugin = harness.plugin()
  let view = @theory_core.TheoryContextView::new(scope_depth=1)
  let actions = @theory_core.TheoryActions::noop()
  plugin.init_search(view, actions)
  plugin.new_eq(
    view,
    actions,
    @theory_core.EqFact::new(id, 4, scope_generation=1),
  )
  plugin.new_diseq(
    view,
    actions,
    @theory_core.DiseqFact::new(id, 5, scope_generation=1),
  )
  ignore(plugin.theory_check(view, actions))
  plugin.init_model(view, actions)
  plugin.finalize_model(view, actions)
  inspect(
    harness.log_text(),
    content="init-search,new-eq:th#21:4,new-diseq:th#21:5,check,init-model,finalize-model",
  )
}

///|
test "fake_combo_plugin_exposes_params_stats_and_continue_check" {
  let plugin = fake_combo_theory_plugin(
    @ids.TheoryId::new(22),
    @ast.FamilyId::new(32),
  )
  let view = @theory_core.TheoryContextView::new(scope_depth=0)
  let actions = @theory_core.TheoryActions::noop()
  match plugin.theory_check(view, actions) {
    @theory_core.TheoryCheckContinue => ()
    _ => fail("expected fake_combo check to request another round")
  }
  inspect(
    plugin.collect_statistics().value_text("fake_combo.checks"),
    content="counter:1",
  )
}
