///|
fn bool_const(manager : @ast.AstManager, name : String) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
fn u_const(
  manager : @ast.AstManager,
  sort : @util.SortId,
  name : String,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, sort)
  manager.mk_app(decl, [])
}

///|
fn unit_availability_text(value : @util.Availability[Unit]) -> String {
  match value {
    @util.Available(_) => "available"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn[T] discard_available(
  value : @util.Availability[T],
) -> @util.Availability[Unit] {
  match value {
    @util.Available(_) => @util.Available(())
    @util.Unavailable(reason) => @util.Unavailable(reason)
  }
}

///|
fn bool_availability_text(value : @util.Availability[Bool]) -> String {
  match value {
    @util.Available(value) => "bool:\{value}"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn config_bool_param_text(
  config : SolverFactoryConfig,
  name : String,
) -> String {
  bool_availability_text(config.params().get_bool(name))
}

///|
fn model_availability_text(value : @util.Availability[@model.Model]) -> String {
  match value {
    @util.Available(model) => model.format()
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn model_availability_status(
  value : @util.Availability[@model.Model],
) -> String {
  match value {
    @util.Available(_) => "model"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn model_availability_reason_kind(
  value : @util.Availability[@model.Model],
) -> String {
  match value {
    @util.Available(_) => "available"
    @util.Unavailable(@util.UnknownReason(@util.InvalidModel)) =>
      "invalid-model-tag"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn model_eval_availability_text(
  value : @util.Availability[@model.Model],
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> String {
  match value {
    @util.Available(model) =>
      match model.eval(manager, expr, completion=false) {
        Some(value) => value.to_text()
        None => "missing"
      }
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn model_value_availability_text(
  value : @util.Availability[@model.ModelValue],
) -> String {
  match value {
    @util.Available(value) => value.to_text()
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn model_query_matrix_text(solver : Solver, expr : @util.ExprId) -> String {
  "\{model_availability_status(solver.get_model())}|\{model_value_availability_text(solver.get_value(expr))}|\{model_value_availability_text(solver.eval(expr, completion=false))}"
}

///|
fn model_value_reason_kind(
  value : @util.Availability[@model.ModelValue],
) -> String {
  match value {
    @util.Available(_) => "available"
    @util.Unavailable(@util.UnknownReason(@util.InvalidModel)) =>
      "invalid-model-tag"
    @util.Unavailable(@util.UnknownReason(@util.ModelEvalFailed)) =>
      "model-eval-failed-tag"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn proof_availability_text(
  value : @util.Availability[@proof.ProofRef],
) -> String {
  match value {
    @util.Available(proof) => proof.to_text()
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn core_availability_text(value : @util.Availability[UnsatCore]) -> String {
  match value {
    @util.Available(core) => core.to_text()
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn assumptions_availability_text(
  value : @util.Availability[UnsatAssumptionSet],
) -> String {
  match value {
    @util.Available(assumptions) => "assumptions:\{assumptions.to_text()}"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn reason_unknown_availability_text(
  value : @util.Availability[@util.ReasonUnknown],
) -> String {
  match value {
    @util.Available(reason) => reason.to_text()
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn tracked_id_availability_text(
  value : @util.Availability[TrackedAssertionId],
) -> String {
  match value {
    @util.Available(id) => "tracked:\{id.to_int()}"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn accepting_backend(result : CheckSatResult) -> SolverBackend {
  SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(assumptions) {
      CheckSatAssumingResult::new(
        result,
        match result {
          CheckUnsat => UnsatAssumptionSet::from_exprs(assumptions.items())
          _ => UnsatAssumptionSet::empty()
        },
      )
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() {
      @util.Unavailable(
        @util.AvailabilityReason::unsupported(
          @util.ReasonUnknown::unsupported_fragment("proof-query"),
        ),
      )
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn model_backend(
  result : CheckSatResult,
  model : @model.Model,
) -> SolverBackend {
  SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(_) { CheckSatAssumingResult::from_result(result) },
    model=fn() { @util.Available(model) },
    proof=fn() {
      @util.Unavailable(
        @util.AvailabilityReason::unsupported(
          @util.ReasonUnknown::unsupported_fragment("proof-query"),
        ),
      )
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn missing_model_backend(result : CheckSatResult) -> SolverBackend {
  SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(_) { CheckSatAssumingResult::from_result(result) },
    model=fn() { @util.Unavailable(@util.AvailabilityReason::NoCurrentResult) },
    proof=fn() {
      @util.Unavailable(
        @util.AvailabilityReason::unsupported(
          @util.ReasonUnknown::unsupported_fragment("proof-query"),
        ),
      )
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn assumption_backend(
  root_result : CheckSatResult,
  assumption_result : CheckSatResult,
) -> SolverBackend {
  SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(assumptions) {
      if assumptions.length() == 0 {
        CheckSatAssumingResult::from_result(root_result)
      } else {
        CheckSatAssumingResult::new(
          assumption_result,
          match assumption_result {
            CheckUnsat => UnsatAssumptionSet::from_exprs(assumptions.items())
            _ => UnsatAssumptionSet::empty()
          },
        )
      }
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() {
      @util.Unavailable(
        @util.AvailabilityReason::unsupported(
          @util.ReasonUnknown::unsupported_fragment("proof-query"),
        ),
      )
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn selective_assumption_backend(
  root_result : CheckSatResult,
  assumption_result : CheckSatResult,
  keep : @util.ExprId,
) -> SolverBackend {
  SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(assumptions) {
      if assumptions.length() == 0 {
        CheckSatAssumingResult::from_result(root_result)
      } else {
        let retained : Array[@util.ExprId] = []
        for assumption in assumptions.items() {
          if assumption == keep {
            retained.push(assumption)
          }
        }
        CheckSatAssumingResult::new(
          assumption_result,
          match assumption_result {
            CheckUnsat => UnsatAssumptionSet::from_exprs(retained)
            _ => UnsatAssumptionSet::empty()
          },
        )
      }
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() {
      @util.Unavailable(
        @util.AvailabilityReason::unsupported(
          @util.ReasonUnknown::unsupported_fragment("proof-query"),
        ),
      )
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn duplicate_assumption_backend(
  result : CheckSatResult,
  duplicated : @util.ExprId,
) -> SolverBackend {
  SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(_) {
      CheckSatAssumingResult::new(
        result,
        match result {
          CheckUnsat => UnsatAssumptionSet::from_exprs([duplicated, duplicated])
          _ => UnsatAssumptionSet::empty()
        },
      )
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() {
      @util.Unavailable(
        @util.AvailabilityReason::unsupported(
          @util.ReasonUnknown::unsupported_fragment("proof-query"),
        ),
      )
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn extension_core_backend(
  result : CheckSatResult,
  entry : UnsatCoreEntry,
) -> SolverBackend {
  SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(_) {
      CheckSatAssumingResult::new_with_core(
        result,
        UnsatAssumptionSet::empty(),
        UnsatCore::single(entry),
      )
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() {
      @util.Unavailable(
        @util.AvailabilityReason::unsupported(
          @util.ReasonUnknown::unsupported_fragment("proof-query"),
        ),
      )
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn proof_backend(
  result : CheckSatResult,
  proof : @util.Availability[@proof.ProofRef],
) -> SolverBackend {
  SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(assumptions) {
      CheckSatAssumingResult::new(
        result,
        match result {
          CheckUnsat => UnsatAssumptionSet::from_exprs(assumptions.items())
          _ => UnsatAssumptionSet::empty()
        },
      )
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() { proof },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
test "solver_facade_tracks_assertion_stack_and_scopes" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let not_p = manager.mk_not(p)
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(unit_availability_text(solver.push(1)), content="available")
  inspect(
    unit_availability_text(solver.assert_expr(not_p)),
    content="available",
  )
  inspect(solver.get_scope_level(), content="1")
  inspect(solver.get_num_assertions(), content="2")
  inspect(solver.get_assertion(0).unwrap(), content="expr#0")
  inspect(unit_availability_text(solver.pop(1)), content="available")
  inspect(solver.get_scope_level(), content="0")
  inspect(solver.get_num_assertions(), content="1")
}

///|
test "solver_facade_enforces_produce_flag_timing" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(
    bool_availability_text(solver.set_produce_proofs(true)),
    content="bool:true",
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(
    bool_availability_text(solver.set_produce_proofs(false)),
    content="unsupported(late-option:produce_proofs)",
  )
  inspect(
    bool_availability_text(solver.set_produce_models(true)),
    content="bool:true",
  )
}

///|
test "solver_factory_config_params_track_produce_flags" {
  let config = SolverFactoryConfig::new()
    .with_produce_models(true)
    .with_produce_proofs(true)
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true)
  inspect(
    config.describe_params().keys_text(),
    content="produce_models,produce_proofs,produce_unsat_cores,produce_unsat_assumptions,model_completion,proof_check",
  )
  inspect(
    "\{config_bool_param_text(config, "produce_models")}|\{config_bool_param_text(config, "produce_proofs")}|\{config_bool_param_text(config, "produce_unsat_cores")}|\{config_bool_param_text(config, "produce_unsat_assumptions")}",
    content="bool:true|bool:true|bool:true|bool:true",
  )
}

///|
test "solver_updt_params_applies_typed_produce_flags" {
  let manager = @ast.AstManager::new()
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  let params = SolverFactoryConfig::new()
    .with_produce_models(true)
    .with_produce_proofs(true)
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true)
    .params()
  inspect(
    unit_availability_text(solver.updt_params(params)),
    content="available",
  )
  inspect(
    model_availability_status(solver.get_model()),
    content="no-current-result",
  )
  inspect(
    proof_availability_text(solver.get_proof()),
    content="no-current-result",
  )
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="no-current-result",
  )
  inspect(
    assumptions_availability_text(solver.get_unsat_assumptions()),
    content="no-current-result",
  )
}

///|
test "solver_updt_params_rejects_late_pre_assertion_without_partial_update" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  ignore(solver.assert_expr(p))
  let params = SolverFactoryConfig::new()
    .with_produce_models(true)
    .with_produce_proofs(true)
    .params()
  inspect(
    unit_availability_text(solver.updt_params(params)),
    content="unsupported(late-option:produce_proofs)",
  )
  inspect(
    model_availability_status(solver.get_model()),
    content="disabled(produce-models)",
  )
}

///|
test "solver_facade_rejects_non_bool_assertion_without_mutating_stack" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(
    unit_availability_text(solver.assert_expr(a)),
    content="unsupported(non-bool-assertion:a)",
  )
  inspect(solver.get_num_assertions(), content="0")
}

///|
test "solver_model_availability_distinguishes_no_current_wrong_and_stale" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(
    bool_availability_text(solver.set_produce_models(true)),
    content="bool:true",
  )
  inspect(
    model_availability_text(solver.get_model()),
    content="no-current-result",
  )
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(model_availability_text(solver.get_model()), content="()")
  ignore(solver.assert_expr(p))
  inspect(model_availability_text(solver.get_model()), content="stale")

  let unsat_solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    accepting_backend(CheckSatResult::unsat()),
  )
  inspect(unsat_solver.check_sat().to_text(), content="unsat")
  inspect(
    model_availability_text(unsat_solver.get_model()),
    content="wrong-result(expected=sat, actual=unsat)",
  )
}

///|
test "solver_model_availability_distinguishes_unknown_model_modes" {
  let manager = @ast.AstManager::new()
  let with_model = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    accepting_backend(
      CheckSatResult::unknown_with_model(@util.ReasonUnknown::Other("maybe")),
    ),
  )
  inspect(with_model.check_sat().to_text(), content="unknown: maybe")
  inspect(model_availability_text(with_model.get_model()), content="()")
  let no_model = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    accepting_backend(
      CheckSatResult::unknown_no_model(@util.ReasonUnknown::Other("maybe")),
    ),
  )
  inspect(no_model.check_sat().to_text(), content="unknown: maybe")
  inspect(
    model_availability_text(no_model.get_model()),
    content="wrong-result(expected=sat, actual=unknown-no-model)",
  )
}

///|
test "solver_reason_unknown_tracks_only_current_unknown_result" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let unknown_solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(
      CheckSatResult::unknown_no_model(
        @util.ReasonUnknown::unsupported_fragment("quantifier"),
      ),
    ),
  )
  inspect(
    reason_unknown_availability_text(unknown_solver.reason_unknown()),
    content="no-current-result",
  )
  inspect(
    unknown_solver.check_sat().to_text(),
    content="unknown: unsupported-fragment(quantifier)",
  )
  inspect(
    reason_unknown_availability_text(unknown_solver.reason_unknown()),
    content="unsupported-fragment(quantifier)",
  )
  ignore(unknown_solver.assert_expr(p))
  inspect(
    reason_unknown_availability_text(unknown_solver.reason_unknown()),
    content="stale",
  )

  let sat_solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(sat_solver.check_sat().to_text(), content="sat")
  inspect(
    reason_unknown_availability_text(sat_solver.reason_unknown()),
    content="no-current-result",
  )

  let unsat_solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::unsat()),
  )
  inspect(unsat_solver.check_sat().to_text(), content="unsat")
  inspect(
    reason_unknown_availability_text(unsat_solver.reason_unknown()),
    content="no-current-result",
  )
}

///|
test "solver_model_query_availability_matrix_covers_value_and_eval" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let model = @model.Model::new()
  model.add_bool_const(p_decl, "p", true)

  let disabled = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    model_backend(CheckSatResult::sat(), model),
  )
  inspect(disabled.check_sat().to_text(), content="sat")
  inspect(
    model_query_matrix_text(disabled, p),
    content="disabled(produce-models)|disabled(produce-models)|disabled(produce-models)",
  )

  let no_check = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    model_backend(CheckSatResult::sat(), model),
  )
  inspect(
    model_query_matrix_text(no_check, p),
    content="no-current-result|no-current-result|no-current-result",
  )

  let sat_solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    model_backend(CheckSatResult::sat(), model),
  )
  inspect(sat_solver.check_sat().to_text(), content="sat")
  inspect(model_query_matrix_text(sat_solver, p), content="model|true|true")

  let unsat_solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    model_backend(CheckSatResult::unsat(), model),
  )
  inspect(unsat_solver.check_sat().to_text(), content="unsat")
  inspect(
    model_query_matrix_text(unsat_solver, p),
    content="wrong-result(expected=sat, actual=unsat)|wrong-result(expected=sat, actual=unsat)|wrong-result(expected=sat, actual=unsat)",
  )

  let unknown_with_model = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    model_backend(
      CheckSatResult::unknown_with_model(@util.ReasonUnknown::Other("maybe")),
      model,
    ),
  )
  inspect(unknown_with_model.check_sat().to_text(), content="unknown: maybe")
  inspect(
    model_query_matrix_text(unknown_with_model, p),
    content="model|true|true",
  )

  let unknown_no_model = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    model_backend(
      CheckSatResult::unknown_no_model(@util.ReasonUnknown::Other("maybe")),
      model,
    ),
  )
  inspect(unknown_no_model.check_sat().to_text(), content="unknown: maybe")
  inspect(
    model_query_matrix_text(unknown_no_model, p),
    content="wrong-result(expected=sat, actual=unknown-no-model)|wrong-result(expected=sat, actual=unknown-no-model)|wrong-result(expected=sat, actual=unknown-no-model)",
  )

  let stale_solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    model_backend(CheckSatResult::sat(), model),
  )
  inspect(stale_solver.check_sat().to_text(), content="sat")
  ignore(stale_solver.assert_expr(p))
  inspect(model_query_matrix_text(stale_solver, p), content="stale|stale|stale")
}

///|
test "solver_get_model_returns_backend_model_object" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let model = @model.Model::new()
  model.add_bool_const(p_decl, "p", true)
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    model_backend(CheckSatResult::sat(), model),
  )
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(
    model_eval_availability_text(solver.get_model(), manager, p),
    content="true",
  )
}

///|
test "solver_eval_uses_backend_model_and_completion_flag" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a_decl = manager.declare_const("a", sort_u)
  let a = manager.mk_app(a_decl, [])
  let model = @model.Model::new()
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    model_backend(CheckSatResult::sat(), model),
  )
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(
    model_value_availability_text(solver.eval(a, completion=false)),
    content="unknown(model-eval-failed)",
  )
  inspect(
    model_value_availability_text(solver.eval(a, completion=true)),
    content="@U0",
  )
  inspect(model_value_availability_text(solver.get_value(a)), content="@U0")
}

///|
test "solver_model_queries_report_typed_invalid_model_when_backend_lacks_snapshot" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    missing_model_backend(CheckSatResult::sat()),
  )
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(
    model_availability_reason_kind(solver.get_model()),
    content="invalid-model-tag",
  )
  inspect(
    model_value_reason_kind(solver.get_value(p)),
    content="invalid-model-tag",
  )
}

///|
test "solver_eval_reports_typed_model_eval_failure_without_completion" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a_decl = manager.declare_const("a", sort_u)
  let a = manager.mk_app(a_decl, [])
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_models(true),
    model_backend(CheckSatResult::sat(), @model.Model::new()),
  )
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(
    model_value_reason_kind(solver.eval(a, completion=false)),
    content="model-eval-failed-tag",
  )
}

///|
test "solver_proof_and_core_queries_never_fake_success" {
  let manager = @ast.AstManager::new()
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::unsat()),
  )
  inspect(
    proof_availability_text(solver.get_proof()),
    content="disabled(produce-proofs)",
  )
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="disabled(produce-unsat-cores)",
  )
  inspect(
    assumptions_availability_text(solver.get_unsat_assumptions()),
    content="disabled(produce-unsat-assumptions)",
  )
  inspect(
    bool_availability_text(solver.set_produce_proofs(true)),
    content="bool:true",
  )
  inspect(
    bool_availability_text(solver.set_produce_unsat_cores(true)),
    content="bool:true",
  )
  inspect(
    bool_availability_text(solver.set_produce_unsat_assumptions(true)),
    content="bool:true",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    proof_availability_text(solver.get_proof()),
    content="unsupported(proof-query)",
  )
  inspect(core_availability_text(solver.get_unsat_core()), content="")
  inspect(
    assumptions_availability_text(solver.get_unsat_assumptions()),
    content="assumptions:",
  )
}

///|
test "solver_unsat_query_availability_matrix_records_result_kind" {
  let manager = @ast.AstManager::new()

  let no_check = Solver::new(
    manager,
    SolverFactoryConfig::new()
    .with_produce_proofs(true)
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
    proof_backend(
      CheckSatResult::unsat(),
      @proof.ProofHandle::new(3, @proof.ProofKind::ast()).view(),
    ),
  )
  inspect(
    proof_availability_text(no_check.get_proof()),
    content="no-current-result",
  )
  inspect(
    core_availability_text(no_check.get_unsat_core()),
    content="no-current-result",
  )
  inspect(
    assumptions_availability_text(no_check.get_unsat_assumptions()),
    content="no-current-result",
  )

  let sat_solver = Solver::new(
    manager,
    SolverFactoryConfig::new()
    .with_produce_proofs(true)
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
    proof_backend(
      CheckSatResult::sat(),
      @proof.ProofHandle::new(4, @proof.ProofKind::ast()).view(),
    ),
  )
  inspect(sat_solver.check_sat().to_text(), content="sat")
  inspect(
    proof_availability_text(sat_solver.get_proof()),
    content="wrong-result(expected=unsat, actual=sat)",
  )
  inspect(
    core_availability_text(sat_solver.get_unsat_core()),
    content="wrong-result(expected=unsat, actual=sat)",
  )
  inspect(
    assumptions_availability_text(sat_solver.get_unsat_assumptions()),
    content="wrong-result(expected=unsat, actual=sat)",
  )

  let unknown_solver = Solver::new(
    manager,
    SolverFactoryConfig::new()
    .with_produce_proofs(true)
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
    proof_backend(
      CheckSatResult::unknown_with_model(@util.ReasonUnknown::Other("maybe")),
      @proof.ProofHandle::new(5, @proof.ProofKind::ast()).view(),
    ),
  )
  inspect(unknown_solver.check_sat().to_text(), content="unknown: maybe")
  inspect(
    proof_availability_text(unknown_solver.get_proof()),
    content="wrong-result(expected=unsat, actual=unknown-with-model)",
  )
  inspect(
    core_availability_text(unknown_solver.get_unsat_core()),
    content="wrong-result(expected=unsat, actual=unknown-with-model)",
  )
  inspect(
    assumptions_availability_text(unknown_solver.get_unsat_assumptions()),
    content="wrong-result(expected=unsat, actual=unknown-with-model)",
  )
}

///|
test "solver_get_proof_uses_backend_when_enabled_unsat" {
  let manager = @ast.AstManager::new()
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_proofs(true),
    proof_backend(
      CheckSatResult::unsat(),
      @proof.ProofHandle::new(7, @proof.ProofKind::ast()).view(),
    ),
  )
  inspect(
    proof_availability_text(solver.get_proof()),
    content="no-current-result",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(proof_availability_text(solver.get_proof()), content="proof#7(ast)")
}

///|
test "solver_get_proof_propagates_invalid_backend_proof" {
  let manager = @ast.AstManager::new()
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_proofs(true),
    proof_backend(
      CheckSatResult::unsat(),
      @util.Unavailable(
        @util.AvailabilityReason::unknown(@util.ReasonUnknown::InvalidProof),
      ),
    ),
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    proof_availability_text(solver.get_proof()),
    content="unknown(invalid-proof)",
  )
}

///|
test "solver_unsat_query_mode_change_stales_current_empty_check" {
  let manager = @ast.AstManager::new()
  let core_solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::unsat()),
  )
  inspect(core_solver.check_sat().to_text(), content="unsat")
  inspect(
    bool_availability_text(core_solver.set_produce_unsat_cores(true)),
    content="bool:true",
  )
  inspect(core_availability_text(core_solver.get_unsat_core()), content="stale")

  let assumption_solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::unsat()),
  )
  inspect(assumption_solver.check_sat().to_text(), content="unsat")
  inspect(
    bool_availability_text(
      assumption_solver.set_produce_unsat_assumptions(true),
    ),
    content="bool:true",
  )
  inspect(
    assumptions_availability_text(assumption_solver.get_unsat_assumptions()),
    content="stale",
  )

  let proof_solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    proof_backend(
      CheckSatResult::unsat(),
      @proof.ProofHandle::new(9, @proof.ProofKind::ast()).view(),
    ),
  )
  inspect(proof_solver.check_sat().to_text(), content="unsat")
  inspect(
    bool_availability_text(proof_solver.set_produce_proofs(true)),
    content="bool:true",
  )
  inspect(proof_availability_text(proof_solver.get_proof()), content="stale")
}

///|
test "solver_tracked_assertion_records_named_unsat_core" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-p")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_unsat_cores(true),
    accepting_backend(CheckSatResult::unsat()),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(p, TrackedExpr::new(tracker, Some("named-p"))),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(core_availability_text(solver.get_unsat_core()), content="named-p")
}

///|
test "solver_tracked_assertion_rejects_duplicates_and_pop_releases_tracker" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let tracker = bool_const(manager, "named-t")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(unit_availability_text(solver.push(1)), content="available")
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(p, TrackedExpr::new(tracker, Some("named-t"))),
    ),
    content="tracked:0",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(q, TrackedExpr::new(tracker, Some("named-t"))),
    ),
    content="unsupported(duplicate-tracked-assertion:named-t)",
  )
  inspect(unit_availability_text(solver.pop(1)), content="available")
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(q, TrackedExpr::new(tracker, Some("named-t"))),
    ),
    content="tracked:1",
  )
}

///|
test "solver_tracked_assertion_requires_bool_const_tracker" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let tracker = bool_const(manager, "named-t")
  let f = manager.declare_fun("f", [manager.bool_sort()], manager.bool_sort())
  let u = manager.declare_sort("U", 0)
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        p,
        TrackedExpr::new(manager.mk_not(tracker), Some("bad-not")),
      ),
    ),
    content="unsupported(invalid-tracker:(not named-t))",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        p,
        TrackedExpr::new(manager.mk_app(f, [q]), Some("bad-app")),
      ),
    ),
    content="unsupported(invalid-tracker:(f q))",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        p,
        TrackedExpr::new(u_const(manager, u, "a"), Some("bad-sort")),
      ),
    ),
    content="unsupported(invalid-tracker:a)",
  )
}

///|
test "solver_tracked_assertion_rejects_non_bool_formula_without_mutating_stack" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let tracker = bool_const(manager, "named-non-bool")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        a,
        TrackedExpr::new(tracker, Some("named-non-bool")),
      ),
    ),
    content="unsupported(non-bool-assertion:a)",
  )
  inspect(solver.get_num_assertions(), content="0")
}

///|
test "solver_tracked_unsat_core_uses_backend_assumption_subset" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let tracker_p = bool_const(manager, "named-p")
  let tracker_q = bool_const(manager, "named-q")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_unsat_cores(true),
    selective_assumption_backend(
      CheckSatResult::sat(),
      CheckSatResult::unsat(),
      tracker_p,
    ),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        p,
        TrackedExpr::new(tracker_p, Some("named-p")),
      ),
    ),
    content="tracked:0",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        q,
        TrackedExpr::new(tracker_q, Some("named-q")),
      ),
    ),
    content="tracked:1",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(core_availability_text(solver.get_unsat_core()), content="named-p")
}

///|
test "solver_tracked_unsat_core_deduplicates_backend_assumption_subset" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-p")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_unsat_cores(true),
    duplicate_assumption_backend(CheckSatResult::unsat(), tracker),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(p, TrackedExpr::new(tracker, Some("named-p"))),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(core_availability_text(solver.get_unsat_core()), content="named-p")
}

///|
test "solver_unsat_assumption_set_from_exprs_deduplicates_exact_entries" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  inspect(UnsatAssumptionSet::from_exprs([p, p]).to_text(), content="expr#0")
}

///|
test "solver_tracked_assertion_records_unsat_assumption_when_enabled" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-p")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_unsat_assumptions(true),
    accepting_backend(CheckSatResult::unsat()),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(p, TrackedExpr::new(tracker, Some("named-p"))),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    assumptions_availability_text(solver.get_unsat_assumptions()),
    content="assumptions:\{tracker}",
  )
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="disabled(produce-unsat-cores)",
  )
}

///|
test "solver_check_sat_assuming_records_original_unsat_assumptions" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let assumptions = AssumptionSet::new()
  assumptions.add(p)
  assumptions.add(p)
  inspect(assumptions.length(), content="1")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_unsat_assumptions(true),
    assumption_backend(CheckSatResult::sat(), CheckSatResult::unsat()),
  )
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    assumptions_availability_text(solver.get_unsat_assumptions()),
    content="assumptions:expr#0",
  )
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(
    assumptions_availability_text(solver.get_unsat_assumptions()),
    content="wrong-result(expected=unsat, actual=sat)",
  )
}

///|
test "solver_unsat_core_maps_call_assumption_owner" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let assumptions = AssumptionSet::new()
  assumptions.add(p)
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_unsat_cores(true),
    assumption_backend(CheckSatResult::sat(), CheckSatResult::unsat()),
  )
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(core_availability_text(solver.get_unsat_core()), content="expr#0")
  inspect(
    assumptions_availability_text(solver.get_unsat_assumptions()),
    content="disabled(produce-unsat-assumptions)",
  )
}

///|
test "solver_unsat_core_includes_backend_extension_core_entry" {
  let manager = @ast.AstManager::new()
  let owner = bool_const(manager, "fake-ext-core")
  let assumptions = AssumptionSet::new()
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new().with_produce_unsat_cores(true),
    extension_core_backend(
      CheckSatResult::unsat(),
      UnsatCoreEntry::new(owner, Some("fake-ext-core")),
    ),
  )
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="fake-ext-core",
  )
  inspect(
    assumptions_availability_text(solver.get_unsat_assumptions()),
    content="disabled(produce-unsat-assumptions)",
  )
}

///|
test "solver_check_sat_assuming_does_not_persist_call_assumptions" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let assumptions = AssumptionSet::new()
  assumptions.add(p)
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    assumption_backend(CheckSatResult::sat(), CheckSatResult::unsat()),
  )
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(solver.get_num_assertions(), content="0")
  inspect(solver.check_sat().to_text(), content="sat")
}

///|
test "solver_reserved_translate_path_is_explicitly_unsupported" {
  let manager = @ast.AstManager::new()
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(
    unit_availability_text(discard_available(solver.translate(manager))),
    content="unsupported(translate)",
  )
}

///|
test "solver_statistics_snapshot_is_available_without_check" {
  let manager = @ast.AstManager::new()
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(CheckSatResult::sat()),
  )
  inspect(solver.collect_statistics().keys_text(), content="")
  ignore(solver.check_sat())
  inspect(solver.collect_statistics().keys_text(), content="solver.checks")
}

///|
test "solver_statistics_incomplete_reasons_follow_current_non_stale_result" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = Solver::new(
    manager,
    SolverFactoryConfig::new(),
    accepting_backend(
      CheckSatResult::unknown_no_model(
        @util.ReasonUnknown::ModelValidationFailed,
      ),
    ),
  )
  inspect(
    solver.check_sat().to_text(),
    content="unknown: model-validation-failed",
  )
  inspect(
    solver.collect_statistics().incomplete_reasons_text(),
    content="model-validation-failed",
  )
  ignore(solver.assert_expr(p))
  inspect(solver.collect_statistics().incomplete_reasons_text(), content="")
  inspect(
    solver.check_sat().to_text(),
    content="unknown: model-validation-failed",
  )
  inspect(
    solver.collect_statistics().incomplete_reasons_text(),
    content="model-validation-failed",
  )
}

///|
test "solver_statistics_incomplete_reasons_include_backend_stats_manifest_gaps" {
  let manager = @ast.AstManager::new()
  let backend = SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(_) {
      CheckSatAssumingResult::from_result(CheckSatResult::sat())
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() {
      @util.Unavailable(
        @util.AvailabilityReason::unsupported(
          @util.ReasonUnknown::unsupported_fragment("proof-query"),
        ),
      )
    },
    collect_statistics=fn() {
      let stats = @stats.Statistics::new()
      stats.inc_counter("backend.custom", 1)
      stats.mark_incomplete(@util.ReasonUnknown::IncompleteTheory("stats"))
      stats
    },
  )
  let solver = Solver::new(manager, SolverFactoryConfig::new(), backend)
  inspect(solver.collect_statistics().keys_text(), content="backend.custom")
  inspect(
    solver.collect_statistics().incomplete_reasons_text(),
    content="incomplete-theory(stats),statistics-missing-owner:backend.custom",
  )
  ignore(solver.check_sat())
  inspect(
    solver.collect_statistics().incomplete_reasons_text(),
    content="incomplete-theory(stats),statistics-missing-owner:backend.custom",
  )
}
