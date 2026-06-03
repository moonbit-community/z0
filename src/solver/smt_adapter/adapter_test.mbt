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
fn string_availability_text(value : @util.Availability[String]) -> String {
  match value {
    @util.Available(value) => value
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn solver_availability_text(
  value : @util.Availability[@solver.Solver],
) -> String {
  match value {
    @util.Available(_) => "available"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn tracked_id_availability_text(
  value : @util.Availability[@solver.TrackedAssertionId],
) -> String {
  match value {
    @util.Available(id) => "tracked:\{id.to_int()}"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn core_availability_text(
  value : @util.Availability[@solver.UnsatCore],
) -> String {
  match value {
    @util.Available(core) => core.to_text()
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn assumptions_availability_text(
  manager : @ast.AstManager,
  value : @util.Availability[@solver.UnsatAssumptionSet],
) -> String {
  match value {
    @util.Available(assumptions) =>
      [
        for assumption in assumptions.items() => manager.pretty(assumption)
      ].join(",")
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
fn unknown_reason_kind_text(result : @solver.CheckSatResult) -> String {
  match result.reason_unknown() {
    Some(@util.ReasonUnknown::ModelValidationFailed) =>
      "model-validation-failed"
    Some(@util.ReasonUnknown::Other(reason)) => "other:\{reason}"
    Some(reason) => reason.to_text()
    None => "none"
  }
}

///|
fn model_validation_failure_registry() -> @smt.TheoryRegistry {
  let registry = @smt.TheoryRegistry::new()
  registry.register(
    @theory_core.TheoryFactory::new(
      @theory_core.TheoryFactoryDescriptor::new(
        id=@theory_ids.TheoryId::new(81),
        name="model-validation-fake",
        families=[@ast.FamilyId::new(81)],
        logics=["QF_UF"],
        auto_config=true,
      ),
      fn() {
        let plugin = @theory_core.TheoryPlugin::default_unimplemented(
          @theory_ids.TheoryId::new(81),
          "model-validation-fake",
          [@ast.FamilyId::new(81)],
        )
        plugin.set_validate_model(fn(_, _, _) {
          @util.Unavailable(
            @util.AvailabilityReason::unknown(
              @util.ReasonUnknown::ModelValidationFailed,
            ),
          )
        })
        plugin
      },
    ),
  )
  registry
}

///|
test "smt_adapter_factory_solves_bool_sat" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = default_factory().create(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_models(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(
    string_availability_text(solver.get_model_text()),
    content="(\n  (define-fun p () Bool\n    true)\n)",
  )
}

///|
test "smt_adapter_preserves_typed_model_validation_unknown_reason" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = new_solver_with_registry(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_models(true),
    model_validation_failure_registry(),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  let result = solver.check_sat()
  inspect(result.to_text(), content="unknown: model-validation-failed")
  inspect(unknown_reason_kind_text(result), content="model-validation-failed")
  inspect(
    string_availability_text(solver.get_model_text()),
    content="wrong-result(expected=sat, actual=unknown-no-model)",
  )
}

///|
test "smt_adapter_factory_preserves_scope_pop" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = new_solver(manager, @solver.SolverFactoryConfig::new())
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(unit_availability_text(solver.push(1)), content="available")
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(unit_availability_text(solver.pop(1)), content="available")
  inspect(solver.check_sat().to_text(), content="sat")
}

///|
test "smt_adapter_translate_replays_assertions_and_scope_shape" {
  let source = @ast.AstManager::new()
  let p = bool_const(source, "p")
  let solver = new_solver(
    source,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_models(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(unit_availability_text(solver.push(1)), content="available")
  inspect(
    unit_availability_text(solver.assert_expr(source.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  let target = @ast.AstManager::new()
  let translated_availability = solver.translate(target)
  inspect(
    solver_availability_text(translated_availability),
    content="available",
  )
  match translated_availability {
    @util.Available(translated) => {
      inspect(translated.get_scope_level(), content="1")
      inspect(translated.get_num_assertions(), content="2")
      inspect(
        string_availability_text(translated.get_model_text()),
        content="no-current-result",
      )
      inspect(translated.check_sat().to_text(), content="unsat")
      inspect(unit_availability_text(translated.pop(1)), content="available")
      inspect(translated.check_sat().to_text(), content="sat")
    }
    @util.Unavailable(_) => fail("expected translated solver")
  }
}

///|
test "smt_adapter_tracked_assertion_participates_in_unsat_core" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-p")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_unsat_cores(true),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        p,
        @solver.TrackedExpr::new(tracker, Some("named-p")),
      ),
    ),
    content="tracked:0",
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(core_availability_text(solver.get_unsat_core()), content="named-p")
}

///|
test "smt_adapter_unsat_core_excludes_irrelevant_tracked_assertion" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let tracker_p = bool_const(manager, "named-p")
  let tracker_q = bool_const(manager, "named-q")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_unsat_cores(true),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        p,
        @solver.TrackedExpr::new(tracker_p, Some("named-p")),
      ),
    ),
    content="tracked:0",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        q,
        @solver.TrackedExpr::new(tracker_q, Some("named-q")),
      ),
    ),
    content="tracked:1",
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(core_availability_text(solver.get_unsat_core()), content="named-p")
}

///|
test "smt_adapter_tracked_assertion_participates_in_unsat_assumptions" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-p")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_unsat_assumptions(true),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        p,
        @solver.TrackedExpr::new(tracker, Some("named-p")),
      ),
    ),
    content="tracked:0",
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="named-p",
  )
}

///|
test "smt_adapter_tracked_euf_assertion_participates_in_core_and_assumptions" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let tracker = bool_const(manager, "named-diseq")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_distinct([a, b]),
        @solver.TrackedExpr::new(tracker, Some("named-diseq")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="named-diseq",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="named-diseq",
  )
}

///|
test "smt_adapter_tracked_euf_scope_pop_drops_backend_record" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let tracker = bool_const(manager, "named-diseq")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(unit_availability_text(solver.push(1)), content="available")
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_distinct([a, b]),
        @solver.TrackedExpr::new(tracker, Some("named-diseq")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(unit_availability_text(solver.pop(1)), content="available")
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(tracker)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="sat")
}

///|
test "smt_adapter_tracked_mixed_conjunction_maps_bool_conflict_to_tracker" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-mixed")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_and([p, manager.mk_distinct([a, b])]),
        @solver.TrackedExpr::new(tracker, Some("named-mixed")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="named-mixed",
  )
}

///|
test "smt_adapter_tracked_mixed_conjunction_maps_euf_conflict_to_tracker" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-mixed")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_and([p, manager.mk_distinct([a, b])]),
        @solver.TrackedExpr::new(tracker, Some("named-mixed")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="named-mixed",
  )
}

///|
test "smt_adapter_tracked_demorgan_mixed_maps_bool_conflict_to_tracker" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-demorgan")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_not(manager.mk_or([manager.mk_not(p), manager.mk_eq(a, b)])),
        @solver.TrackedExpr::new(tracker, Some("named-demorgan")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="named-demorgan",
  )
}

///|
test "smt_adapter_tracked_demorgan_mixed_maps_euf_conflict_to_tracker" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-demorgan")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_distinct([a, b]))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_not(
          manager.mk_or([manager.mk_not(p), manager.mk_distinct([a, b])]),
        ),
        @solver.TrackedExpr::new(tracker, Some("named-demorgan")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="named-demorgan",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="named-demorgan",
  )
}

///|
test "smt_adapter_tracked_negated_implies_mixed_maps_euf_conflict_to_tracker" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-implies")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_not(manager.mk_implies(p, manager.mk_eq(a, b))),
        @solver.TrackedExpr::new(tracker, Some("named-implies")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="named-implies",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="named-implies",
  )
}

///|
test "smt_adapter_tracked_nested_mixed_conjunction_maps_euf_conflict_to_tracker" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let tracker = bool_const(manager, "named-nested")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_and([p, manager.mk_and([q, manager.mk_distinct([a, b])])]),
        @solver.TrackedExpr::new(tracker, Some("named-nested")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="named-nested",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="named-nested",
  )
}

///|
test "smt_adapter_check_sat_assuming_uses_temporary_scope" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_unsat_assumptions(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(manager.mk_not(p))
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(solver.check_sat().to_text(), content="sat")
}

///|
test "smt_adapter_check_sat_assuming_drops_irrelevant_unsat_assumptions" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_unsat_assumptions(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(manager.mk_not(p))
  assumptions.add(manager.mk_not(q))
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="(not p)",
  )
}

///|
test "smt_adapter_check_sat_assuming_deduplicates_repeated_assumptions" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_unsat_assumptions(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  let not_p = manager.mk_not(p)
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(not_p)
  assumptions.add(not_p)
  inspect(assumptions.length(), content="1")
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="(not p)",
  )
}

///|
test "smt_adapter_check_sat_assuming_core_uses_original_compound_assumption" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_unsat_cores(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  let assumption = manager.mk_and([q, manager.mk_not(p)])
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(assumption)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="\{assumption}",
  )
}

///|
test "smt_adapter_check_sat_assuming_euf_assumption_uses_original_owner" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  let assumption = manager.mk_distinct([a, b])
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(assumption)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="\{assumption}",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="(distinct a b)",
  )
  inspect(solver.check_sat().to_text(), content="sat")
}

///|
test "smt_adapter_check_sat_assuming_euf_assumption_drops_irrelevant_owner" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let c = u_const(manager, u, "c")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  let conflict = manager.mk_distinct([a, b])
  let irrelevant = manager.mk_distinct([a, c])
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(conflict)
  assumptions.add(irrelevant)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="\{conflict}",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="(distinct a b)",
  )
}

///|
test "smt_adapter_check_sat_assuming_mixed_conjunction_bool_conflict_uses_original_owner" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  let assumption = manager.mk_and([p, manager.mk_distinct([a, b])])
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(assumption)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="\{assumption}",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="(and p (distinct a b))",
  )
}

///|
test "smt_adapter_check_sat_assuming_mixed_conjunction_euf_conflict_uses_original_owner" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  let assumption = manager.mk_and([p, manager.mk_distinct([a, b])])
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(assumption)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="\{assumption}",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="(and p (distinct a b))",
  )
}

///|
test "smt_adapter_check_sat_assuming_nested_mixed_conjunction_euf_conflict_uses_original_owner" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true)
    .with_produce_unsat_assumptions(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  let assumption = manager.mk_and([
    p,
    manager.mk_and([q, manager.mk_distinct([a, b])]),
  ])
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(assumption)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="\{assumption}",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="(and p (and q (distinct a b)))",
  )
}

///|
fn extension_core_registry(
  assumption_expr : @util.ExprId,
  core_expr : @util.ExprId,
) -> @smt.TheoryRegistry {
  let registry = @smt.TheoryRegistry::new()
  registry.register(
    @theory_core.TheoryFactory::new(
      @theory_core.TheoryFactoryDescriptor::new(
        id=@theory_ids.TheoryId::new(80),
        name="extension-core-fake",
        families=[@ast.FamilyId::new(80)],
        logics=["QF_UF"],
        auto_config=true,
      ),
      fn() {
        let plugin = @theory_core.TheoryPlugin::default_unimplemented(
          @theory_ids.TheoryId::new(80),
          "extension-core-fake",
          [@ast.FamilyId::new(80)],
        )
        plugin.set_theory_check(fn(_, actions) {
          match actions.internalize_bool(assumption_expr) {
            Some(literal) =>
              actions.add_extension_assumption(
                literal,
                core_expr,
                Some("fake-ext-core"),
              )
            None => ()
          }
          @theory_core.TheoryCheckDone
        })
        plugin
      },
    ),
  )
  registry
}

///|
test "smt_adapter_extension_tracking_assumption_maps_to_unsat_core" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let core_owner = bool_const(manager, "fake-ext-core")
  let solver = new_solver_with_registry(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true),
    extension_core_registry(p, core_owner),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(
    solver.check_sat_assuming(@solver.AssumptionSet::new()).to_text(),
    content="unsat",
  )
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="fake-ext-core",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="disabled(produce-unsat-assumptions)",
  )
}

///|
test "smt_adapter_extension_tracking_assumption_participates_in_plain_check" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let core_owner = bool_const(manager, "fake-ext-core")
  let solver = new_solver_with_registry(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true),
    extension_core_registry(p, core_owner),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="fake-ext-core",
  )
}

///|
test "smt_adapter_extension_tracking_assumption_maps_to_unsat_assumptions" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let core_owner = bool_const(manager, "fake-ext-core")
  let solver = new_solver_with_registry(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_assumptions(true),
    extension_core_registry(p, core_owner),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(
    solver.check_sat_assuming(@solver.AssumptionSet::new()).to_text(),
    content="unsat",
  )
  inspect(
    assumptions_availability_text(manager, solver.get_unsat_assumptions()),
    content="fake-ext-core",
  )
  inspect(
    core_availability_text(solver.get_unsat_core()),
    content="disabled(produce-unsat-cores)",
  )
}

///|
test "smt_adapter_get_proof_carries_extension_assumption_theorem_scope" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let core_owner = bool_const(manager, "fake-ext-core")
  let solver = new_solver_with_registry(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
    extension_core_registry(p, core_owner),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 redundant learned;final-empty:false;assumptions:fake-ext-core;result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_materializes_euf_conflict_hint" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_distinct([a, b]))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 theory euf redundant hint congruence((= a b),(distinct a b));final-empty:true;result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_materializes_euf_nary_distinct_conflict_hint" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let c = u_const(manager, u, "c")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_distinct([a, b, c]))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 theory euf redundant hint congruence((= a b),(distinct a b c));final-empty:true;result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_materializes_euf_chain_conflict_hint" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let c = u_const(manager, u, "c")
  let f = manager.declare_fun("f", [u], u)
  let f_a = manager.mk_app(f, [a])
  let f_c = manager.mk_app(f, [c])
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(b, c))),
    content="available",
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_distinct([f_a, f_c]))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 theory euf redundant hint congruence((= a b),(= b c),(distinct (f a) (f c)));final-empty:true;result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_materializes_euf_negated_equality_chain_conflict_hint" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let c = u_const(manager, u, "c")
  let f = manager.declare_fun("f", [u], u)
  let f_a = manager.mk_app(f, [a])
  let f_c = manager.mk_app(f, [c])
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(b, c))),
    content="available",
  )
  let assumption = manager.mk_not(manager.mk_eq(f_a, f_c))
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(assumption)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 theory euf redundant hint congruence((= a b),(= b c),(not (= (f a) (f c))));delete clause#0 deleted;final-empty:false;assumptions:(not (= (f a) (f c)));result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_materializes_euf_assumption_conflict_hint" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  let assumption = manager.mk_distinct([a, b])
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(assumption)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 theory euf redundant hint congruence((= a b),(distinct a b));delete clause#0 deleted;final-empty:false;assumptions:(distinct a b);result:unsat
    ),
  )
  inspect(solver.check_sat().to_text(), content="sat")
}

///|
test "smt_adapter_get_proof_returns_skeleton_when_enabled_unsat" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_proofs(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(proof_availability_text(solver.get_proof()), content="proof#0(ast)")
}

///|
test "smt_adapter_get_proof_carries_call_assumption_theorem_scope" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_proofs(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(manager.mk_not(p))
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 redundant learned;final-empty:false;assumptions:(not p);result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_carries_compound_call_assumption_theorem_scope" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let q = bool_const(manager, "q")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_proofs(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(manager.mk_and([q, manager.mk_not(p)]))
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 asserted input;add clause#2 asserted input;add clause#3 asserted input;add clause#4 redundant learned;delete clause#1 deleted;delete clause#2 deleted;delete clause#3 deleted;delete clause#4 deleted;final-empty:false;assumptions:(and q (not p));result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_carries_tracked_assumption_theorem_scope" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let tracker = bool_const(manager, "named-p")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_proofs(true),
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        p,
        @solver.TrackedExpr::new(tracker, Some("named-p")),
      ),
    ),
    content="tracked:0",
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 asserted input;add clause#2 asserted input;add clause#3 asserted input;add clause#4 asserted input;add clause#5 redundant learned;final-empty:false;assumptions:named-p;result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_materializes_tracked_euf_conflict_hint" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let tracker = bool_const(manager, "named-diseq")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_distinct([a, b]),
        @solver.TrackedExpr::new(tracker, Some("named-diseq")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 theory euf redundant hint congruence((= a b),named-diseq);delete clause#0 deleted;final-empty:false;assumptions:named-diseq;result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_materializes_mixed_call_euf_conflict_hint" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  let assumption = manager.mk_and([p, manager.mk_distinct([a, b])])
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(assumption)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 theory euf redundant hint congruence((= a b),(distinct a b));delete clause#0 deleted;final-empty:false;assumptions:(and p (distinct a b));result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_materializes_tracked_mixed_euf_conflict_hint" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let tracker = bool_const(manager, "named-mixed")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_and([p, manager.mk_distinct([a, b])]),
        @solver.TrackedExpr::new(tracker, Some("named-mixed")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 asserted input;add clause#2 asserted input;add clause#3 asserted input;add clause#4 theory euf redundant hint congruence((= a b),named-mixed);delete clause#4 deleted;final-empty:false;assumptions:named-mixed;result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_materializes_tracked_negated_implies_mixed_euf_conflict_hint" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const(manager, "p")
  let a = u_const(manager, u, "a")
  let b = u_const(manager, u, "b")
  let tracker = bool_const(manager, "named-implies")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_proofs(true),
  )
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_eq(a, b))),
    content="available",
  )
  inspect(
    tracked_id_availability_text(
      solver.assert_expr_tracked(
        manager.mk_not(manager.mk_implies(p, manager.mk_eq(a, b))),
        @solver.TrackedExpr::new(tracker, Some("named-implies")),
      ),
    ),
    content="tracked:0",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 asserted input;add clause#2 asserted input;add clause#3 asserted input;add clause#4 theory euf redundant hint congruence((= a b),named-implies);delete clause#4 deleted;final-empty:false;assumptions:named-implies;result:unsat
    ),
  )
}

///|
test "smt_adapter_get_proof_carries_sat_clause_events" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = new_solver(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_proofs(true),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(
    match solver.get_proof() {
      @util.Available(proof) =>
        match proof.object() {
          Some(object) => object.root_text()
          None => "missing-proof-object"
        }
      @util.Unavailable(reason) => reason.to_text()
    },
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 asserted input;add clause#2 redundant learned;final-empty:true;result:unsat
    ),
  )
}

///|
test "smt_adapter_injects_euf_theory_factory_outside_smt" {
  let manager = @ast.AstManager::new()
  let config = @solver.SolverFactoryConfig::new().with_logic("QF_UF")
  inspect(configured_theory_names(manager, config), content="euf")
  let concrete = new_concrete_solver(manager, config)
  inspect(concrete.registered_theory_count(), content="1")
}
