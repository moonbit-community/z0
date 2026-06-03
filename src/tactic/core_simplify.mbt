///|
fn simplify_unavailable(message : String) -> @util.Availability[TacticResult] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment("simplify:\{message}"),
    ),
  )
}

///|
fn Goal::simplified_copy(self : Goal) -> Goal {
  {
    manager: self.manager,
    formulas: [],
    precision: self.precision,
    depth: self.depth + 1,
    reason_unknown: self.reason_unknown,
    model_converter: self.model_converter,
    proof_converter: self.proof_converter,
    dependency_converter: self.dependency_converter,
    requires_model: self.requires_model,
    requires_proof: self.requires_proof,
    requires_unsat_core: self.requires_unsat_core,
  }
}

///|
fn bool_value(manager : @ast.AstManager, expr : @util.ExprId) -> Bool? {
  match manager.get_expr(expr).kind {
    BoolValue(value) => Some(value)
    _ => None
  }
}

///|
pub fn Tactic::simplify() -> Tactic {
  Tactic::new("simplify", fn(goal) {
    let simplified = goal.simplified_copy()
    for formula in goal.formulas {
      let rewritten = @rewriter.rewrite_bool(goal.manager, formula) catch {
        err => return simplify_unavailable(err.to_string())
      }
      match bool_value(goal.manager, rewritten) {
        Some(true) => ()
        Some(false) => {
          simplified.add(rewritten)
          return @util.Available(TacticResult::from_goals([simplified]))
        }
        None => simplified.add(rewritten)
      }
    }
    @util.Available(TacticResult::from_goals([simplified]))
  })
}
