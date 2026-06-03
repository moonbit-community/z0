///|
fn tactic_adapter_result_text(
  result : @util.Availability[@tactic.TacticResult],
) -> String {
  match result {
    @util.Available(value) => "goals:\{value.goal_count()}"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn solver2tactic_goal_text(
  result : @util.Availability[@tactic.TacticResult],
) -> String {
  match result {
    @util.Available(value) =>
      match value.goal(0) {
        Some(goal) =>
          "goals:\{value.goal_count()}:size=\{goal.size()}:sat=\{goal.is_decided_sat()}:unsat=\{goal.is_decided_unsat()}"
        None => "goals:\{value.goal_count()}:no-goal"
      }
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
fn unit_availability_text(value : @util.Availability[Unit]) -> String {
  match value {
    @util.Available(_) => "available"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn bool_const(manager : @ast.AstManager, name : String) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
test "tactic2solver_simplify_decides_trivial_bool_goals" {
  let manager = @ast.AstManager::new()
  let factory = tactic2solver_factory(@tactic.Tactic::simplify())
  let solver = factory.create(manager, @solver.SolverFactoryConfig::new())
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_bool(true))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_bool(false))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
}

///|
test "tactic2solver_preserves_scoped_assertions" {
  let manager = @ast.AstManager::new()
  let solver = tactic2solver_factory(@tactic.Tactic::simplify()).create(
    manager,
    @solver.SolverFactoryConfig::new(),
  )
  inspect(solver.check_sat().to_text(), content="sat")
  inspect(unit_availability_text(solver.push(1)), content="available")
  inspect(
    unit_availability_text(solver.assert_expr(manager.mk_bool(false))),
    content="available",
  )
  inspect(solver.check_sat().to_text(), content="unsat")
  inspect(unit_availability_text(solver.pop(1)), content="available")
  inspect(solver.check_sat().to_text(), content="sat")
}

///|
test "tactic2solver_translate_replays_assertions" {
  let source = @ast.AstManager::new()
  let solver = tactic2solver_factory(@tactic.Tactic::simplify()).create(
    source,
    @solver.SolverFactoryConfig::new(),
  )
  inspect(
    unit_availability_text(solver.assert_expr(source.mk_bool(false))),
    content="available",
  )
  let translated = solver.translate(@ast.AstManager::new())
  inspect(
    unit_availability_text(discard_available(translated)),
    content="available",
  )
  match translated {
    @util.Available(translated_solver) =>
      inspect(translated_solver.check_sat().to_text(), content="unsat")
    @util.Unavailable(_) => fail("expected translated tactic solver")
  }
}

///|
test "tactic2solver_reports_unknown_for_open_or_imprecise_goals" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let open_solver = tactic2solver_factory(@tactic.Tactic::skip()).create(
    manager,
    @solver.SolverFactoryConfig::new(),
  )
  inspect(
    unit_availability_text(open_solver.assert_expr(p)),
    content="available",
  )
  inspect(
    open_solver.check_sat().to_text(),
    content="unknown: unsupported-fragment(tactic2solver:open-goal)",
  )
  let imprecise = @tactic.Tactic::new("under-goal", fn(goal) {
    goal.set_precision(@tactic.GoalPrecision::Under)
    @util.Available(@tactic.TacticResult::from_goals([goal]))
  })
  let imprecise_solver = tactic2solver_factory(imprecise).create(
    manager,
    @solver.SolverFactoryConfig::new(),
  )
  inspect(
    unit_availability_text(imprecise_solver.assert_expr(manager.mk_bool(true))),
    content="available",
  )
  inspect(
    imprecise_solver.check_sat().to_text(),
    content="unknown: unsupported-fragment(tactic2solver:imprecise-goal)",
  )
}

///|
test "solver2tactic_closes_sat_and_unsat_goals" {
  let manager = @ast.AstManager::new()
  let tactic = solver2tactic(tactic2solver_factory(@tactic.Tactic::simplify()))
  let sat_goal = @tactic.Goal::new(manager)
  sat_goal.add(manager.mk_bool(true))
  inspect(
    solver2tactic_goal_text(tactic.apply(sat_goal)),
    content="goals:1:size=0:sat=true:unsat=false",
  )
  let unsat_goal = @tactic.Goal::new(manager)
  unsat_goal.add(manager.mk_bool(false))
  inspect(
    solver2tactic_goal_text(tactic.apply(unsat_goal)),
    content="goals:1:size=1:sat=false:unsat=true",
  )
}

///|
test "solver2tactic_reports_unknown_when_solver_cannot_close_goal" {
  let manager = @ast.AstManager::new()
  let tactic = solver2tactic(tactic2solver_factory(@tactic.Tactic::skip()))
  let goal = @tactic.Goal::new(manager)
  goal.add(bool_const(manager, "p"))
  inspect(
    tactic_adapter_result_text(tactic.apply(goal)),
    content="unknown(unsupported-fragment(tactic2solver:open-goal))",
  )
}

///|
test "tactic2solver_forwards_tactic_statistics" {
  let tactic = @tactic.Tactic::new("stats-hook", fn(goal) {
    @util.Available(@tactic.TacticResult::from_goals([goal]))
  })
  tactic.set_collect_statistics(fn() {
    let stats = @stats.Statistics::new()
    stats.inc_counter("tactic.stats-hook.custom", 5)
    stats
  })
  let solver = tactic2solver_factory(tactic).create(
    @ast.AstManager::new(),
    @solver.SolverFactoryConfig::new(),
  )
  inspect(
    solver.collect_statistics().keys_text(),
    content="tactic.stats-hook.custom",
  )
}

///|
test "solver2tactic_forwards_solver_params_and_statistics" {
  let manager = @ast.AstManager::new()
  let tactic = solver2tactic(tactic2solver_factory(@tactic.Tactic::simplify()))
  inspect(
    tactic.describe_params().keys_text(),
    content="produce_models,produce_proofs,produce_unsat_cores,produce_unsat_assumptions,model_completion,proof_check",
  )
  let params = @solver.SolverFactoryConfig::new()
    .with_produce_models(true)
    .params()
  inspect(
    unit_availability_text(tactic.updt_params(params)),
    content="available",
  )
  let goal = @tactic.Goal::new(manager)
  goal.add(manager.mk_bool(true))
  inspect(tactic_adapter_result_text(tactic.apply(goal)), content="goals:1")
  inspect(tactic.collect_statistics().keys_text(), content="solver.checks")
}
