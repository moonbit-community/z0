///|
pub struct SolverPreprocess {
  priv base : @solver.SolverFactory
  priv enabled : Bool
}

///|
pub fn SolverPreprocess::new(base : @solver.SolverFactory) -> SolverPreprocess {
  { base, enabled: true, }
}

///|
pub fn SolverPreprocess::disabled(
  base : @solver.SolverFactory,
) -> SolverPreprocess {
  { base, enabled: false, }
}

///|
pub fn SolverPreprocess::status_text(self : SolverPreprocess) -> String {
  if self.enabled {
    "preprocess=on"
  } else {
    "preprocess=off"
  }
}

///|
fn preprocess_unsupported(message : String) -> @util.AvailabilityReason {
  @util.AvailabilityReason::unsupported(
    @util.ReasonUnknown::unsupported_fragment("preprocess:\{message}"),
  )
}

///|
fn preprocess_rewrite_expr(
  manager : @ast.AstManager,
  enabled : Bool,
  expr : @util.ExprId,
) -> @util.Availability[@util.ExprId] {
  if !enabled {
    Available(expr)
  } else {
    Available(@rewriter.rewrite_bool(manager, expr)) catch {
      err => Unavailable(preprocess_unsupported(Show::to_string(err)))
    }
  }
}

///|
fn preprocess_rewrite_assumptions(
  manager : @ast.AstManager,
  enabled : Bool,
  assumptions : @solver.AssumptionSet,
) -> @util.Availability[@solver.AssumptionSet] {
  let rewritten = @solver.AssumptionSet::new()
  for assumption in assumptions.items() {
    match preprocess_rewrite_expr(manager, enabled, assumption) {
      Available(expr) => rewritten.add(expr)
      Unavailable(reason) => return Unavailable(reason)
    }
  }
  Available(rewritten)
}

///|
fn preprocess_original_for_rewritten(
  originals : Array[@util.ExprId],
  rewritten : Array[@util.ExprId],
  assumption : @util.ExprId,
) -> @util.ExprId {
  for i in 0..<rewritten.length() {
    if rewritten[i] == assumption {
      return originals[i]
    }
  }
  assumption
}

///|
fn preprocess_map_unsat_assumptions(
  original : @solver.AssumptionSet,
  rewritten : @solver.AssumptionSet,
  unsat : @solver.UnsatAssumptionSet,
) -> @solver.UnsatAssumptionSet {
  let original_items = original.items()
  let rewritten_items = rewritten.items()
  let mapped : Array[@util.ExprId] = []
  for assumption in unsat.items() {
    mapped.push(
      preprocess_original_for_rewritten(
        original_items, rewritten_items, assumption,
      ),
    )
  }
  @solver.UnsatAssumptionSet::from_exprs(mapped)
}

///|
fn preprocess_assumptions_changed(
  original : @solver.AssumptionSet,
  rewritten : @solver.AssumptionSet,
) -> Bool {
  let original_items = original.items()
  let rewritten_items = rewritten.items()
  if original_items.length() != rewritten_items.length() {
    return true
  }
  for i in 0..<original_items.length() {
    if original_items[i] != rewritten_items[i] {
      return true
    }
  }
  false
}

///|
fn preprocess_backend(
  manager : @ast.AstManager,
  base_factory : @solver.SolverFactory,
  base : @solver.Solver,
  enabled : Bool,
) -> @solver.SolverBackend {
  @solver.SolverBackend::new(
    assert_expr=fn(expr) {
      match preprocess_rewrite_expr(manager, enabled, expr) {
        Available(rewritten) => base.assert_expr(rewritten)
        Unavailable(reason) => Unavailable(reason)
      }
    },
    assert_expr_tracked=fn(expr, tracked) {
      match preprocess_rewrite_expr(manager, enabled, expr) {
        Available(rewritten) =>
          match base.assert_expr_tracked(rewritten, tracked) {
            Available(_) => Available(())
            Unavailable(reason) => Unavailable(reason)
          }
        Unavailable(reason) => Unavailable(reason)
      }
    },
    push=fn(count) { base.push(count) },
    pop=fn(count) { base.pop(count) },
    check_sat_assuming=fn(assumptions) {
      match preprocess_rewrite_assumptions(manager, enabled, assumptions) {
        Unavailable(reason) =>
          @solver.CheckSatAssumingResult::from_result(
            @solver.CheckSatResult::unknown_no_model(
              @util.ReasonUnknown::unsupported_fragment(reason.to_text()),
            ),
          )
        Available(rewritten) => {
          let result = base.check_sat_assuming(rewritten)
          match result {
            CheckUnsat => {
              let base_unsat = base.get_unsat_assumptions()
              let mapped = match base_unsat {
                Available(unsat) =>
                  preprocess_map_unsat_assumptions(
                    assumptions, rewritten, unsat,
                  )
                Unavailable(_) => @solver.UnsatAssumptionSet::empty()
              }
              let base_core = match base.get_unsat_core() {
                _ if preprocess_assumptions_changed(assumptions, rewritten) =>
                  @solver.UnsatCore::empty()
                Available(core) => core
                Unavailable(_) => @solver.UnsatCore::empty()
              }
              @solver.CheckSatAssumingResult::new_with_core(
                result, mapped, base_core,
              )
            }
            _ => @solver.CheckSatAssumingResult::from_result(result)
          }
        }
      }
    },
    model=fn() { base.get_model() },
    proof=fn() { base.get_proof() },
    collect_statistics=fn() { @stats.Statistics::new() },
    translate=fn(target, config) {
      Available(
        preprocess_backend(
          target,
          base_factory,
          base_factory.create(target, config),
          enabled,
        ),
      )
    },
  )
}

///|
pub fn SolverPreprocess::create(
  self : SolverPreprocess,
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
) -> @solver.Solver {
  let base = self.base.create(manager, config)
  @solver.Solver::new(
    manager,
    config,
    preprocess_backend(manager, self.base, base, self.enabled),
  )
}

///|
pub fn SolverPreprocess::as_factory(
  self : SolverPreprocess,
) -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    self.create(manager, config)
  })
}
