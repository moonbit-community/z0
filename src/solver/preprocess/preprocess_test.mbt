///|
fn preprocess_seed_backend() -> @solver.SolverBackend {
  @solver.SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(_) {
      @solver.CheckSatAssumingResult::from_result(@solver.CheckSatResult::sat())
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() {
      @util.Unavailable(@util.AvailabilityReason::Disabled("produce-proofs"))
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn preprocess_seed_factory() -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(manager, config, preprocess_seed_backend())
  })
}

///|
fn recording_preprocess_backend(
  manager : @ast.AstManager,
  asserted : Array[String],
  assumptions_seen : Array[String],
) -> @solver.SolverBackend {
  @solver.SolverBackend::new(
    assert_expr=fn(expr) {
      asserted.push(manager.pretty(expr))
      @util.Available(())
    },
    assert_expr_tracked=fn(expr, _) {
      asserted.push(manager.pretty(expr))
      @util.Available(())
    },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(assumptions) {
      for assumption in assumptions.items() {
        assumptions_seen.push(manager.pretty(assumption))
      }
      @solver.CheckSatAssumingResult::from_result(@solver.CheckSatResult::sat())
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() {
      @util.Unavailable(@util.AvailabilityReason::Disabled("produce-proofs"))
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn recording_preprocess_factory(
  asserted : Array[String],
  assumptions_seen : Array[String],
) -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(
      manager,
      config,
      recording_preprocess_backend(manager, asserted, assumptions_seen),
    )
  })
}

///|
fn unsat_assumption_preprocess_backend(
  manager : @ast.AstManager,
  assumptions_seen : Array[String],
) -> @solver.SolverBackend {
  @solver.SolverBackend::new(
    assert_expr=fn(_) { @util.Available(()) },
    assert_expr_tracked=fn(_, _) { @util.Available(()) },
    push=fn(_) { @util.Available(()) },
    pop=fn(_) { @util.Available(()) },
    check_sat_assuming=fn(assumptions) {
      for assumption in assumptions.items() {
        assumptions_seen.push(manager.pretty(assumption))
      }
      @solver.CheckSatAssumingResult::new(
        @solver.CheckSatResult::unsat(),
        @solver.UnsatAssumptionSet::from_exprs(assumptions.items()),
      )
    },
    model=fn() { @util.Available(@model.Model::new()) },
    proof=fn() {
      @util.Unavailable(@util.AvailabilityReason::Disabled("produce-proofs"))
    },
    collect_statistics=fn() { @stats.Statistics::new() },
  )
}

///|
fn unsat_assumption_preprocess_factory(
  assumptions_seen : Array[String],
) -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(
      manager,
      config,
      unsat_assumption_preprocess_backend(manager, assumptions_seen),
    )
  })
}

///|
fn bool_const(manager : @ast.AstManager, name : String) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
fn unsat_assumptions_pretty(
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
test "preprocess_wrapper_tracks_enabled_state_and_delegates_factory" {
  let base = preprocess_seed_factory()
  let wrapper = SolverPreprocess::new(base)
  inspect(wrapper.status_text(), content="preprocess=on")
  let solver = wrapper.create(
    @ast.AstManager::new(),
    @solver.SolverFactoryConfig::new(),
  )
  inspect(solver.check_sat().to_text(), content="sat")
}

///|
test "preprocess_wrapper_rewrites_assertions_and_assumptions_when_enabled" {
  let asserted : Array[String] = []
  let assumptions_seen : Array[String] = []
  let factory = SolverPreprocess::new(
    recording_preprocess_factory(asserted, assumptions_seen),
  ).as_factory()
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = factory.create(manager, @solver.SolverFactoryConfig::new())
  inspect(
    unit_availability_text(
      solver.assert_expr(manager.mk_and([p, manager.mk_bool(true)])),
    ),
    content="available",
  )
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(manager.mk_and([p, manager.mk_bool(true)]))
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="sat")
  inspect(asserted.join(","), content="p")
  inspect(assumptions_seen.join(","), content="p")
}

///|
test "preprocessing_disabled_factory_leaves_assertions_unrewritten" {
  let asserted : Array[String] = []
  let assumptions_seen : Array[String] = []
  let factory = preprocessing_disabled_factory(
    recording_preprocess_factory(asserted, assumptions_seen),
  )
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = factory.create(manager, @solver.SolverFactoryConfig::new())
  inspect(
    unit_availability_text(
      solver.assert_expr(manager.mk_and([p, manager.mk_bool(true)])),
    ),
    content="available",
  )
  inspect(asserted.join(","), content="(and p true)")
}

///|
test "preprocess_wrapper_maps_unsat_assumptions_back_to_original_inputs" {
  let assumptions_seen : Array[String] = []
  let factory = SolverPreprocess::new(
    unsat_assumption_preprocess_factory(assumptions_seen),
  ).as_factory()
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let original = manager.mk_and([p, manager.mk_bool(true)])
  let solver = factory.create(
    manager,
    @solver.SolverFactoryConfig::new().with_produce_unsat_assumptions(true),
  )
  let assumptions = @solver.AssumptionSet::new()
  assumptions.add(original)
  inspect(solver.check_sat_assuming(assumptions).to_text(), content="unsat")
  inspect(assumptions_seen.join(","), content="p")
  inspect(
    unsat_assumptions_pretty(manager, solver.get_unsat_assumptions()),
    content="(and p true)",
  )
}

///|
test "preprocess_wrapper_preserves_base_translate_capability" {
  let factory = SolverPreprocess::new(@smt_adapter.default_factory()).as_factory()
  let source = @ast.AstManager::new()
  let p = bool_const(source, "p")
  let solver = factory.create(
    source,
    @solver.SolverFactoryConfig::new().with_logic("QF_UF"),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(unit_availability_text(solver.push(1)), content="available")
  inspect(
    unit_availability_text(solver.assert_expr(source.mk_not(p))),
    content="available",
  )
  let target = @ast.AstManager::new()
  let translated = solver.translate(target)
  inspect(
    unit_availability_text(discard_available(translated)),
    content="available",
  )
  match translated {
    @util.Available(translated_solver) => {
      inspect(translated_solver.get_scope_level(), content="1")
      inspect(translated_solver.check_sat().to_text(), content="unsat")
      inspect(
        unit_availability_text(translated_solver.pop(1)),
        content="available",
      )
      inspect(translated_solver.check_sat().to_text(), content="sat")
    }
    @util.Unavailable(_) => fail("expected translated solver")
  }
}

///|
test "preprocessing_disabled_factory_keeps_base_solver_available" {
  let factory = preprocessing_disabled_factory(preprocess_seed_factory())
  let solver = factory.create(
    @ast.AstManager::new(),
    @solver.SolverFactoryConfig::new(),
  )
  inspect(solver.check_sat().to_text(), content="sat")
}
