///|
fn euf_result_text(result : @theory_core.TheoryInternalizeResult) -> String {
  match result {
    @theory_core.TheoryHandled(term) =>
      "handled:\{term.owner()}:\{term.to_int()}:\{term.is_valid_at(2)}"
    @theory_core.TheoryNotOwned => "not-owned"
    @theory_core.TheoryUnsupported(reason) => "unsupported:\{reason.to_text()}"
  }
}

///|
fn euf_unit_availability_text(result : @util.Availability[Unit]) -> String {
  match result {
    @util.Available(_) => "available"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
test "euf_theory_factory_internalizes_uninterpreted_terms" {
  let id = @ids.TheoryId::new(1)
  let family = @ast.FamilyId::new(1)
  let plugin = euf_theory_plugin(id, family)
  let view = @theory_core.TheoryContextView::new(scope_depth=2)
  let actions = @theory_core.TheoryActions::noop()
  inspect(
    euf_result_text(
      plugin.internalize_term(view, actions, family, @util.ExprId::new(42)),
    ),
    content="handled:th#1:42:true",
  )
  inspect(
    euf_result_text(
      plugin.internalize_term(
        view,
        actions,
        @ast.FamilyId::new(99),
        @util.ExprId::new(42),
      ),
    ),
    content="not-owned",
  )
}

///|
test "euf_theory_factory_descriptor_is_injectable" {
  let factory = euf_theory_factory(@ids.TheoryId::new(2), @ast.FamilyId::new(1))
  inspect(factory.descriptor().name(), content="euf")
  inspect(factory.descriptor().matches_logic("QF_UF"), content="true")
  inspect(factory.descriptor().auto_config(), content="true")
}

///|
test "euf_theory_plugin_includes_uninterpreted_function_interps" {
  let plugin = euf_theory_plugin(@ids.TheoryId::new(3), @ast.FamilyId::new(1))
  inspect(plugin.include_func_interp(@util.FuncDeclId::new(9)), content="true")
}

///|
test "euf_theory_plugin_params_contract_is_explicit_noop" {
  let plugin = euf_theory_plugin(@ids.TheoryId::new(4), @ast.FamilyId::new(1))
  let descrs = plugin.describe_params()
  inspect(descrs.keys_text(), content="")
  inspect(
    euf_unit_availability_text(plugin.updt_params(@params.Params::new(descrs))),
    content="available",
  )
}

///|
test "euf_model_obligations_and_proof_hints_are_opaque_placeholders" {
  let id = @ids.TheoryId::new(3)
  let term = @theory_core.TheoryTermRef::new(id, 7, scope_generation=1)
  let obligations = EufModelObligations::new()
  obligations.add_uninterpreted_value(term)
  obligations.add_function_obligation(@util.FuncDeclId::new(9))
  inspect(obligations.summary_text(), content="values=1,functions=1")
  let hints = EufProofHints::new()
  let hint = hints.add_congruence(id, "cc")
  inspect(
    "\{hint.owner()}:\{hint.to_int()}:\{hints.kind_text(hint)}",
    content="th#3:0:congruence(cc)",
  )
}
