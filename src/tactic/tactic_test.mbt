///|
fn tactic_result_text(result : @util.Availability[TacticResult]) -> String {
  match result {
    @util.Available(value) => "goals:\{value.goal_count()}"
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
fn tactic_availability_text(value : @util.Availability[Tactic]) -> String {
  match value {
    @util.Available(tactic) => "available:\{tactic.name()}"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn tactic_result_goal_text(
  manager : @ast.AstManager,
  result : @util.Availability[TacticResult],
) -> String {
  match result {
    @util.Available(value) =>
      match value.goal(0) {
        Some(goal) => {
          let parts : Array[String] = []
          for i in 0..<goal.size() {
            match goal.formula(i) {
              Some(formula) => parts.push(manager.pretty(formula))
              None => ()
            }
          }
          if parts.is_empty() {
            "empty:depth=\{goal.depth()}:sat=\{goal.is_decided_sat()}"
          } else {
            let formulas = parts.join(",")
            "\{formulas}:depth=\{goal.depth()}:unsat=\{goal.is_decided_unsat()}"
          }
        }
        None => "no-goal"
      }
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn tactic_result_goal_metadata_text(
  result : @util.Availability[TacticResult],
) -> String {
  match result {
    @util.Available(value) =>
      match value.goal(0) {
        Some(goal) =>
          "\{goal.dependency_converter().labels_text()}:\{goal.requires_model()},\{goal.requires_proof()},\{goal.requires_unsat_core()}:\{goal.sat_preserved()},\{goal.unsat_preserved()}"
        None => "no-goal"
      }
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn tactic_result_goal_model_converter_text(
  result : @util.Availability[TacticResult],
) -> String {
  match result {
    @util.Available(value) =>
      match value.goal(0) {
        Some(goal) => goal.model_converter().steps_text()
        None => "no-goal"
      }
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn tactic_result_goal_proof_labels_text(
  result : @util.Availability[TacticResult],
) -> String {
  match result {
    @util.Available(value) =>
      match value.goal(0) {
        Some(goal) =>
          match goal.proof_converter().apply_labels(["named-input"]) {
            @util.Available(labels) => labels.join(",")
            @util.Unavailable(reason) => reason.to_text()
          }
        None => "no-goal"
      }
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
test "skip_tactic_preserves_goal_and_fail_tactic_is_explicitly_unsupported" {
  let manager = @ast.AstManager::new()
  let goal = Goal::new(manager)
  goal.add(manager.mk_bool(true))
  inspect(tactic_result_text(Tactic::skip().apply(goal)), content="goals:1")
  inspect(
    tactic_result_text(Tactic::fail("phase-9-seed").apply(goal)),
    content="unsupported(phase-9-seed)",
  )
}

///|
test "tactic_statistics_use_stable_seed_key" {
  let stats = Tactic::skip().collect_statistics()
  inspect(stats.keys_text(), content="tactic.skip.queries")
}

///|
test "tactic_lifecycle_hooks_are_available_by_default" {
  let source = @ast.AstManager::new()
  let target = @ast.AstManager::new()
  let translator = @ast.AstTranslator::new(source, target)
  let tactic = Tactic::skip()
  inspect(
    tactic_availability_text(tactic.translate(translator)),
    content="available:skip",
  )
  inspect(
    unit_availability_text(tactic.set_logic("QF_UF")),
    content="available",
  )
  inspect(
    unit_availability_text(
      tactic.updt_params(@params.Params::new(tactic.describe_params())),
    ),
    content="available",
  )
  inspect(unit_availability_text(tactic.cleanup()), content="available")
}

///|
test "tactic_params_and_statistics_hooks_are_callback_driven" {
  let tactic = Tactic::new("fake-hook", fn(goal) {
    @util.Available(TacticResult::from_goals([goal]))
  })
  let log : Array[String] = []
  tactic.set_describe_params(fn() {
    let descrs = @params.ParamDescrs::new()
    descrs.add_bool_with_policy(
      "tactic.fake.enabled",
      true,
      "fake-hook",
      "enable fake tactic hook",
      @params.ParamLifecycle::dynamic(),
      70,
      false,
    )
    descrs
  })
  tactic.set_updt_params(fn(params) {
    match params.get_bool("tactic.fake.enabled") {
      @util.Available(value) => {
        log.push("update:\{value}")
        @util.Available(())
      }
      @util.Unavailable(reason) => @util.Unavailable(reason)
    }
  })
  tactic.set_collect_statistics(fn() {
    let stats = @stats.Statistics::new()
    stats.inc_counter("tactic.fake-hook.custom", 3)
    stats
  })
  let descrs = tactic.describe_params()
  inspect(descrs.keys_text(), content="tactic.fake.enabled")
  inspect(
    "\{descrs.owner("tactic.fake.enabled")}:\{descrs.lifecycle_text("tactic.fake.enabled")}:\{descrs.apply_order("tactic.fake.enabled")}:\{descrs.requires_reset("tactic.fake.enabled")}",
    content="fake-hook:dynamic:70:false",
  )
  let params = @params.Params::new(descrs)
  ignore(params.set_bool("tactic.fake.enabled", false))
  inspect(
    unit_availability_text(tactic.updt_params(params)),
    content="available",
  )
  inspect(log.join(">"), content="update:false")
  inspect(
    tactic.collect_statistics().keys_text(),
    content="tactic.fake-hook.custom",
  )
}

///|
test "simplify_tactic_rewrites_bool_formulas_and_tracks_decisions" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let sat_goal = Goal::new(manager)
  sat_goal.add(manager.mk_bool(true))
  inspect(
    tactic_result_goal_text(manager, Tactic::simplify().apply(sat_goal)),
    content="empty:depth=1:sat=true",
  )
  let rewrite_goal = Goal::new(manager)
  rewrite_goal.add(manager.mk_and([p, manager.mk_bool(true)]))
  inspect(
    tactic_result_goal_text(manager, Tactic::simplify().apply(rewrite_goal)),
    content="p:depth=1:unsat=false",
  )
  let unsat_goal = Goal::new(manager)
  unsat_goal.add(manager.mk_not(manager.mk_bool(true)))
  inspect(
    tactic_result_goal_text(manager, Tactic::simplify().apply(unsat_goal)),
    content="false:depth=1:unsat=true",
  )
}

///|
test "tseitin_cnf_tactic_creates_ast_level_aux_clauses" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let q_decl = manager.declare_const("q", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let q = manager.mk_app(q_decl, [])
  let goal = Goal::new(manager)
  goal.add(manager.mk_and([p, q]))
  inspect(
    tactic_result_goal_text(manager, Tactic::tseitin_cnf().apply(goal)),
    content="(or (not tseitin!0) p),(or (not tseitin!0) q),(or tseitin!0 (not p) (not q)),tseitin!0:depth=1:unsat=false",
  )
}

///|
test "tseitin_cnf_tactic_records_aux_model_hiding_converter" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let q_decl = manager.declare_const("q", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let q = manager.mk_app(q_decl, [])
  let goal = Goal::new(manager)
  goal.add(manager.mk_and([p, q]))
  inspect(
    tactic_result_goal_model_converter_text(Tactic::tseitin_cnf().apply(goal)),
    content="identity>identity>hide:tseitin!0",
  )
}

///|
test "tseitin_cnf_tactic_records_aux_proof_and_dependency_metadata" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let q_decl = manager.declare_const("q", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let q = manager.mk_app(q_decl, [])
  let goal = Goal::new(manager)
  goal.add(manager.mk_and([p, q]))
  let result = Tactic::tseitin_cnf().apply(goal)
  inspect(
    tactic_result_goal_proof_labels_text(result),
    content="named-input,tseitin-aux:tseitin!0",
  )
  inspect(
    tactic_result_goal_metadata_text(result),
    content="tseitin-aux:tseitin!0:false,false,false:true,true",
  )
}

///|
test "tseitin_cnf_tactic_preserves_literals_and_decisions" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let literal_goal = Goal::new(manager)
  literal_goal.add(p)
  inspect(
    tactic_result_goal_text(manager, Tactic::tseitin_cnf().apply(literal_goal)),
    content="p:depth=1:unsat=false",
  )
  let sat_goal = Goal::new(manager)
  sat_goal.add(manager.mk_bool(true))
  inspect(
    tactic_result_goal_text(manager, Tactic::tseitin_cnf().apply(sat_goal)),
    content="empty:depth=1:sat=true",
  )
  let unsat_goal = Goal::new(manager)
  unsat_goal.add(manager.mk_bool(false))
  inspect(
    tactic_result_goal_text(manager, Tactic::tseitin_cnf().apply(unsat_goal)),
    content="false:depth=1:unsat=true",
  )
}

///|
test "solve_eqs_tactic_substitutes_bool_constants_and_preserves_metadata" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let q_decl = manager.declare_const("q", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let q = manager.mk_app(q_decl, [])
  let goal = Goal::new(manager)
  goal.add(manager.mk_eq(p, manager.mk_bool(true)))
  goal.add(manager.mk_and([p, q]))
  goal.dependency_converter().add_label("dep-solve")
  goal.set_requires_model(true)
  let result = Tactic::solve_eqs().apply(goal)
  inspect(
    tactic_result_goal_text(manager, result),
    content="q:depth=1:unsat=false",
  )
  inspect(
    tactic_result_goal_metadata_text(result),
    content="dep-solve:true,false,false:true,true",
  )
}

///|
test "solve_eqs_tactic_substitutes_uf_constants_into_remaining_formulas" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a_decl = manager.declare_const("a", u)
  let b_decl = manager.declare_const("b", u)
  let a = manager.mk_app(a_decl, [])
  let b = manager.mk_app(b_decl, [])
  let goal = Goal::new(manager)
  goal.add(manager.mk_eq(a, b))
  goal.add(manager.mk_distinct([a, b]))
  inspect(
    tactic_result_goal_text(manager, Tactic::solve_eqs().apply(goal)),
    content="false:depth=1:unsat=true",
  )
}

///|
test "simplify_tactic_preserves_goal_metadata" {
  let manager = @ast.AstManager::new()
  let goal = Goal::new(manager)
  goal.add(manager.mk_bool(true))
  goal.dependency_converter().add_label("dep-a")
  goal.set_requires_model(true)
  goal.set_requires_proof(true)
  goal.set_requires_unsat_core(true)
  goal.set_precision(Over)
  inspect(
    tactic_result_goal_metadata_text(Tactic::simplify().apply(goal)),
    content="dep-a:true,true,true:false,true",
  )
}

///|
test "and_then_tactical_applies_second_tactic_to_each_subgoal" {
  let manager = @ast.AstManager::new()
  let goal = Goal::new(manager)
  goal.add(manager.mk_bool(true))
  let tactic = Tactic::skip().and_then(Tactic::simplify())
  inspect(tactic.name(), content="skip>>simplify")
  inspect(
    tactic_result_goal_text(manager, tactic.apply(goal)),
    content="empty:depth=1:sat=true",
  )
  inspect(
    tactic_result_text(
      Tactic::fail("first").and_then(Tactic::skip()).apply(goal),
    ),
    content="unsupported(first)",
  )
}
