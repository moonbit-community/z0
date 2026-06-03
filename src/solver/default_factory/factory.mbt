///|
pub fn default_strategy_text(config : @solver.SolverFactoryConfig) -> String {
  let preprocess = @preprocess.SolverPreprocess::new(
    @smt_adapter.default_factory(),
  )
  "logic=\{config.logic()};\{preprocess.status_text()}"
}

///|
fn phase11_theory_factories(
  manager : @ast.AstManager,
) -> Array[@theory_core.TheoryFactory] {
  [
    @arith_lite.arith_lite_theory_factory(
      @theory_ids.TheoryId::new(2),
      manager.arith_family(),
    ),
    @fake_combo.fake_combo_theory_factory(
      @theory_ids.TheoryId::new(3),
      @ast.FamilyId::new(70),
    ),
  ]
}

///|
pub fn default_params_descrs() -> @params.ParamDescrs {
  @solver.SolverFactoryConfig::new().describe_params()
}

///|
pub fn default_configured_theory_names(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
) -> String {
  @smt_adapter.configured_theory_names_with_theory_factories(
    manager,
    config,
    phase11_theory_factories(manager),
  )
}

///|
pub fn default_factory() -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @preprocess.SolverPreprocess::new(
      @smt_adapter.factory_with_theory_factories(
        phase11_theory_factories(manager),
      ),
    ).create(manager, config)
  })
}
