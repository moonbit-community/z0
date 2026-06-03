///|
pub struct SolverBackend {
  priv assert_expr_fn : (@util.ExprId) -> @util.Availability[Unit]
  priv assert_expr_tracked_fn : (@util.ExprId, TrackedExpr) -> @util.Availability[
    Unit,
  ]
  priv push_fn : (Int) -> @util.Availability[Unit]
  priv pop_fn : (Int) -> @util.Availability[Unit]
  priv check_sat_assuming_fn : (AssumptionSet) -> CheckSatAssumingResult
  priv model_fn : () -> @util.Availability[@model.Model]
  priv proof_fn : () -> @util.Availability[@proof.ProofRef]
  priv collect_statistics_fn : () -> @stats.Statistics
  priv translate_fn : (@ast.AstManager, SolverFactoryConfig) -> @util.Availability[
    SolverBackend,
  ]
}

///|
fn backend_translate_unsupported(
  _target : @ast.AstManager,
  _config : SolverFactoryConfig,
) -> @util.Availability[SolverBackend] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment("translate"),
    ),
  )
}

///|
pub fn SolverBackend::new(
  assert_expr~ : (@util.ExprId) -> @util.Availability[Unit],
  assert_expr_tracked~ : (@util.ExprId, TrackedExpr) -> @util.Availability[Unit],
  push~ : (Int) -> @util.Availability[Unit],
  pop~ : (Int) -> @util.Availability[Unit],
  check_sat_assuming~ : (AssumptionSet) -> CheckSatAssumingResult,
  model~ : () -> @util.Availability[@model.Model],
  proof~ : () -> @util.Availability[@proof.ProofRef],
  collect_statistics~ : () -> @stats.Statistics,
  translate? : (@ast.AstManager, SolverFactoryConfig) -> @util.Availability[
    SolverBackend,
  ] = backend_translate_unsupported,
) -> SolverBackend {
  SolverBackend::{
    assert_expr_fn: assert_expr,
    assert_expr_tracked_fn: assert_expr_tracked,
    push_fn: push,
    pop_fn: pop,
    check_sat_assuming_fn: check_sat_assuming,
    model_fn: model,
    proof_fn: proof,
    collect_statistics_fn: collect_statistics,
    translate_fn: translate,
  }
}

///|
priv struct TrackedAssertionRecord {
  assertion_index : Int
  tracked : TrackedExpr
}

///|
pub struct StatisticsSnapshot {
  priv stats : @stats.Statistics
  priv incomplete_reasons : Array[@util.ReasonUnknown]
}

///|
pub fn StatisticsSnapshot::new(
  stats : @stats.Statistics,
  incomplete_reasons : Array[@util.ReasonUnknown],
) -> StatisticsSnapshot {
  { stats, incomplete_reasons: incomplete_reasons.copy() }
}

///|
pub fn StatisticsSnapshot::keys_text(self : StatisticsSnapshot) -> String {
  self.stats.keys_text()
}

///|
pub fn StatisticsSnapshot::incomplete_reasons_text(
  self : StatisticsSnapshot,
) -> String {
  let parts : Array[String] = []
  for reason in self.incomplete_reasons {
    parts.push(reason.to_text())
  }
  parts.join(",")
}

///|
fn solver_statistics_manifest() -> @stats.StatManifest {
  let manifest = @stats.StatManifest::new()
  ignore(
    manifest.add_counter(
      "solver.checks",
      "solver",
      @stats.StatMergePolicy::sum(),
      "",
    ),
  )
  ignore(
    manifest.add_counter(
      "model.queries",
      "model",
      @stats.StatMergePolicy::sum(),
      "",
    ),
  )
  ignore(
    manifest.add_counter(
      "proof.queries",
      "proof",
      @stats.StatMergePolicy::sum(),
      "",
    ),
  )
  ignore(
    manifest.add_counter(
      "sat.core.clauses",
      "sat.core",
      @stats.StatMergePolicy::sum(),
      "",
    ),
  )
  ignore(
    manifest.add_counter(
      "sat.core.decisions",
      "sat.core",
      @stats.StatMergePolicy::sum(),
      "",
    ),
  )
  ignore(
    manifest.add_counter(
      "sat.core.deleted_clauses",
      "sat.core",
      @stats.StatMergePolicy::sum(),
      "",
    ),
  )
  ignore(
    manifest.add_counter(
      "sat.core.learned_clauses",
      "sat.core",
      @stats.StatMergePolicy::sum(),
      "",
    ),
  )
  ignore(
    manifest.add_counter(
      "sat.core.propagations",
      "sat.core",
      @stats.StatMergePolicy::sum(),
      "",
    ),
  )
  ignore(
    manifest.add_counter(
      "sat.core.vars",
      "sat.core",
      @stats.StatMergePolicy::sum(),
      "",
    ),
  )
  manifest
}

///|
pub struct Solver {
  priv manager : @ast.AstManager
  priv mut config : SolverFactoryConfig
  priv backend : SolverBackend
  priv assertions : @util.ScopedVector[@util.ExprId]
  priv tracked_assertions : @util.ScopedVector[TrackedAssertionRecord]
  priv statistics : @stats.Statistics
  priv mut current_result : CheckSatResult?
  priv mut stale_result : Bool
  priv mut next_tracked_assertion_id : Int
  priv mut last_unsat_core : UnsatCore
  priv mut last_unsat_assumptions : UnsatAssumptionSet
}

///|
pub fn Solver::new(
  manager : @ast.AstManager,
  config : SolverFactoryConfig,
  backend : SolverBackend,
) -> Solver {
  Solver::{
    manager,
    config,
    backend,
    assertions: @util.ScopedVector::new(),
    tracked_assertions: @util.ScopedVector::new(),
    statistics: @stats.Statistics::new(),
    current_result: None,
    stale_result: false,
    next_tracked_assertion_id: 0,
    last_unsat_core: UnsatCore::empty(),
    last_unsat_assumptions: UnsatAssumptionSet::empty(),
  }
}

///|
fn unavailable_unit(
  reason : @util.AvailabilityReason,
) -> @util.Availability[Unit] {
  @util.Unavailable(reason)
}

///|
fn unsupported_reason(feature : String) -> @util.AvailabilityReason {
  @util.AvailabilityReason::unsupported(
    @util.ReasonUnknown::unsupported_fragment(feature),
  )
}

///|
fn tracked_name(tracked : TrackedExpr) -> String {
  let display = tracked.display_name()
  if display == "" {
    "\{tracked.tracker()}"
  } else {
    display
  }
}

///|
fn tracked_record_for_assertion_index(
  records : Array[TrackedAssertionRecord],
  assertion_index : Int,
) -> TrackedAssertionRecord? {
  for record in records {
    if record.assertion_index == assertion_index {
      return Some(record)
    }
  }
  None
}

///|
fn Solver::validate_assertion_expr(
  self : Solver,
  expr : @util.ExprId,
) -> @util.Availability[Unit] {
  if self.manager.expr_sort(expr) == self.manager.bool_sort() {
    @util.Available(())
  } else {
    @util.Unavailable(
      unsupported_reason("non-bool-assertion:\{self.manager.pretty(expr)}"),
    )
  }
}

///|
fn Solver::mark_result_stale(self : Solver) -> Unit {
  match self.current_result {
    Some(_) => self.stale_result = true
    None => ()
  }
}

///|
pub fn Solver::assert_expr(
  self : Solver,
  expr : @util.ExprId,
) -> @util.Availability[Unit] {
  match self.validate_assertion_expr(expr) {
    @util.Unavailable(reason) => unavailable_unit(reason)
    @util.Available(_) =>
      match (self.backend.assert_expr_fn)(expr) {
        @util.Available(_) => {
          self.assertions.push_item(expr)
          self.mark_result_stale()
          @util.Available(())
        }
        @util.Unavailable(reason) => unavailable_unit(reason)
      }
  }
}

///|
pub fn Solver::push(self : Solver, count : Int) -> @util.Availability[Unit] {
  if count < 0 {
    unavailable_unit(unsupported_reason("negative-push"))
  } else {
    match (self.backend.push_fn)(count) {
      @util.Available(_) => {
        for _ in 0..<count {
          self.assertions.push_scope()
          self.tracked_assertions.push_scope()
        }
        self.mark_result_stale()
        @util.Available(())
      }
      @util.Unavailable(reason) => unavailable_unit(reason)
    }
  }
}

///|
pub fn Solver::pop(self : Solver, count : Int) -> @util.Availability[Unit] {
  if count < 0 || count > self.assertions.scope_depth() {
    unavailable_unit(unsupported_reason("invalid-pop"))
  } else {
    match (self.backend.pop_fn)(count) {
      @util.Available(_) => {
        self.assertions.pop_scope(count) catch {
          _ => return unavailable_unit(unsupported_reason("invalid-pop"))
        }
        self.tracked_assertions.pop_scope(count) catch {
          _ => return unavailable_unit(unsupported_reason("invalid-pop"))
        }
        self.mark_result_stale()
        @util.Available(())
      }
      @util.Unavailable(reason) => unavailable_unit(reason)
    }
  }
}

///|
fn Solver::duplicate_tracked_assertion(
  self : Solver,
  tracked : TrackedExpr,
) -> Bool {
  let name = tracked.display_name()
  for record in self.tracked_assertions.items() {
    if record.tracked.tracker() == tracked.tracker() {
      return true
    }
    if name != "" && record.tracked.display_name() == name {
      return true
    }
  }
  false
}

///|
fn Solver::tracker_is_bool_const(self : Solver, tracker : @util.ExprId) -> Bool {
  if self.manager.expr_sort(tracker) != self.manager.bool_sort() {
    return false
  }
  match self.manager.get_expr(tracker).kind {
    @ast.App(decl_id, args) =>
      if !args.is_empty() {
        false
      } else {
        let decl = self.manager.get_decl(decl_id)
        decl.domain.is_empty() &&
        decl.range == self.manager.bool_sort() &&
        decl.family == self.manager.uf_family()
      }
    _ => false
  }
}

///|
fn Solver::validate_tracked_expr(
  self : Solver,
  tracked : TrackedExpr,
) -> @util.Availability[Unit] {
  let tracker = tracked.tracker()
  if self.tracker_is_bool_const(tracker) {
    @util.Available(())
  } else {
    @util.Unavailable(
      unsupported_reason("invalid-tracker:\{self.manager.pretty(tracker)}"),
    )
  }
}

///|
fn Solver::tracked_assumption_set(self : Solver) -> AssumptionSet {
  let assumptions = AssumptionSet::new()
  for record in self.tracked_assertions.items() {
    assumptions.add(record.tracked.tracker())
  }
  assumptions
}

///|
fn Solver::tracked_entry_for_expr(
  self : Solver,
  expr : @util.ExprId,
) -> UnsatCoreEntry? {
  for record in self.tracked_assertions.items() {
    if record.tracked.tracker() == expr {
      let name = record.tracked.display_name()
      return Some(
        UnsatCoreEntry::new(expr, if name == "" { None } else { Some(name) }),
      )
    }
  }
  None
}

///|
fn Solver::core_from_tracked_assumptions(
  self : Solver,
  assumptions : UnsatAssumptionSet,
) -> UnsatCore {
  let entries : Array[UnsatCoreEntry] = []
  for assumption in assumptions.items() {
    match self.tracked_entry_for_expr(assumption) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  UnsatCore::from_entries(entries)
}

///|
fn Solver::core_from_assumption_owners(
  self : Solver,
  call_assumptions : AssumptionSet,
  assumptions : UnsatAssumptionSet,
) -> UnsatCore {
  let call_items = call_assumptions.items()
  let entries : Array[UnsatCoreEntry] = []
  for assumption in assumptions.items() {
    match self.tracked_entry_for_expr(assumption) {
      Some(entry) => entries.push(entry)
      None =>
        if expr_array_contains(call_items, assumption) {
          entries.push(UnsatCoreEntry::new(assumption, None))
        }
    }
  }
  UnsatCore::from_entries(entries)
}

///|
fn expr_array_contains(
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
fn push_unique_expr(values : Array[@util.ExprId], value : @util.ExprId) -> Unit {
  if !expr_array_contains(values, value) {
    values.push(value)
  }
}

///|
fn Solver::assumptions_from_core_owners(
  self : Solver,
  call_assumptions : AssumptionSet,
  core_assumptions : UnsatAssumptionSet,
) -> UnsatAssumptionSet {
  let call_items = call_assumptions.items()
  let result : Array[@util.ExprId] = []
  for assumption in core_assumptions.items() {
    match self.tracked_entry_for_expr(assumption) {
      Some(_) => push_unique_expr(result, assumption)
      None =>
        if expr_array_contains(call_items, assumption) {
          push_unique_expr(result, assumption)
        }
    }
  }
  UnsatAssumptionSet::from_exprs(result)
}

///|
fn Solver::combined_assumption_set(
  self : Solver,
  call_assumptions : AssumptionSet,
) -> AssumptionSet {
  let combined = self.tracked_assumption_set()
  for assumption in call_assumptions.items() {
    combined.add(assumption)
  }
  combined
}

///|
pub fn Solver::check_sat(self : Solver) -> CheckSatResult {
  let tracked_assumptions = self.tracked_assumption_set()
  let assumption_result = (self.backend.check_sat_assuming_fn)(
    tracked_assumptions,
  )
  let core_assumptions = assumption_result.unsat_assumptions()
  let result = assumption_result.result()
  self.current_result = Some(result)
  self.stale_result = false
  self.last_unsat_core = match result {
    CheckUnsat =>
      self
      .core_from_tracked_assumptions(core_assumptions)
      .merge(assumption_result.unsat_core())
    _ => UnsatCore::empty()
  }
  self.last_unsat_assumptions = match result {
    CheckUnsat =>
      self
      .assumptions_from_core_owners(AssumptionSet::new(), core_assumptions)
      .with_backend_assumptions(core_assumptions)
    _ => UnsatAssumptionSet::empty()
  }
  self.statistics.record_solver_check()
  result
}

///|
pub fn Solver::get_scope_level(self : Solver) -> Int {
  self.assertions.scope_depth()
}

///|
pub fn Solver::get_num_assertions(self : Solver) -> Int {
  self.assertions.length()
}

///|
pub fn Solver::get_assertion(self : Solver, index : Int) -> @util.ExprId? {
  self.assertions.items().get(index)
}

///|
fn Solver::has_assertions(self : Solver) -> Bool {
  self.assertions.length() > 0
}

///|
fn Solver::set_pre_assertion_flag(
  self : Solver,
  name : String,
  value : Bool,
  getter : (SolverFactoryConfig) -> Bool,
  setter : (SolverFactoryConfig, Bool) -> SolverFactoryConfig,
) -> @util.Availability[Bool] {
  if self.has_assertions() {
    @util.Unavailable(unsupported_reason("late-option:\{name}"))
  } else {
    let changed = getter(self.config) != value
    self.config = setter(self.config, value)
    if changed {
      self.mark_result_stale()
    }
    @util.Available(value)
  }
}

///|
pub fn Solver::set_produce_models(
  self : Solver,
  value : Bool,
) -> @util.Availability[Bool] {
  self.config = self.config.with_produce_models(value)
  @util.Available(value)
}

///|
pub fn Solver::set_produce_proofs(
  self : Solver,
  value : Bool,
) -> @util.Availability[Bool] {
  self.set_pre_assertion_flag(
    "produce_proofs",
    value,
    fn(config) { config.produce_proofs() },
    fn(config, flag) { config.with_produce_proofs(flag) },
  )
}

///|
pub fn Solver::set_produce_unsat_cores(
  self : Solver,
  value : Bool,
) -> @util.Availability[Bool] {
  self.set_pre_assertion_flag(
    "produce_unsat_cores",
    value,
    fn(config) { config.produce_unsat_cores() },
    fn(config, flag) { config.with_produce_unsat_cores(flag) },
  )
}

///|
pub fn Solver::set_produce_unsat_assumptions(
  self : Solver,
  value : Bool,
) -> @util.Availability[Bool] {
  self.set_pre_assertion_flag(
    "produce_unsat_assumptions",
    value,
    fn(config) { config.produce_unsat_assumptions() },
    fn(config, flag) { config.with_produce_unsat_assumptions(flag) },
  )
}

///|
fn Solver::current_result_availability(
  self : Solver,
) -> @util.Availability[CheckSatResult] {
  match self.current_result {
    None => @util.Unavailable(@util.AvailabilityReason::NoCurrentResult)
    Some(result) =>
      if self.stale_result {
        @util.Unavailable(@util.AvailabilityReason::Stale)
      } else {
        @util.Available(result)
      }
  }
}

///|
fn wrong_result(
  expected : @util.ResultKind,
  actual : @util.ResultKind,
) -> @util.AvailabilityReason {
  @util.AvailabilityReason::wrong_result(expected, actual)
}

///|
fn invalid_model_reason() -> @util.AvailabilityReason {
  @util.AvailabilityReason::unknown(@util.ReasonUnknown::InvalidModel)
}

///|
pub fn Solver::model_available(self : Solver) -> @util.Availability[Unit] {
  if !self.config.produce_models() {
    @util.Unavailable(@util.AvailabilityReason::Disabled("produce-models"))
  } else {
    match self.current_result_availability() {
      @util.Unavailable(reason) => @util.Unavailable(reason)
      @util.Available(result) =>
        match result.result_kind() {
          @util.ResultKind::Sat | @util.ResultKind::Unknown(true) =>
            @util.Available(())
          actual =>
            @util.Unavailable(wrong_result(@util.ResultKind::Sat, actual))
        }
    }
  }
}

///|
pub fn Solver::get_model(self : Solver) -> @util.Availability[@model.Model] {
  match self.model_available() {
    @util.Available(_) =>
      match (self.backend.model_fn)() {
        @util.Available(model) => @util.Available(model)
        @util.Unavailable(@util.AvailabilityReason::NoCurrentResult) =>
          @util.Unavailable(invalid_model_reason())
        @util.Unavailable(reason) => @util.Unavailable(reason)
      }
    @util.Unavailable(reason) => @util.Unavailable(reason)
  }
}

///|
pub fn Solver::get_model_text(self : Solver) -> @util.Availability[String] {
  match self.get_model() {
    @util.Available(model) => @util.Available(model.format())
    @util.Unavailable(reason) => @util.Unavailable(reason)
  }
}

///|
pub fn Solver::eval(
  self : Solver,
  expr : @util.ExprId,
  completion~ : Bool,
) -> @util.Availability[@model.ModelValue] {
  match self.get_model() {
    @util.Available(model) =>
      match model.eval(self.manager, expr, completion~) {
        Some(value) => @util.Available(value)
        None =>
          @util.Unavailable(
            @util.AvailabilityReason::unknown(
              @util.ReasonUnknown::ModelEvalFailed,
            ),
          )
      }
    @util.Unavailable(reason) => @util.Unavailable(reason)
  }
}

///|
pub fn Solver::get_value(
  self : Solver,
  expr : @util.ExprId,
) -> @util.Availability[@model.ModelValue] {
  self.eval(expr, completion=true)
}

///|
pub fn Solver::reason_unknown(
  self : Solver,
) -> @util.Availability[@util.ReasonUnknown] {
  match self.current_result_availability() {
    @util.Unavailable(reason) => @util.Unavailable(reason)
    @util.Available(result) =>
      match result.reason_unknown() {
        Some(reason) => @util.Available(reason)
        None => @util.Unavailable(@util.AvailabilityReason::NoCurrentResult)
      }
  }
}

///|
fn Solver::unsat_query_available(
  self : Solver,
  enabled : Bool,
  disabled_name : String,
) -> @util.Availability[Unit] {
  if !enabled {
    @util.Unavailable(@util.AvailabilityReason::Disabled(disabled_name))
  } else {
    match self.current_result_availability() {
      @util.Unavailable(reason) => @util.Unavailable(reason)
      @util.Available(result) =>
        match result.result_kind() {
          @util.ResultKind::Unsat => @util.Available(())
          actual =>
            @util.Unavailable(wrong_result(@util.ResultKind::Unsat, actual))
        }
    }
  }
}

///|
pub fn Solver::get_proof(self : Solver) -> @util.Availability[@proof.ProofRef] {
  match
    self.unsat_query_available(self.config.produce_proofs(), "produce-proofs") {
    @util.Available(_) => (self.backend.proof_fn)()
    @util.Unavailable(reason) => @util.Unavailable(reason)
  }
}

///|
pub fn Solver::get_unsat_core(self : Solver) -> @util.Availability[UnsatCore] {
  match
    self.unsat_query_available(
      self.config.produce_unsat_cores(),
      "produce-unsat-cores",
    ) {
    @util.Available(_) => @util.Available(self.last_unsat_core)
    @util.Unavailable(reason) => @util.Unavailable(reason)
  }
}

///|
pub fn Solver::get_unsat_assumptions(
  self : Solver,
) -> @util.Availability[UnsatAssumptionSet] {
  match
    self.unsat_query_available(
      self.config.produce_unsat_assumptions(),
      "produce-unsat-assumptions",
    ) {
    @util.Available(_) => @util.Available(self.last_unsat_assumptions)
    @util.Unavailable(reason) => @util.Unavailable(reason)
  }
}

///|
pub fn Solver::assert_expr_tracked(
  self : Solver,
  expr : @util.ExprId,
  tracked : TrackedExpr,
) -> @util.Availability[TrackedAssertionId] {
  match self.validate_assertion_expr(expr) {
    @util.Unavailable(reason) => @util.Unavailable(reason)
    @util.Available(_) =>
      match self.validate_tracked_expr(tracked) {
        @util.Unavailable(reason) => @util.Unavailable(reason)
        @util.Available(_) =>
          if self.duplicate_tracked_assertion(tracked) {
            @util.Unavailable(
              unsupported_reason(
                "duplicate-tracked-assertion:\{tracked_name(tracked)}",
              ),
            )
          } else {
            match (self.backend.assert_expr_tracked_fn)(expr, tracked) {
              @util.Available(_) => {
                let id = TrackedAssertionId::new(self.next_tracked_assertion_id)
                self.next_tracked_assertion_id += 1
                let assertion_index = self.assertions.length()
                self.assertions.push_item(expr)
                self.tracked_assertions.push_item(TrackedAssertionRecord::{
                  assertion_index,
                  tracked,
                })
                self.mark_result_stale()
                @util.Available(id)
              }
              @util.Unavailable(reason) => @util.Unavailable(reason)
            }
          }
      }
  }
}

///|
pub fn Solver::check_sat_assuming(
  self : Solver,
  assumptions : AssumptionSet,
) -> CheckSatResult {
  let assumption_result = (self.backend.check_sat_assuming_fn)(
    self.combined_assumption_set(assumptions),
  )
  let result = assumption_result.result()
  self.current_result = Some(result)
  self.stale_result = false
  self.last_unsat_core = match result {
    CheckUnsat =>
      self
      .core_from_assumption_owners(
        assumptions,
        assumption_result.unsat_assumptions(),
      )
      .merge(assumption_result.unsat_core())
    _ => UnsatCore::empty()
  }
  self.last_unsat_assumptions = match result {
    CheckUnsat =>
      self
      .assumptions_from_core_owners(
        assumptions,
        assumption_result.unsat_assumptions(),
      )
      .with_backend_assumptions(assumption_result.unsat_assumptions())
    _ => UnsatAssumptionSet::empty()
  }
  self.statistics.record_solver_check()
  result
}

///|
priv struct SolverParamFlags {
  produce_models : Bool
  produce_proofs : Bool
  produce_unsat_cores : Bool
  produce_unsat_assumptions : Bool
}

///|
fn solver_param_flags(
  params : @params.Params,
) -> @util.Availability[SolverParamFlags] {
  let produce_models = match params.get_bool("produce_models") {
    @util.Available(value) => value
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  let produce_proofs = match params.get_bool("produce_proofs") {
    @util.Available(value) => value
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  let produce_unsat_cores = match params.get_bool("produce_unsat_cores") {
    @util.Available(value) => value
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  let produce_unsat_assumptions = match
    params.get_bool("produce_unsat_assumptions") {
    @util.Available(value) => value
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  @util.Available(SolverParamFlags::{
    produce_models,
    produce_proofs,
    produce_unsat_cores,
    produce_unsat_assumptions,
  })
}

///|
fn Solver::validate_pre_assertion_param_update(
  self : Solver,
  name : String,
  desired : Bool,
  current : Bool,
) -> @util.Availability[Unit] {
  if self.has_assertions() && desired != current {
    unavailable_unit(unsupported_reason("late-option:\{name}"))
  } else {
    @util.Available(())
  }
}

///|
fn Solver::validate_param_update(
  self : Solver,
  flags : SolverParamFlags,
) -> @util.Availability[Unit] {
  match
    self.validate_pre_assertion_param_update(
      "produce_proofs",
      flags.produce_proofs,
      self.config.produce_proofs(),
    ) {
    @util.Available(_) => ()
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  match
    self.validate_pre_assertion_param_update(
      "produce_unsat_cores",
      flags.produce_unsat_cores,
      self.config.produce_unsat_cores(),
    ) {
    @util.Available(_) => ()
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  self.validate_pre_assertion_param_update(
    "produce_unsat_assumptions",
    flags.produce_unsat_assumptions,
    self.config.produce_unsat_assumptions(),
  )
}

///|
fn Solver::pre_assertion_param_update_changes(
  self : Solver,
  flags : SolverParamFlags,
) -> Bool {
  flags.produce_proofs != self.config.produce_proofs() ||
  flags.produce_unsat_cores != self.config.produce_unsat_cores() ||
  flags.produce_unsat_assumptions != self.config.produce_unsat_assumptions()
}

///|
pub fn Solver::describe_params(_self : Solver) -> @params.ParamDescrs {
  SolverFactoryConfig::new().describe_params()
}

///|
pub fn Solver::updt_params(
  self : Solver,
  params : @params.Params,
) -> @util.Availability[Unit] {
  let flags = match solver_param_flags(params) {
    @util.Available(flags) => flags
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  match self.validate_param_update(flags) {
    @util.Available(_) => ()
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  let stale = self.pre_assertion_param_update_changes(flags)
  self.config = self.config.with_produce_models(flags.produce_models)
  self.config = self.config.with_produce_proofs(flags.produce_proofs)
  self.config = self.config.with_produce_unsat_cores(flags.produce_unsat_cores)
  self.config = self.config.with_produce_unsat_assumptions(
    flags.produce_unsat_assumptions,
  )
  if stale {
    self.mark_result_stale()
  }
  @util.Available(())
}

///|
pub fn Solver::translate(
  self : Solver,
  target : @ast.AstManager,
) -> @util.Availability[Solver] {
  let translated_backend = match
    (self.backend.translate_fn)(target, self.config) {
    @util.Available(backend) => backend
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  let translator = @ast.AstTranslator::new(self.manager, target)
  let translated = Solver::new(target, self.config, translated_backend)
  let assertion_items = self.assertions.items()
  let assertion_scopes = self.assertions.scopes.copy()
  let tracked_records = self.tracked_assertions.items()
  let mut scope_index = 0
  for assertion_index in 0..<assertion_items.length() {
    while scope_index < assertion_scopes.length() &&
          assertion_scopes[scope_index] == assertion_index {
      match translated.push(1) {
        @util.Available(_) => scope_index += 1
        @util.Unavailable(reason) => return @util.Unavailable(reason)
      }
    }
    let translated_expr = translator.translate_expr(
      assertion_items[assertion_index],
    ) catch {
      err =>
        return @util.Unavailable(
          unsupported_reason("translate:\{err.to_string()}"),
        )
    }
    match tracked_record_for_assertion_index(tracked_records, assertion_index) {
      Some(record) => {
        let translated_tracker = translator.translate_expr(
          record.tracked.tracker(),
        ) catch {
          err =>
            return @util.Unavailable(
              unsupported_reason("translate:\{err.to_string()}"),
            )
        }
        let display = record.tracked.display_name()
        let translated_tracked = TrackedExpr::new(
          translated_tracker,
          if display == "" {
            None
          } else {
            Some(display)
          },
        )
        match
          translated.assert_expr_tracked(translated_expr, translated_tracked) {
          @util.Available(_) => ()
          @util.Unavailable(reason) => return @util.Unavailable(reason)
        }
      }
      None =>
        match translated.assert_expr(translated_expr) {
          @util.Available(_) => ()
          @util.Unavailable(reason) => return @util.Unavailable(reason)
        }
    }
  }
  while scope_index < assertion_scopes.length() {
    if assertion_scopes[scope_index] != assertion_items.length() {
      return @util.Unavailable(unsupported_reason("translate:invalid-scope"))
    }
    match translated.push(1) {
      @util.Available(_) => scope_index += 1
      @util.Unavailable(reason) => return @util.Unavailable(reason)
    }
  }
  @util.Available(translated)
}

///|
pub fn Solver::collect_statistics(self : Solver) -> StatisticsSnapshot {
  let snapshot = @stats.Statistics::new()
  snapshot.merge(self.statistics)
  snapshot.merge((self.backend.collect_statistics_fn)())
  let reasons = snapshot.incomplete_reasons(solver_statistics_manifest())
  match self.current_result_availability() {
    @util.Available(result) =>
      match result.reason_unknown() {
        Some(reason) => reasons.push(reason)
        None => ()
      }
    @util.Unavailable(_) => ()
  }
  StatisticsSnapshot::new(snapshot, reasons)
}
