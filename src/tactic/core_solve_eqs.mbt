///|
priv struct SolveEqSubstitution {
  source : @util.ExprId
  target : @util.ExprId
}

///|
fn solve_eqs_unavailable(message : String) -> @util.Availability[TacticResult] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment("solve-eqs:\{message}"),
    ),
  )
}

///|
fn solve_eqs_is_zero_arity_const(
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> Bool {
  match manager.get_expr(expr).kind {
    App(_, args) => args.is_empty()
    _ => false
  }
}

///|
fn solve_eqs_contains(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  needle : @util.ExprId,
) -> Bool {
  if expr == needle {
    return true
  }
  match manager.get_expr(expr).kind {
    BoolValue(_) | IntValue(_) | MacroRef(_) => false
    App(_, args) | And(args) | Or(args) | Distinct(args) => {
      for arg in args {
        if solve_eqs_contains(manager, arg, needle) {
          return true
        }
      }
      false
    }
    Not(inner) => solve_eqs_contains(manager, inner, needle)
    Implies(lhs, rhs)
    | Xor(lhs, rhs)
    | Eq(lhs, rhs)
    | ArithCompare(_, lhs, rhs) =>
      solve_eqs_contains(manager, lhs, needle) ||
      solve_eqs_contains(manager, rhs, needle)
  }
}

///|
fn solve_eqs_assignment(
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> SolveEqSubstitution? {
  match manager.get_expr(expr).kind {
    Eq(lhs, rhs) =>
      if lhs == rhs {
        None
      } else if solve_eqs_is_zero_arity_const(manager, lhs) &&
        !solve_eqs_contains(manager, rhs, lhs) {
        Some({ source: lhs, target: rhs })
      } else if solve_eqs_is_zero_arity_const(manager, rhs) &&
        !solve_eqs_contains(manager, lhs, rhs) {
        Some({ source: rhs, target: lhs })
      } else {
        None
      }
    _ => None
  }
}

///|
fn solve_eqs_lookup_substitution(
  substitutions : Array[SolveEqSubstitution],
  expr : @util.ExprId,
) -> @util.ExprId? {
  for substitution in substitutions {
    if substitution.source == expr {
      return Some(substitution.target)
    }
  }
  None
}

///|
fn solve_eqs_substitute_args(
  manager : @ast.AstManager,
  args : Array[@util.ExprId],
  substitutions : Array[SolveEqSubstitution],
  fuel : Int,
) -> Array[@util.ExprId] raise {
  let substituted : Array[@util.ExprId] = []
  for arg in args {
    substituted.push(solve_eqs_substitute(manager, arg, substitutions, fuel))
  }
  substituted
}

///|
fn solve_eqs_substitute(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  substitutions : Array[SolveEqSubstitution],
  fuel : Int,
) -> @util.ExprId raise {
  match solve_eqs_lookup_substitution(substitutions, expr) {
    Some(target) =>
      if fuel <= 0 {
        expr
      } else {
        solve_eqs_substitute(manager, target, substitutions, fuel - 1)
      }
    None =>
      match manager.get_expr(expr).kind {
        BoolValue(_) | IntValue(_) | MacroRef(_) => expr
        App(decl, args) =>
          if args.is_empty() {
            expr
          } else {
            manager.mk_app(
              decl,
              solve_eqs_substitute_args(manager, args, substitutions, fuel),
            )
          }
        Not(inner) =>
          manager.mk_not(
            solve_eqs_substitute(manager, inner, substitutions, fuel),
          )
        And(args) =>
          manager.mk_and(
            solve_eqs_substitute_args(manager, args, substitutions, fuel),
          )
        Or(args) =>
          manager.mk_or(
            solve_eqs_substitute_args(manager, args, substitutions, fuel),
          )
        Implies(lhs, rhs) =>
          manager.mk_implies(
            solve_eqs_substitute(manager, lhs, substitutions, fuel),
            solve_eqs_substitute(manager, rhs, substitutions, fuel),
          )
        Xor(lhs, rhs) =>
          manager.mk_xor(
            solve_eqs_substitute(manager, lhs, substitutions, fuel),
            solve_eqs_substitute(manager, rhs, substitutions, fuel),
          )
        Eq(lhs, rhs) =>
          manager.mk_eq(
            solve_eqs_substitute(manager, lhs, substitutions, fuel),
            solve_eqs_substitute(manager, rhs, substitutions, fuel),
          )
        Distinct(args) =>
          manager.mk_distinct(
            solve_eqs_substitute_args(manager, args, substitutions, fuel),
          )
        ArithCompare(op, lhs, rhs) =>
          manager.mk_arith_compare(
            op,
            solve_eqs_substitute(manager, lhs, substitutions, fuel),
            solve_eqs_substitute(manager, rhs, substitutions, fuel),
          )
      }
  }
}

///|
fn solve_eqs_rewrite(
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> @util.ExprId raise {
  @rewriter.rewrite_bool(manager, expr)
}

///|
fn solve_eqs_substitute_and_rewrite(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  substitutions : Array[SolveEqSubstitution],
) -> @util.ExprId raise {
  solve_eqs_rewrite(
    manager,
    solve_eqs_substitute(
      manager,
      expr,
      substitutions,
      substitutions.length() + 1,
    ),
  )
}

///|
fn solve_eqs_add_residual(goal : Goal, formula : @util.ExprId) -> Bool {
  match bool_value(goal.manager, formula) {
    Some(true) => false
    Some(false) => {
      goal.add(formula)
      true
    }
    None => {
      goal.add(formula)
      false
    }
  }
}

///|
pub fn Tactic::solve_eqs() -> Tactic {
  Tactic::new("solve-eqs", fn(goal) {
    let solved = goal.simplified_copy()
    let substitutions : Array[SolveEqSubstitution] = []
    let pending : Array[@util.ExprId] = []
    for formula in goal.formulas {
      let rewritten = solve_eqs_rewrite(goal.manager, formula) catch {
        err => return solve_eqs_unavailable(err.to_string())
      }
      let normalized = solve_eqs_substitute_and_rewrite(
        goal.manager,
        rewritten,
        substitutions,
      ) catch {
        err => return solve_eqs_unavailable(err.to_string())
      }
      match bool_value(goal.manager, normalized) {
        Some(true) => ()
        Some(false) => {
          solved.add(normalized)
          return @util.Available(TacticResult::from_goals([solved]))
        }
        None =>
          match solve_eqs_assignment(goal.manager, normalized) {
            Some(substitution) => substitutions.push(substitution)
            None => pending.push(normalized)
          }
      }
    }
    for formula in pending {
      let residual = solve_eqs_substitute_and_rewrite(
        goal.manager,
        formula,
        substitutions,
      ) catch {
        err => return solve_eqs_unavailable(err.to_string())
      }
      if solve_eqs_add_residual(solved, residual) {
        return @util.Available(TacticResult::from_goals([solved]))
      }
    }
    @util.Available(TacticResult::from_goals([solved]))
  })
}
