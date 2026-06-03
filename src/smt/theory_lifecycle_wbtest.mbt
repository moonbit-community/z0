///|
test "smt_theory_registry_setup_selects_two_fake_theories_without_concrete_imports" {
  let registry = TheoryRegistry::new()
  registry.register(
    @theory_core.TheoryFactory::new(
      @theory_core.TheoryFactoryDescriptor::new(
        id=@theory_ids.TheoryId::new(10),
        name="fake-a",
        families=[@ast.FamilyId::new(20)],
        logics=["QF_UF"],
        auto_config=true,
      ),
      fn() {
        @theory_core.TheoryPlugin::default_unimplemented(
          @theory_ids.TheoryId::new(10),
          "fake-a",
          [@ast.FamilyId::new(20)],
        )
      },
    ),
  )
  registry.register(
    @theory_core.TheoryFactory::new(
      @theory_core.TheoryFactoryDescriptor::new(
        id=@theory_ids.TheoryId::new(11),
        name="fake-b",
        families=[@ast.FamilyId::new(21)],
        logics=["QF_UF"],
        auto_config=true,
      ),
      fn() {
        @theory_core.TheoryPlugin::default_unimplemented(
          @theory_ids.TheoryId::new(11),
          "fake-b",
          [@ast.FamilyId::new(21)],
        )
      },
    ),
  )
  inspect(
    setup_selected_names(registry, SmtSetupMode::logic("QF_UF")),
    content="fake-a,fake-b",
  )
  inspect(setup_selected_names(registry, SmtSetupMode::basic()), content="")
}

///|
fn lifecycle_bool_const(
  manager : @ast.AstManager,
  name : String,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
test "smt_context_theory_asserted_receives_actual_sat_literal" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let log : Array[String] = []
  let context = SmtContext::new(manager)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(33),
    "asserted-life",
    [@ast.FamilyId::new(43)],
  )
  plugin.set_asserted(fn(_, _, asserted) { log.push("\{asserted.literal()}") })
  context.register_theory(plugin)
  context.assert_expr(manager.mk_not(p))
  ignore(context.check_sat())
  inspect(log.join(","), content="not b1")
}

///|
test "smt_context_extension_assumption_vars_are_external_to_sat" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  let mut external_var : @pure_sat.BoolVar? = None
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(34),
    "external-assumption-life",
    [@ast.FamilyId::new(44)],
  )
  plugin.set_theory_check(fn(_, actions) {
    match actions.internalize_bool(p) {
      Some(literal) => {
        external_var = Some(literal.bool_var())
        actions.add_extension_assumption(
          literal,
          p,
          Some("external-assumption"),
        )
      }
      None => ()
    }
    @theory_core.TheoryCheckDone
  })
  context.register_theory(plugin)
  ignore(context.check_sat())
  let extension = context.sat_extension()
  match external_var {
    Some(bool_var) => inspect((extension.is_external)(bool_var), content="true")
    None => inspect("missing", content="bool-var")
  }
}

///|
test "smt_context_theory_lifecycle_order_is_observable" {
  let manager = @ast.AstManager::new()
  let log : Array[String] = []
  let context = SmtContext::new(manager)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(12),
    "fake-life",
    [@ast.FamilyId::new(22)],
  )
  plugin.set_push(fn(_) { log.push("push") })
  plugin.set_init_search(fn(_, _) { log.push("init") })
  plugin.set_asserted(fn(_, _, _) { log.push("asserted") })
  plugin.set_can_propagate(fn(_) {
    log.push("can")
    false
  })
  plugin.set_theory_check(fn(_, _) {
    log.push("check")
    @theory_core.TheoryCheckDone
  })
  plugin.set_finalize_check(fn(_, _) { log.push("finalize") })
  plugin.set_on_check_done(fn(_, _) { log.push("done") })
  plugin.set_pop(fn(_, count) { log.push("pop:\{count}") })
  context.register_theory(plugin)
  context.push()
  ignore(context.check_sat())
  context.pop(1)
  inspect(
    log.join(">"),
    content="push>init>can>check>finalize>done>asserted>pop:1",
  )
}

///|
fn theory_lifecycle_result_text(result : SmtContextResult) -> String {
  match result {
    SmtContextSat(_) => "sat"
    SmtContextUnsat => "unsat"
    SmtContextUnknown(reason) => "unknown:\{reason}"
  }
}

///|
fn theory_lifecycle_assumption_result_text(
  result : SmtContextAssumptionResult,
) -> String {
  match result {
    SmtAssumptionSat => "sat"
    SmtAssumptionUnsat(_, _) => "unsat"
    SmtAssumptionUnknown(reason) => "unknown:\{reason}"
  }
}

///|
fn model_lifecycle_plugin(
  id : Int,
  family : Int,
  name : String,
  log : Array[String],
) -> @theory_core.TheoryPlugin {
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(id),
    name,
    [@ast.FamilyId::new(family)],
  )
  plugin.set_init_model(fn(_, _) { log.push("init-model") })
  plugin.set_finalize_model(fn(_, _) { log.push("finalize-model") })
  plugin.set_validate_model(fn(_, _, _) {
    log.push("validate-model")
    @util.Available(())
  })
  plugin
}

///|
test "smt_context_scopes_unsupported_theory_terms_as_unknown" {
  let context = SmtContext::new(@ast.AstManager::new())
  context.push()
  context.record_unsupported_term(
    @util.ExprId::new(99),
    @util.ReasonUnknown::unsupported_fragment("fake:term"),
  )
  inspect(context.unsupported_term_count(), content="1")
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:unsupported-fragment(fake:term)",
  )
  context.pop(1)
  inspect(context.unsupported_term_count(), content="0")
  inspect(theory_lifecycle_result_text(context.check_sat()), content="sat")
}

///|
test "smt_context_late_theory_registration_replays_user_scope_depth" {
  let context = SmtContext::new(@ast.AstManager::new())
  context.push()
  context.push()
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(13),
    "late",
    [@ast.FamilyId::new(23)],
  )
  plugin.set_push(fn(view) { log.push("push:\{view.scope_depth()}") })
  context.register_theory(plugin)
  inspect(log.join(">"), content="push:1>push:2")
}

///|
test "smt_context_late_theory_registration_marks_current_result_stale" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="sat")
  inspect(context.cache_state_text(), content="model=current")
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(14),
    "late-stale",
    [@ast.FamilyId::new(24)],
  )
  context.register_theory(plugin)
  inspect(context.cache_state_text(), content="model=stale")
}

///|
fn fake_lifecycle_factory(
  id : Int,
  family : Int,
  name : String,
  log : Array[String],
) -> @theory_core.TheoryFactory {
  @theory_core.TheoryFactory::new(
    @theory_core.TheoryFactoryDescriptor::new(
      id=@theory_ids.TheoryId::new(id),
      name~,
      families=[@ast.FamilyId::new(family)],
      logics=["QF_UF"],
      auto_config=true,
    ),
    fn() {
      let plugin = @theory_core.TheoryPlugin::default_unimplemented(
        @theory_ids.TheoryId::new(id),
        name,
        [@ast.FamilyId::new(family)],
      )
      plugin.set_configure(fn(_) { log.push("setup:\{name}") })
      plugin.set_internalize_term(fn(_, _, _, expr) {
        log.push("internalize:\{name}:\{expr.to_int()}")
        @theory_core.TheoryHandled(
          @theory_core.TheoryTermRef::new(
            @theory_ids.TheoryId::new(id),
            expr.to_int(),
            scope_generation=0,
          ),
        )
      })
      plugin.set_asserted(fn(_, _, _) { log.push("asserted:\{name}") })
      plugin.set_can_propagate(fn(_) {
        log.push("can:\{name}")
        true
      })
      plugin.set_propagate(fn(_, _) {
        log.push("propagate:\{name}")
        @theory_core.TheoryPropagateDone
      })
      plugin.set_theory_check(fn(_, _) {
        log.push("check:\{name}")
        @theory_core.TheoryCheckDone
      })
      plugin.set_finalize_check(fn(_, _) { log.push("finalize:\{name}") })
      plugin
    },
  )
}

///|
test "smt_context_setup_registers_two_fake_theories_and_dispatches_internalize" {
  let log : Array[String] = []
  let registry = TheoryRegistry::new()
  registry.register(fake_lifecycle_factory(20, 30, "fake-a", log))
  registry.register(fake_lifecycle_factory(21, 31, "fake-b", log))
  let context = SmtContext::new(@ast.AstManager::new())
  context.setup_theories(
    registry,
    SmtSetupMode::logic("QF_UF"),
    @params.Params::new(@params.ParamDescrs::new()),
  )
  ignore(
    context.internalize_theory_term(
      @ast.FamilyId::new(30),
      @util.ExprId::new(300),
    ),
  )
  ignore(
    context.internalize_theory_term(
      @ast.FamilyId::new(31),
      @util.ExprId::new(301),
    ),
  )
  ignore(context.check_sat())
  inspect(
    log.join(">"),
    content="setup:fake-a>setup:fake-b>internalize:fake-a:300>internalize:fake-b:301>can:fake-a>propagate:fake-a>can:fake-b>propagate:fake-b>check:fake-a>check:fake-b>finalize:fake-a>finalize:fake-b",
  )
}

///|
test "smt_context_defers_giveup_while_theory_check_makes_progress" {
  let context = SmtContext::new(@ast.AstManager::new())
  let log : Array[String] = []
  let stuck = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(30),
    "stuck",
    [@ast.FamilyId::new(40)],
  )
  stuck.set_theory_check(fn(_, _) {
    log.push("stuck")
    @theory_core.TheoryCheckGiveUp(
      @util.ReasonUnknown::unsupported_fragment("stuck"),
    )
  })
  stuck.set_finalize_check(fn(_, _) { log.push("finalize:stuck") })
  stuck.set_on_check_done(fn(_, _) { log.push("done:stuck") })
  let progress = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(31),
    "progress",
    [@ast.FamilyId::new(41)],
  )
  let mut rounds = 0
  progress.set_theory_check(fn(_, _) {
    rounds += 1
    log.push("progress:\{rounds}")
    if rounds == 1 {
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  progress.set_finalize_check(fn(_, _) { log.push("finalize:progress") })
  progress.set_on_check_done(fn(_, _) { log.push("done:progress") })
  context.register_theory(stuck)
  context.register_theory(progress)
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:unsupported-fragment(stuck)",
  )
  inspect(
    log.join(">"),
    content=(
      #|stuck>progress:1>stuck>progress:2>finalize:stuck>finalize:progress>done:stuck>done:progress
    ),
  )
}

///|
test "smt_context_propagate_giveup_runs_check_completion_callbacks" {
  let context = SmtContext::new(@ast.AstManager::new())
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(33),
    "propagate-stuck",
    [@ast.FamilyId::new(43)],
  )
  plugin.set_can_propagate(fn(_) { true })
  plugin.set_propagate(fn(_, _) {
    log.push("propagate")
    @theory_core.TheoryPropagateGiveUp(
      @util.ReasonUnknown::unsupported_fragment("propagate-stuck"),
    )
  })
  plugin.set_theory_check(fn(_, _) {
    log.push("check")
    @theory_core.TheoryCheckDone
  })
  plugin.set_finalize_check(fn(_, _) { log.push("finalize") })
  plugin.set_on_check_done(fn(_, _) { log.push("done") })
  context.register_theory(plugin)
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:unsupported-fragment(propagate-stuck)",
  )
  inspect(log.join(">"), content="propagate>finalize>done")
}

///|
test "smt_context_validates_unsat_core_before_returning_unsat" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  context.assert_expr(manager.mk_not(p))
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(32),
    "core-validator",
    [@ast.FamilyId::new(42)],
  )
  plugin.set_validate_unsat_core(fn(_, _) {
    @util.Unavailable(
      @util.AvailabilityReason::unknown(@util.ReasonUnknown::InvalidCore),
    )
  })
  context.register_theory(plugin)
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:invalid-core",
  )
}

///|
test "smt_context_validates_model_before_returning_sat" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(33),
    "model-validator",
    [@ast.FamilyId::new(43)],
  )
  plugin.set_validate_model(fn(_, _, _) {
    @util.Unavailable(
      @util.AvailabilityReason::unknown(
        @util.ReasonUnknown::ModelValidationFailed,
      ),
    )
  })
  context.register_theory(plugin)
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:model-validation-failed",
  )
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_context_maps_model_validator_availability_state_to_validation_failure" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(42),
    "stale-model-validator",
    [@ast.FamilyId::new(46)],
  )
  plugin.set_validate_model(fn(_, _, _) { @util.Unavailable(@util.Stale) })
  context.register_theory(plugin)
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:model-validation-failed",
  )
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_context_rejects_euf_model_obligation_mismatch" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a_decl = manager.declare_const("a", sort_u)
  let b_decl = manager.declare_const("b", sort_u)
  let f = manager.declare_fun("f", [sort_u], sort_u)
  let a = manager.mk_app(a_decl, [])
  let b = manager.mk_app(b_decl, [])
  let f_a = manager.mk_app(f, [a])
  let context = SmtContext::new(manager)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(41),
    "euf-obligation-validator",
    [manager.uf_family()],
  )
  plugin.set_include_func_interp(fn(_) { true })
  plugin.set_validate_model(fn(_, _, model) {
    match
      (
        model.eval_text(f_a, completion=false),
        model.eval_text(a, completion=false),
      ) {
      (Some(lhs), Some(rhs)) =>
        if lhs == rhs {
          @util.Available(())
        } else {
          @util.Unavailable(
            @util.AvailabilityReason::unknown(
              @util.ReasonUnknown::ModelValidationFailed,
            ),
          )
        }
      _ =>
        @util.Unavailable(
          @util.AvailabilityReason::unknown(
            @util.ReasonUnknown::ModelValidationFailed,
          ),
        )
    }
  })
  context.register_theory(plugin)
  context.assert_expr(manager.mk_distinct([a, b]))
  context.assert_expr(manager.mk_eq(f_a, b))
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:model-validation-failed",
  )
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_context_runs_model_lifecycle_hooks_before_returning_sat" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let log : Array[String] = []
  context.register_theory(model_lifecycle_plugin(36, 46, "model-life", log))
  inspect(theory_lifecycle_result_text(context.check_sat()), content="sat")
  inspect(log.join(">"), content="init-model>finalize-model>validate-model")
}

///|
test "smt_context_runs_assumption_model_lifecycle_hooks_before_returning_sat" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  let log : Array[String] = []
  context.register_theory(
    model_lifecycle_plugin(37, 47, "assumption-model-life", log),
  )
  inspect(
    theory_lifecycle_assumption_result_text(context.check_sat_assuming([p])),
    content="sat",
  )
  inspect(log.join(">"), content="init-model>finalize-model>validate-model")
}

///|
test "smt_context_runs_empty_assumption_model_lifecycle_hooks_before_returning_sat" {
  let context = SmtContext::new(@ast.AstManager::new())
  let log : Array[String] = []
  context.register_theory(
    model_lifecycle_plugin(38, 48, "empty-assumption-model-life", log),
  )
  inspect(
    theory_lifecycle_assumption_result_text(context.check_sat_assuming([])),
    content="sat",
  )
  inspect(log.join(">"), content="init-model>finalize-model>validate-model")
}

///|
test "smt_context_rejects_incomplete_theory_model_before_returning_sat" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let log : Array[String] = []
  let plugin = model_lifecycle_plugin(39, 49, "incomplete-model-life", log)
  plugin.set_model_incomplete_reason(fn() {
    log.push("model-incomplete")
    Some(@util.ReasonUnknown::IncompleteTheory("fake-model"))
  })
  context.register_theory(plugin)
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:incomplete-theory(fake-model)",
  )
  inspect(context.cache_state_text(), content="model=none")
  inspect(log.join(">"), content="init-model>finalize-model>model-incomplete")
}

///|
test "smt_context_rejects_unhandled_theory_model_before_returning_sat" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let log : Array[String] = []
  let plugin = model_lifecycle_plugin(40, 50, "unhandled-model-life", log)
  plugin.set_has_unhandled(fn() {
    log.push("has-unhandled")
    true
  })
  context.register_theory(plugin)
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:incomplete-theory(unhandled-model-life)",
  )
  inspect(context.cache_state_text(), content="model=none")
  inspect(log.join(">"), content="init-model>finalize-model>has-unhandled")
}

///|
test "smt_context_validates_assumption_model_before_returning_sat" {
  let manager = @ast.AstManager::new()
  let p = lifecycle_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(34),
    "assumption-model-validator",
    [@ast.FamilyId::new(44)],
  )
  plugin.set_validate_model(fn(_, _, _) {
    @util.Unavailable(
      @util.AvailabilityReason::unknown(
        @util.ReasonUnknown::ModelValidationFailed,
      ),
    )
  })
  context.register_theory(plugin)
  inspect(
    theory_lifecycle_assumption_result_text(context.check_sat_assuming([p])),
    content="unknown:model-validation-failed",
  )
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_context_validates_empty_assumption_model_before_returning_sat" {
  let context = SmtContext::new(@ast.AstManager::new())
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(35),
    "empty-assumption-model-validator",
    [@ast.FamilyId::new(45)],
  )
  plugin.set_validate_model(fn(_, _, _) {
    @util.Unavailable(
      @util.AvailabilityReason::unknown(
        @util.ReasonUnknown::ModelValidationFailed,
      ),
    )
  })
  context.register_theory(plugin)
  inspect(
    theory_lifecycle_assumption_result_text(context.check_sat_assuming([])),
    content="unknown:model-validation-failed",
  )
  inspect(context.cache_state_text(), content="model=none")
}
