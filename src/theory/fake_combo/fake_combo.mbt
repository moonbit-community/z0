///|
pub fn fake_combo_param_descrs() -> @params.ParamDescrs {
  let descrs = @params.ParamDescrs::new()
  descrs.add_bool(
    "fake_combo.enabled", true, "fake_combo", "enable the test-only combo lifecycle theory",
  )
  descrs
}

///|
pub fn fake_combo_theory_plugin(
  id : @ids.TheoryId,
  family : @ast.FamilyId,
) -> @theory_core.TheoryPlugin {
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    id,
    "fake_combo",
    [family],
  )
  plugin.set_describe_params(fn() { fake_combo_param_descrs() })
  plugin.set_updt_params(fn(_) { @util.Available(()) })
  plugin.set_internalize_term(fn(view, _, _, expr) {
    @theory_core.TheoryHandled(
      @theory_core.TheoryTermRef::new(
        id,
        expr.to_int(),
        scope_generation=view.scope_depth(),
      ),
    )
  })
  plugin.set_internalize_atom(fn(view, actions, family, expr) {
    plugin.internalize_term(view, actions, family, expr)
  })
  plugin.set_theory_check(fn(_, _) { @theory_core.TheoryCheckContinue })
  plugin.set_validate_model(fn(_, _, _) { @util.Available(()) })
  plugin.set_validate_unsat_core(fn(_, _) { @util.Available(()) })
  plugin.set_collect_statistics(fn() {
    let statistics = @stats.Statistics::new()
    statistics.inc_counter("fake_combo.checks", 1)
    statistics
  })
  plugin
}

///|
pub fn fake_combo_theory_factory(
  id : @ids.TheoryId,
  family : @ast.FamilyId,
) -> @theory_core.TheoryFactory {
  @theory_core.TheoryFactory::new(
    @theory_core.TheoryFactoryDescriptor::new(
      id~,
      name="fake_combo",
      families=[family],
      logics=["QF_FAKE_COMBO"],
      auto_config=false,
    ),
    fn() { fake_combo_theory_plugin(id, family) },
  )
}

///|
pub struct FakeComboHarness {
  priv plugin : @theory_core.TheoryPlugin
  priv log : Array[String]
}

///|
pub fn FakeComboHarness::new(
  id : @ids.TheoryId,
  family : @ast.FamilyId,
) -> FakeComboHarness {
  let log : Array[String] = []
  let plugin = fake_combo_theory_plugin(id, family)
  plugin.set_new_eq(fn(_, _, fact) { log.push("new-eq:\{fact}") })
  plugin.set_new_diseq(fn(_, _, fact) { log.push("new-diseq:\{fact}") })
  plugin.set_init_search(fn(_, _) { log.push("init-search") })
  plugin.set_theory_check(fn(_, _) {
    log.push("check")
    @theory_core.TheoryCheckContinue
  })
  plugin.set_init_model(fn(_, _) { log.push("init-model") })
  plugin.set_finalize_model(fn(_, _) { log.push("finalize-model") })
  { plugin, log }
}

///|
pub fn FakeComboHarness::plugin(
  self : FakeComboHarness,
) -> @theory_core.TheoryPlugin {
  self.plugin
}

///|
pub fn FakeComboHarness::log_text(self : FakeComboHarness) -> String {
  self.log.join(",")
}
