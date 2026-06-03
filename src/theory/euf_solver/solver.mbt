///|
pub fn euf_theory_plugin(
  id : @ids.TheoryId,
  family : @ast.FamilyId,
) -> @theory_core.TheoryPlugin {
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(id, "euf", [
    family,
  ])
  plugin.set_describe_params(fn() { @params.ParamDescrs::new() })
  plugin.set_updt_params(fn(_) { @util.Available(()) })
  plugin.set_internalize_term(fn(view, actions, _, expr) {
    match actions.internalize_term_ref(expr) {
      Some(term) => @theory_core.TheoryHandled(term)
      None =>
        @theory_core.TheoryHandled(
          @theory_core.TheoryTermRef::new(
            id,
            expr.to_int(),
            scope_generation=view.scope_depth(),
          ),
        )
    }
  })
  plugin.set_internalize_atom(fn(view, actions, family, expr) {
    plugin.internalize_term(view, actions, family, expr)
  })
  plugin.set_include_func_interp(fn(_) { true })
  plugin.set_collect_statistics(fn() { @stats.Statistics::new() })
  plugin
}

///|
pub fn euf_theory_factory(
  id : @ids.TheoryId,
  family : @ast.FamilyId,
) -> @theory_core.TheoryFactory {
  @theory_core.TheoryFactory::new(
    @theory_core.TheoryFactoryDescriptor::new(
      id~,
      name="euf",
      families=[family],
      logics=["QF_UF", "QF_LIA", "QF_UFLIA", "QF_FAKE_COMBO", "ALL"],
      auto_config=true,
    ),
    fn() { euf_theory_plugin(id, family) },
  )
}
