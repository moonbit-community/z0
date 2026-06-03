///|
fn bool_const(manager : @ast.AstManager, name : String) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
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
fn solver_availability_text(
  value : @util.Availability[@solver.Solver],
) -> String {
  match value {
    @util.Available(_) => "available"
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
test "default_factory_reports_preprocess_strategy" {
  let config = @solver.SolverFactoryConfig::new().with_logic("QF_UF")
  inspect(default_strategy_text(config), content="logic=QF_UF;preprocess=on")
}

///|
test "default_factory_reports_solver_params_contract" {
  inspect(
    default_params_descrs().keys_text(),
    content="produce_models,produce_proofs,produce_unsat_cores,produce_unsat_assumptions,model_completion,proof_check",
  )
}

///|
test "default_factory_reports_phase11_theory_selection" {
  let manager = @ast.AstManager::new()
  inspect(
    default_configured_theory_names(
      manager,
      @solver.SolverFactoryConfig::new().with_logic("QF_UF"),
    ),
    content="euf",
  )
  inspect(
    default_configured_theory_names(
      manager,
      @solver.SolverFactoryConfig::new().with_logic("QF_UFLIA"),
    ),
    content="euf,arith_lite",
  )
  inspect(
    default_configured_theory_names(
      manager,
      @solver.SolverFactoryConfig::new().with_logic("QF_FAKE_COMBO"),
    ),
    content="euf,fake_combo",
  )
  inspect(
    default_configured_theory_names(
      manager,
      @solver.SolverFactoryConfig::new().with_logic("ALL"),
    ),
    content="euf,arith_lite",
  )
}

///|
test "default_factory_solves_bool_sat_through_preprocess_wrapper" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = default_factory().create(
    manager,
    @solver.SolverFactoryConfig::new().with_logic("QF_UF"),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(solver.check_sat().to_text(), content="sat")
}

///|
test "default_factory_solves_bool_unsat_through_preprocess_wrapper" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = default_factory().create(
    manager,
    @solver.SolverFactoryConfig::new().with_logic("QF_UF"),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_not(p))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
}

///|
test "default_factory_translate_preserves_scopes_and_tracked_core" {
  let source = @ast.AstManager::new()
  let p = bool_const(source, "p")
  let q = bool_const(source, "q")
  let tracker = bool_const(source, "named-p")
  let solver = default_factory().create(
    source,
    @solver.SolverFactoryConfig::new()
    .with_logic("QF_UF")
    .with_produce_unsat_cores(true),
  )
  inspect(
    unit_availability_text(
      discard_available(
        solver.assert_expr_tracked(
          p,
          @solver.TrackedExpr::new(tracker, Some("named-p")),
        ),
      ),
    ),
    content="available",
  )
  inspect(unit_availability_text(solver.push(1)), content="available")
  inspect(unit_availability_text(solver.assert_expr(q)), content="available")
  inspect(unit_availability_text(solver.push(1)), content="available")
  inspect(
    unit_availability_text(solver.assert_expr(source.mk_not(p))),
    content="available",
  )
  ignore(solver.check_sat())
  let target = @ast.AstManager::new()
  let translated_availability = solver.translate(target)
  inspect(
    solver_availability_text(translated_availability),
    content="available",
  )
  match translated_availability {
    @util.Available(translated) => {
      inspect(translated.get_scope_level(), content="2")
      inspect(translated.get_num_assertions(), content="3")
      inspect(
        core_availability_text(translated.get_unsat_core()),
        content="no-current-result",
      )
      inspect(translated.check_sat().to_text(), content="unsat")
      inspect(
        core_availability_text(translated.get_unsat_core()),
        content="named-p",
      )
      inspect(unit_availability_text(translated.pop(1)), content="available")
      inspect(translated.check_sat().to_text(), content="sat")
      inspect(unit_availability_text(translated.pop(1)), content="available")
      inspect(translated.check_sat().to_text(), content="sat")
    }
    @util.Unavailable(_) => fail("expected translated solver")
  }
}
