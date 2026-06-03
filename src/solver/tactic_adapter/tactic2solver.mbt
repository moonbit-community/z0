///|
fn tactic_adapter_unsupported_unit(
  feature : String,
) -> @util.Availability[Unit] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment(feature),
    ),
  )
}

///|
fn[T] tactic_adapter_unsupported(feature : String) -> @util.Availability[T] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment(feature),
    ),
  )
}

///|
fn tactic_adapter_unknown(feature : String) -> @solver.CheckSatAssumingResult {
  @solver.CheckSatAssumingResult::from_result(
    @solver.CheckSatResult::unknown_no_model(
      @util.ReasonUnknown::unsupported_fragment(feature),
    ),
  )
}

///|
fn tactic_adapter_reason_to_unknown(
  reason : @util.AvailabilityReason,
) -> @util.ReasonUnknown {
  match reason {
    @util.AvailabilityReason::Unsupported(reason) => reason
    @util.AvailabilityReason::UnknownReason(reason) => reason
    @util.AvailabilityReason::Disabled(feature) =>
      @util.ReasonUnknown::unsupported_fragment(feature)
    @util.AvailabilityReason::NoCurrentResult =>
      @util.ReasonUnknown::unsupported_fragment("no-current-result")
    @util.AvailabilityReason::WrongResult(_, _) =>
      @util.ReasonUnknown::unsupported_fragment(reason.to_text())
    @util.AvailabilityReason::Stale =>
      @util.ReasonUnknown::unsupported_fragment("stale")
  }
}

///|
fn tactic_adapter_result_to_check(
  result : @util.Availability[@tactic.TacticResult],
) -> @solver.CheckSatAssumingResult {
  match result {
    @util.Unavailable(reason) =>
      @solver.CheckSatAssumingResult::from_result(
        @solver.CheckSatResult::unknown_no_model(
          tactic_adapter_reason_to_unknown(reason),
        ),
      )
    @util.Available(tactic_result) => {
      let mut all_sat = true
      for i in 0..<tactic_result.goal_count() {
        match tactic_result.goal(i) {
          None => ()
          Some(goal) =>
            if !goal.sat_preserved() || !goal.unsat_preserved() {
              return tactic_adapter_unknown("tactic2solver:imprecise-goal")
            } else if goal.is_decided_unsat() {
              return @solver.CheckSatAssumingResult::from_result(
                @solver.CheckSatResult::unsat(),
              )
            } else if !goal.is_decided_sat() {
              all_sat = false
            }
        }
      }
      if all_sat {
        @solver.CheckSatAssumingResult::from_result(
          @solver.CheckSatResult::sat(),
        )
      } else {
        tactic_adapter_unknown("tactic2solver:open-goal")
      }
    }
  }
}

///|
fn tactic_adapter_check(
  manager : @ast.AstManager,
  tactic : @tactic.Tactic,
  assertions : @util.ScopedVector[@util.ExprId],
  assumptions : @solver.AssumptionSet,
) -> @solver.CheckSatAssumingResult {
  let goal = @tactic.Goal::new(manager)
  for assertion in assertions.items() {
    goal.add(assertion)
  }
  for assumption in assumptions.items() {
    goal.add(assumption)
  }
  tactic_adapter_result_to_check(tactic.apply(goal))
}

///|
fn tactic_adapter_backend(
  manager : @ast.AstManager,
  tactic : @tactic.Tactic,
) -> @solver.SolverBackend {
  let assertions : @util.ScopedVector[@util.ExprId] = @util.ScopedVector::new()
  @solver.SolverBackend::new(
    assert_expr=fn(expr) {
      assertions.push_item(expr)
      @util.Available(())
    },
    assert_expr_tracked=fn(expr, _) {
      assertions.push_item(expr)
      @util.Available(())
    },
    push=fn(count) {
      if count < 0 {
        tactic_adapter_unsupported_unit("invalid-push")
      } else {
        for _ in 0..<count {
          assertions.push_scope()
        }
        @util.Available(())
      }
    },
    pop=fn(count) {
      assertions.pop_scope(count) catch {
        _ => return tactic_adapter_unsupported_unit("invalid-pop")
      }
      @util.Available(())
    },
    check_sat_assuming=fn(assumptions) {
      tactic_adapter_check(manager, tactic, assertions, assumptions)
    },
    model=fn() { tactic_adapter_unsupported("tactic2solver:model") },
    proof=fn() { tactic_adapter_unsupported("tactic2solver:proof") },
    collect_statistics=fn() { tactic.collect_statistics() },
    translate=fn(target, _) {
      let translator = @ast.AstTranslator::new(manager, target)
      match tactic.translate(translator) {
        @util.Available(translated_tactic) =>
          @util.Available(tactic_adapter_backend(target, translated_tactic))
        @util.Unavailable(reason) => @util.Unavailable(reason)
      }
    },
  )
}

///|
pub fn tactic2solver_factory(tactic : @tactic.Tactic) -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(
      manager,
      config,
      tactic_adapter_backend(manager, tactic),
    )
  })
}
