///|
fn[T] unavailable_from_error(message : String) -> @util.Availability[T] {
  @util.Unavailable(
    @util.AvailabilityReason::unknown(@util.ReasonUnknown::Other(message)),
  )
}

///|
fn reason_unknown_from_smt_text(reason : String) -> @util.ReasonUnknown {
  match reason {
    "timeout" => @util.ReasonUnknown::Timeout
    "memout" => @util.ReasonUnknown::Memout
    "max-conflicts" => @util.ReasonUnknown::MaxConflictsReached
    "resource-limit-exceeded" => @util.ReasonUnknown::ResourceLimitExceeded
    "invalid-core" => @util.ReasonUnknown::InvalidCore
    "invalid-proof" => @util.ReasonUnknown::InvalidProof
    "invalid-model" => @util.ReasonUnknown::InvalidModel
    "model-eval-failed" => @util.ReasonUnknown::ModelEvalFailed
    "model-validation-failed" => @util.ReasonUnknown::ModelValidationFailed
    _ => @util.ReasonUnknown::Other(reason)
  }
}

///|
fn solver_core_from_smt_entries(
  entries : Array[@smt.SmtUnsatCoreEntry],
) -> @solver.UnsatCore {
  let mut core = @solver.UnsatCore::empty()
  for entry in entries {
    core = core.with_entry(
      @solver.UnsatCoreEntry::new(entry.expr(), entry.name()),
    )
  }
  core
}

///|
priv struct TrackedEufRecord {
  formula : @util.ExprId
  tracker : @util.ExprId
}

///|
fn adapter_expr_array_contains(
  values : Array[@util.ExprId],
  value : @util.ExprId,
) -> Bool {
  for existing in values {
    if existing == value {
      return true
    }
  }
  false
}

///|
fn tracked_euf_formula(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  polarity : Bool,
) -> Bool {
  let expanded = manager.expand_macros(expr) catch { _ => return false }
  let expr = expanded.result()
  match manager.get_expr(expr).kind {
    MacroRef(_) => false
    Not(inner) => tracked_euf_formula(manager, inner, !polarity)
    And(args) =>
      if polarity {
        let mut any_euf = false
        for arg in args {
          if !tracked_euf_formula(manager, arg, true) {
            return false
          }
          any_euf = true
        }
        any_euf
      } else {
        false
      }
    Eq(lhs, rhs) =>
      manager.expr_sort(lhs) != manager.bool_sort() &&
      manager.expr_sort(rhs) != manager.bool_sort()
    Distinct(args) =>
      args.length() > 0 &&
      manager.expr_sort(args[0]) != manager.bool_sort() &&
      (polarity || args.length() == 2)
    BoolValue(_)
    | IntValue(_)
    | App(_, _)
    | ArithCompare(_, _, _)
    | Or(_)
    | Implies(_, _)
    | Xor(_, _) => false
  }
}

///|
fn tracked_bool_formula(manager : @ast.AstManager, expr : @util.ExprId) -> Bool {
  if manager.expr_sort(expr) != manager.bool_sort() {
    return false
  }
  let expanded = manager.expand_macros(expr) catch { _ => return false }
  let expr = expanded.result()
  match manager.get_expr(expr).kind {
    BoolValue(_) => true
    MacroRef(_) => false
    App(_, args) => args.is_empty()
    Not(inner) => tracked_bool_formula(manager, inner)
    And(args) | Or(args) => {
      for arg in args {
        if !tracked_bool_formula(manager, arg) {
          return false
        }
      }
      true
    }
    Implies(lhs, rhs) | Xor(lhs, rhs) =>
      tracked_bool_formula(manager, lhs) && tracked_bool_formula(manager, rhs)
    Eq(lhs, rhs) =>
      manager.expr_sort(lhs) == manager.bool_sort() &&
      manager.expr_sort(rhs) == manager.bool_sort() &&
      tracked_bool_formula(manager, lhs) &&
      tracked_bool_formula(manager, rhs)
    ArithCompare(_, _, _) => false
    IntValue(_) => false
    Distinct(args) => {
      for arg in args {
        if !tracked_bool_formula(manager, arg) {
          return false
        }
      }
      true
    }
  }
}

///|
fn tracked_mixed_conjunction_parts(
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> (Array[@util.ExprId], Array[@util.ExprId])? {
  let bool_parts : Array[@util.ExprId] = []
  let euf_parts : Array[@util.ExprId] = []
  if !tracked_collect_mixed_conjunction_parts(
      manager, expr, true, bool_parts, euf_parts,
    ) {
    return None
  }
  if !bool_parts.is_empty() && !euf_parts.is_empty() {
    Some((bool_parts, euf_parts))
  } else {
    None
  }
}

///|
fn tracked_collect_mixed_conjunction_parts(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  polarity : Bool,
  bool_parts : Array[@util.ExprId],
  euf_parts : Array[@util.ExprId],
) -> Bool {
  let expanded = manager.expand_macros(expr) catch { _ => return false }
  match manager.get_expr(expanded.result()).kind {
    Not(inner) =>
      tracked_collect_mixed_conjunction_parts(
        manager,
        inner,
        !polarity,
        bool_parts,
        euf_parts,
      )
    And(args) if polarity => {
      for arg in args {
        if !tracked_collect_mixed_conjunction_parts(
            manager, arg, true, bool_parts, euf_parts,
          ) {
          return false
        }
      }
      true
    }
    Or(args) if !polarity => {
      for arg in args {
        if !tracked_collect_mixed_conjunction_parts(
            manager, arg, false, bool_parts, euf_parts,
          ) {
          return false
        }
      }
      true
    }
    Implies(lhs, rhs) if !polarity =>
      tracked_collect_mixed_conjunction_parts(
        manager, lhs, true, bool_parts, euf_parts,
      ) &&
      tracked_collect_mixed_conjunction_parts(
        manager, rhs, false, bool_parts, euf_parts,
      )
    _ =>
      tracked_collect_mixed_conjunction_leaf(
        manager, expr, polarity, bool_parts, euf_parts,
      )
  }
}

///|
fn tracked_collect_mixed_conjunction_leaf(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  polarity : Bool,
  bool_parts : Array[@util.ExprId],
  euf_parts : Array[@util.ExprId],
) -> Bool {
  let root = tracked_polarized_root(manager, expr, polarity) catch {
    _ => return false
  }
  if tracked_euf_formula(manager, expr, polarity) {
    euf_parts.push(root)
    true
  } else if tracked_bool_formula(manager, root) {
    bool_parts.push(root)
    true
  } else {
    false
  }
}

///|
fn tracked_polarized_root(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  polarity : Bool,
) -> @util.ExprId raise {
  if polarity {
    expr
  } else {
    manager.mk_not(expr)
  }
}

///|
fn assert_tracked_bool_formula(
  manager : @ast.AstManager,
  concrete : @smt.Solver,
  tracker : @util.ExprId,
  expr : @util.ExprId,
) -> @util.Availability[Unit] {
  let implication = manager.mk_implies(tracker, expr) catch {
    err => return unavailable_from_error(err.to_string())
  }
  concrete.assert_expr(implication) catch {
    err => return unavailable_from_error(err.to_string())
  }
  @util.Available(())
}

///|
fn tracked_euf_active_formula(
  records : Array[TrackedEufRecord],
  expr : @util.ExprId,
) -> @util.ExprId? {
  for record in records {
    if record.formula == expr {
      return Some(record.tracker)
    }
  }
  None
}

///|
fn tracked_euf_map_core_expr(
  records : Array[TrackedEufRecord],
  expr : @util.ExprId,
) -> @util.ExprId {
  match tracked_euf_active_formula(records, expr) {
    Some(tracker) => tracker
    None => expr
  }
}

///|
fn tracked_euf_record_contains(
  records : Array[TrackedEufRecord],
  formula : @util.ExprId,
  tracker : @util.ExprId,
) -> Bool {
  for record in records {
    if record.formula == formula && record.tracker == tracker {
      return true
    }
  }
  false
}

///|
fn record_tracked_euf_proof_owner(
  result : Array[TrackedEufRecord],
  records : Array[TrackedEufRecord],
  expr : @util.ExprId,
) -> Unit {
  match tracked_euf_active_formula(records, expr) {
    Some(tracker) =>
      if !tracked_euf_record_contains(result, expr, tracker) {
        result.push(TrackedEufRecord::{ formula: expr, tracker })
      }
    None => ()
  }
}

///|
fn rewrite_tracked_euf_proof_object(
  manager : @ast.AstManager,
  proof : @proof.ProofObject,
  records : Array[TrackedEufRecord],
) -> @proof.ProofObject {
  let mut root = proof.root_text()
  for record in records {
    root = root.replace_all(
      old=manager.pretty(record.formula),
      new=manager.pretty(record.tracker),
    )
  }
  @proof.ProofObject::from_root_and_hints(root, proof.hints())
}

///|
fn tracked_euf_augmented_assumptions(
  assumptions : @solver.AssumptionSet,
  records : Array[TrackedEufRecord],
) -> @solver.AssumptionSet {
  let result = @solver.AssumptionSet::new()
  let assumption_items = assumptions.items()
  for assumption in assumption_items {
    result.add(assumption)
  }
  for record in records {
    if adapter_expr_array_contains(assumption_items, record.tracker) {
      result.add(record.formula)
    }
  }
  result
}

///|
fn solver_assumptions_from_smt_result(
  core : Array[@util.ExprId],
  entries : Array[@smt.SmtUnsatCoreEntry],
  tracked_euf_records : Array[TrackedEufRecord],
) -> @solver.UnsatAssumptionSet {
  let assumptions : Array[@util.ExprId] = []
  for expr in core {
    let owner = tracked_euf_map_core_expr(tracked_euf_records, expr)
    if !adapter_expr_array_contains(assumptions, owner) {
      assumptions.push(owner)
    }
  }
  for entry in entries {
    let expr = entry.expr()
    let mut found = false
    for existing in assumptions {
      if existing == expr {
        found = true
      }
    }
    if !found {
      assumptions.push(expr)
    }
  }
  @solver.UnsatAssumptionSet::from_exprs(assumptions)
}

///|
fn check_sat_assuming_concrete(
  concrete : @smt.Solver,
  assumptions : @solver.AssumptionSet,
  tracked_euf_records : Array[TrackedEufRecord],
  tracked_euf_proof_records : Array[TrackedEufRecord],
) -> @solver.CheckSatAssumingResult {
  tracked_euf_proof_records.truncate(0)
  let concrete_assumptions = tracked_euf_augmented_assumptions(
    assumptions, tracked_euf_records,
  )
  match concrete.check_sat_assuming(concrete_assumptions.items()) {
    @smt.AssumptionSat =>
      @solver.CheckSatAssumingResult::from_result(@solver.CheckSatResult::sat())
    @smt.AssumptionUnsat(core, entries) => {
      for expr in core {
        record_tracked_euf_proof_owner(
          tracked_euf_proof_records, tracked_euf_records, expr,
        )
      }
      @solver.CheckSatAssumingResult::new_with_core(
        @solver.CheckSatResult::unsat(),
        solver_assumptions_from_smt_result(core, entries, tracked_euf_records),
        solver_core_from_smt_entries(entries),
      )
    }
    @smt.AssumptionUnknown(reason) =>
      @solver.CheckSatAssumingResult::from_result(
        @solver.CheckSatResult::unknown_no_model(
          reason_unknown_from_smt_text(reason),
        ),
      )
  }
}

///|
fn setup_mode(config : @solver.SolverFactoryConfig) -> @smt.SmtSetupMode {
  @smt.SmtSetupMode::logic(config.logic())
}

///|
fn default_theory_registry(manager : @ast.AstManager) -> @smt.TheoryRegistry {
  let registry = @smt.TheoryRegistry::new()
  registry.register(
    @euf_solver.euf_theory_factory(
      @theory_ids.TheoryId::new(1),
      manager.uf_family(),
    ),
  )
  registry
}

///|
fn default_theory_registry_with_theory_factories(
  manager : @ast.AstManager,
  extra_factories : Array[@theory_core.TheoryFactory],
) -> @smt.TheoryRegistry {
  let registry = default_theory_registry(manager)
  for factory in extra_factories {
    registry.register(factory)
  }
  registry
}

///|
pub fn configured_theory_names(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
) -> String {
  configured_theory_names_with_theory_factories(manager, config, [])
}

///|
pub fn configured_theory_names_with_theory_factories(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
  extra_factories : Array[@theory_core.TheoryFactory],
) -> String {
  @smt.setup_selected_names(
    default_theory_registry_with_theory_factories(manager, extra_factories),
    setup_mode(config),
  )
}

///|
pub fn new_concrete_solver(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
) -> @smt.Solver {
  new_concrete_solver_with_theory_factories(manager, config, [])
}

///|
pub fn new_concrete_solver_with_theory_factories(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
  extra_factories : Array[@theory_core.TheoryFactory],
) -> @smt.Solver {
  new_concrete_solver_with_registry(
    manager,
    config,
    default_theory_registry_with_theory_factories(manager, extra_factories),
  )
}

///|
pub fn new_concrete_solver_with_registry(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
  registry : @smt.TheoryRegistry,
) -> @smt.Solver {
  let concrete = @smt.Solver::new(manager)
  concrete.setup_theories(registry, setup_mode(config), config.params())
  concrete
}

///|
fn backend_from_concrete(
  manager : @ast.AstManager,
  _config : @solver.SolverFactoryConfig,
  concrete : @smt.Solver,
  make_concrete : (@ast.AstManager, @solver.SolverFactoryConfig) -> @smt.Solver,
) -> @solver.SolverBackend {
  let tracked_euf_records : Array[TrackedEufRecord] = []
  let tracked_euf_scopes : Array[Int] = []
  let tracked_euf_proof_records : Array[TrackedEufRecord] = []
  @solver.SolverBackend::new(
    assert_expr=fn(expr) {
      concrete.assert_expr(expr) catch {
        err => return unavailable_from_error(err.to_string())
      }
      @util.Available(())
    },
    assert_expr_tracked=fn(expr, tracked) {
      if tracked_euf_formula(manager, expr, true) {
        tracked_euf_records.push(TrackedEufRecord::{
          formula: expr,
          tracker: tracked.tracker(),
        })
        return @util.Available(())
      }
      match tracked_mixed_conjunction_parts(manager, expr) {
        Some((bool_parts, euf_parts)) => {
          for part in bool_parts {
            match
              assert_tracked_bool_formula(
                manager,
                concrete,
                tracked.tracker(),
                part,
              ) {
              @util.Available(_) => ()
              @util.Unavailable(reason) => return @util.Unavailable(reason)
            }
          }
          for part in euf_parts {
            tracked_euf_records.push(TrackedEufRecord::{
              formula: part,
              tracker: tracked.tracker(),
            })
          }
          return @util.Available(())
        }
        None => ()
      }
      assert_tracked_bool_formula(manager, concrete, tracked.tracker(), expr)
    },
    push=fn(count) {
      concrete.push(count) catch {
        err => return unavailable_from_error(err.to_string())
      }
      if count > 0 {
        for _ in 0..<count {
          tracked_euf_scopes.push(tracked_euf_records.length())
        }
      }
      @util.Available(())
    },
    pop=fn(count) {
      concrete.pop(count) catch {
        err => return unavailable_from_error(err.to_string())
      }
      if count > 0 {
        let depth = tracked_euf_scopes.length()
        if depth > 0 {
          let pop_count = if count > depth { depth } else { count }
          let target_depth = depth - pop_count
          tracked_euf_records.truncate(tracked_euf_scopes[target_depth])
          tracked_euf_scopes.truncate(target_depth)
        }
      }
      @util.Available(())
    },
    check_sat_assuming=fn(assumptions) {
      check_sat_assuming_concrete(
        concrete, assumptions, tracked_euf_records, tracked_euf_proof_records,
      )
    },
    model=fn() {
      match concrete.get_model() {
        Some(model) => @util.Available(model)
        None => @util.Unavailable(@util.AvailabilityReason::NoCurrentResult)
      }
    },
    proof=fn() {
      match concrete.checked_proof_object() {
        @util.Available(proof) =>
          @proof.ProofHandle::from_object(
            0,
            @proof.ProofKind::ast(),
            rewrite_tracked_euf_proof_object(
              manager, proof, tracked_euf_proof_records,
            ),
          ).view()
        @util.Unavailable(reason) => @util.Unavailable(reason)
      }
    },
    collect_statistics=fn() { @stats.Statistics::new() },
    translate=fn(target, translated_config) {
      @util.Available(
        backend_from_concrete(
          target,
          translated_config,
          make_concrete(target, translated_config),
          make_concrete,
        ),
      )
    },
  )
}

///|
fn solver_from_concrete(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
  concrete : @smt.Solver,
  make_concrete : (@ast.AstManager, @solver.SolverFactoryConfig) -> @smt.Solver,
) -> @solver.Solver {
  let backend = backend_from_concrete(manager, config, concrete, make_concrete)
  @solver.Solver::new(manager, config, backend)
}

///|
pub fn new_solver_with_registry(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
  registry : @smt.TheoryRegistry,
) -> @solver.Solver {
  let make_concrete = fn(
    target : @ast.AstManager,
    target_config : @solver.SolverFactoryConfig,
  ) {
    new_concrete_solver_with_registry(target, target_config, registry)
  }
  solver_from_concrete(
    manager,
    config,
    make_concrete(manager, config),
    make_concrete,
  )
}

///|
pub fn new_solver(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
) -> @solver.Solver {
  new_solver_with_theory_factories(manager, config, [])
}

///|
pub fn new_solver_with_theory_factories(
  manager : @ast.AstManager,
  config : @solver.SolverFactoryConfig,
  extra_factories : Array[@theory_core.TheoryFactory],
) -> @solver.Solver {
  let make_concrete = fn(
    target : @ast.AstManager,
    target_config : @solver.SolverFactoryConfig,
  ) {
    new_concrete_solver_with_theory_factories(
      target, target_config, extra_factories,
    )
  }
  solver_from_concrete(
    manager,
    config,
    make_concrete(manager, config),
    make_concrete,
  )
}

///|
pub fn default_factory() -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) { new_solver(manager, config) })
}

///|
pub fn factory_with_theory_factories(
  extra_factories : Array[@theory_core.TheoryFactory],
) -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    new_solver_with_theory_factories(manager, config, extra_factories)
  })
}
