///|
fn solver2tactic_result_from_goal(
  goal : @tactic.Goal,
  result : @solver.CheckSatResult,
) -> @util.Availability[@tactic.TacticResult] {
  let manager = goal.manager()
  match result {
    CheckSat => {
      let sat_goal = @tactic.Goal::new(manager)
      sat_goal.set_requires_model(goal.requires_model())
      sat_goal.set_requires_proof(goal.requires_proof())
      sat_goal.set_requires_unsat_core(goal.requires_unsat_core())
      Available(@tactic.TacticResult::from_goals([sat_goal]))
    }
    CheckUnsat => {
      let unsat_goal = @tactic.Goal::new(manager)
      unsat_goal.add(manager.mk_bool(false))
      Available(@tactic.TacticResult::from_goals([unsat_goal]))
    }
    CheckUnknown(reason, _) =>
      Unavailable(@util.AvailabilityReason::unknown(reason))
  }
}

///|
fn solver2tactic_update_config(
  config : @solver.SolverFactoryConfig,
  params : @params.Params,
) -> @util.Availability[Unit] {
  match params.get_bool("produce_models") {
    Available(value) => ignore(config.with_produce_models(value))
    Unavailable(reason) => return Unavailable(reason)
  }
  match params.get_bool("produce_proofs") {
    Available(value) => ignore(config.with_produce_proofs(value))
    Unavailable(reason) => return Unavailable(reason)
  }
  match params.get_bool("produce_unsat_cores") {
    Available(value) => ignore(config.with_produce_unsat_cores(value))
    Unavailable(reason) => return Unavailable(reason)
  }
  match params.get_bool("produce_unsat_assumptions") {
    Available(value) => ignore(config.with_produce_unsat_assumptions(value))
    Unavailable(reason) => return Unavailable(reason)
  }
  Available(())
}

///|
pub fn solver2tactic(factory : @solver.SolverFactory) -> @tactic.Tactic {
  let config = @solver.SolverFactoryConfig::new()
  let statistics = @stats.Statistics::new()
  let tactic = @tactic.Tactic::new("solver2tactic", fn(goal) {
    let solver = factory.create(goal.manager(), config)
    for i in 0..<goal.size() {
      match goal.formula(i) {
        Some(formula) =>
          match solver.assert_expr(formula) {
            Available(_) => ()
            Unavailable(reason) => return Unavailable(reason)
          }
        None => ()
      }
    }
    let result = solver.check_sat()
    statistics.record_solver_check()
    solver2tactic_result_from_goal(goal, result)
  })
  tactic.set_describe_params(fn() { config.describe_params() })
  tactic.set_updt_params(fn(params) {
    solver2tactic_update_config(config, params)
  })
  tactic.set_logic_callback(fn(logic) {
    ignore(config.with_logic(logic))
    Available(())
  })
  tactic.set_collect_statistics(fn() { statistics })
  tactic
}
