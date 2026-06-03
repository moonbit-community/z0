///|
fn theory_result_text(result : TheoryInternalizeResult) -> String {
  match result {
    TheoryHandled(term) => "handled:\{term}"
    TheoryNotOwned => "not-owned"
    TheoryUnsupported(reason) => "unsupported:\{reason.to_text()}"
  }
}

///|
fn theory_check_text(result : TheoryCheckResult) -> String {
  match result {
    TheoryCheckContinue => "continue"
    TheoryCheckDone => "done"
    TheoryCheckGiveUp(reason) => "give-up:\{reason.to_text()}"
  }
}

///|
fn theory_unit_availability_text(result : @util.Availability[Unit]) -> String {
  match result {
    @util.Available(_) => "available"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
test "theory_plugin_default_distinguishes_not_owned_from_unimplemented_owner" {
  let plugin = TheoryPlugin::default_unimplemented(
    @ids.TheoryId::new(2),
    "fake",
    [@ast.FamilyId::new(7)],
  )
  let view = TheoryContextView::new(scope_depth=0)
  let actions = TheoryActions::noop()
  inspect(
    theory_result_text(
      plugin.internalize_term(
        view,
        actions,
        @ast.FamilyId::new(9),
        @util.ExprId::new(1),
      ),
    ),
    content="not-owned",
  )
  inspect(
    theory_result_text(
      plugin.internalize_term(
        view,
        actions,
        @ast.FamilyId::new(7),
        @util.ExprId::new(1),
      ),
    ),
    content="unsupported:unsupported-fragment(fake:internalize-term)",
  )
  inspect(theory_check_text(plugin.theory_check(view, actions)), content="done")
}

///|
test "theory_plugin_params_hooks_default_and_callbacks" {
  let plugin = TheoryPlugin::default_unimplemented(
    @ids.TheoryId::new(9),
    "fake-params",
    [@ast.FamilyId::new(9)],
  )
  inspect(plugin.describe_params().keys_text(), content="")
  inspect(
    theory_unit_availability_text(
      plugin.updt_params(@params.Params::new(plugin.describe_params())),
    ),
    content="available",
  )
  let log : Array[String] = []
  plugin.set_configure(fn(params) {
    match params.get_bool("theory.fake.enabled") {
      @util.Available(value) => log.push("configure:\{value}")
      @util.Unavailable(reason) => log.push("configure:\{reason.to_text()}")
    }
  })
  plugin.set_describe_params(fn() {
    let descrs = @params.ParamDescrs::new()
    descrs.add_bool_with_policy(
      "theory.fake.enabled",
      true,
      "fake-params",
      "enable fake params test theory",
      @params.ParamLifecycle::pre_assertion(),
      90,
      true,
    )
    descrs
  })
  plugin.set_updt_params(fn(params) {
    match params.get_bool("theory.fake.enabled") {
      @util.Available(value) => {
        log.push("update:\{value}")
        @util.Available(())
      }
      @util.Unavailable(reason) => @util.Unavailable(reason)
    }
  })
  let descrs = plugin.describe_params()
  inspect(descrs.keys_text(), content="theory.fake.enabled")
  inspect(
    "\{descrs.owner("theory.fake.enabled")}:\{descrs.lifecycle_text("theory.fake.enabled")}:\{descrs.apply_order("theory.fake.enabled")}:\{descrs.requires_reset("theory.fake.enabled")}",
    content="fake-params:pre-assertion:90:true",
  )
  let params = @params.Params::new(descrs)
  ignore(params.set_bool("theory.fake.enabled", false))
  inspect(
    theory_unit_availability_text(plugin.updt_params(params)),
    content="available",
  )
  plugin.configure(params)
  inspect(
    log.join(">"),
    content="configure:false>update:false>configure:false>update:false",
  )
}

///|
test "theory_handles_carry_owner_and_scope_validity" {
  let owner = @ids.TheoryId::new(5)
  let term = TheoryTermRef::new(owner, 3, scope_generation=2)
  let eq = EqFact::new(owner, 4, scope_generation=2)
  let diseq = DiseqFact::new(owner, 5, scope_generation=2)
  inspect(
    "\{term.owner()}:\{term.to_int()}:\{term.is_valid_at(2)}",
    content="th#5:3:true",
  )
  inspect(
    "\{eq.owner()}:\{eq.to_int()}:\{eq.is_valid_at(1)}",
    content="th#5:4:false",
  )
  inspect(
    "\{diseq.owner()}:\{diseq.to_int()}:\{diseq.is_valid_at(3)}",
    content="th#5:5:true",
  )
}

///|
test "theory_factory_descriptor_selects_by_logic_and_family" {
  let descriptor = TheoryFactoryDescriptor::new(
    id=@ids.TheoryId::new(1),
    name="fake-a",
    families=[@ast.FamilyId::new(7)],
    logics=["QF_UF"],
    auto_config=true,
  )
  inspect(descriptor.matches_family(@ast.FamilyId::new(7)), content="true")
  inspect(descriptor.matches_logic("QF_UF"), content="true")
  inspect(descriptor.matches_logic("QF_BV"), content="false")
  inspect(descriptor.auto_config(), content="true")
}

///|
test "theory_plugin_callbacks_record_lifecycle_order" {
  let log : Array[String] = []
  let plugin = TheoryPlugin::default_unimplemented(
    @ids.TheoryId::new(3),
    "fake-b",
    [@ast.FamilyId::new(3)],
  )
  plugin.set_init_search(fn(_, _) { log.push("init") })
  plugin.set_asserted(fn(_, _, asserted) {
    log.push("asserted:\{asserted.literal()}")
  })
  plugin.set_can_propagate(fn(_) {
    log.push("can")
    true
  })
  plugin.set_propagate(fn(_, _) {
    log.push("propagate")
    TheoryPropagateDone
  })
  plugin.set_theory_check(fn(_, _) {
    log.push("check")
    TheoryCheckDone
  })
  plugin.set_finalize_check(fn(_, _) { log.push("finalize") })
  let view = TheoryContextView::new(scope_depth=1)
  let actions = TheoryActions::noop()
  plugin.init_search(view, actions)
  plugin.asserted(
    view,
    actions,
    TheoryAssertedLiteral::new(@sat.Literal::pos(@sat.BoolVar::new(1))),
  )
  if plugin.can_propagate(view) {
    ignore(plugin.propagate(view, actions))
  }
  ignore(plugin.theory_check(view, actions))
  plugin.finalize_check(view, actions)
  inspect(
    log.join(">"),
    content="init>asserted:b1>can>propagate>check>finalize",
  )
}

///|
test "theory_plugin_model_add_value_callback_records_constructed_value_expr" {
  let log : Array[String] = []
  let plugin = TheoryPlugin::default_unimplemented(
    @ids.TheoryId::new(4),
    "fake-model",
    [@ast.FamilyId::new(4)],
  )
  plugin.set_model_add_value(fn(_, _, term, value) {
    log.push("value:\{term}:\{value.to_int()}")
  })
  let view = TheoryContextView::new(scope_depth=1)
  let actions = TheoryActions::noop()
  let term = TheoryTermRef::new(@ids.TheoryId::new(4), 6, scope_generation=1)
  plugin.model_add_value(view, actions, term, @util.ExprId::new(17))
  inspect(log.join(">"), content="value:th#4:6:17")
}

///|
fn optional_literal_text(value : @sat.Literal?) -> String {
  match value {
    Some(literal) => "\{literal}"
    None => "none"
  }
}

///|
fn optional_term_text(value : TheoryTermRef?) -> String {
  match value {
    Some(term) => "\{term}"
    None => "none"
  }
}

///|
fn optional_bool_text(value : Bool?) -> String {
  match value {
    Some(v) => "\{v}"
    None => "none"
  }
}

///|
test "theory_actions_noop_exposes_safe_capabilities" {
  let owner = @ids.TheoryId::new(8)
  let actions = TheoryActions::noop()
  let literal = @sat.Literal::pos(@sat.BoolVar::new(1))
  let term = TheoryTermRef::new(owner, 2, scope_generation=0)
  let antecedent = AntecedentId::new(owner, 3, scope_generation=0)
  inspect(actions.scope_depth(), content="0")
  inspect(
    optional_literal_text(actions.internalize_bool(@util.ExprId::new(1))),
    content="none",
  )
  inspect(
    optional_term_text(actions.internalize_term_ref(@util.ExprId::new(1))),
    content="none",
  )
  inspect(optional_bool_text(actions.sat_value(literal)), content="none")
  inspect(optional_term_text(actions.current_root(term)), content="none")
  actions.add_clause([literal])
  actions.add_lemma([literal])
  actions.enqueue(literal, antecedent)
  actions.conflict(antecedent)
  inspect(actions.materialize_antecedent(antecedent).length(), content="0")
  let hint = actions.create_proof_hint(owner, "fake")
  inspect(
    "\{hint.owner()}:\{hint.to_int()}:\{hint.is_valid_at(0)}",
    content="th#8:-1:true",
  )
  inspect(actions.params_available(), content="false")
  inspect(actions.collect_statistics().keys_text(), content="")
}
