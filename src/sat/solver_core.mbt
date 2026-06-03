///|
pub struct SatCoreModel {
  priv assignments : Array[Bool?]
} derive(Eq)

///|
pub fn SatCoreModel::value(self : SatCoreModel, bool_var : BoolVar) -> Bool? {
  match self.assignments.get(bool_var.to_int()) {
    Some(value) => value
    None => None
  }
}

///|
pub(all) enum SatCoreResult {
  SatCoreSat(SatCoreModel)
  SatCoreUnsat
  SatCoreUnknown(String)
} derive(Eq)

///|
priv struct SatConflictRecord {
  clause : Clause
  status : ClauseStatus
}

///|
pub struct SatSolverCore {
  priv mut next_var : Int
  priv clause_db : ClauseDb
  priv mut assignment : Array[Bool?]
  priv trail : Array[Literal]
  priv decision_var : Array[Bool]
  priv scope_guards : Array[BoolVar]
  priv mut extension : SatExtension?
  priv ext_watches : Array[ExternalWatch]
  priv phase : Array[Bool]
  priv activity : Array[Int]
  priv mut decisions : Int
  priv mut propagations : Int
  priv mut last_conflict : SatConflictRecord?
  priv mut pending_unknown : String?
}

///|
pub fn SatSolverCore::new() -> SatSolverCore {
  {
    next_var: 0,
    clause_db: ClauseDb::new(),
    assignment: [None],
    trail: [],
    decision_var: [false],
    scope_guards: [],
    extension: None,
    ext_watches: [],
    phase: [false],
    activity: [0],
    decisions: 0,
    propagations: 0,
    last_conflict: None,
    pending_unknown: None,
  }
}

///|
pub fn SatSolverCore::add_var(self : SatSolverCore) -> BoolVar {
  self.next_var += 1
  self.assignment.push(None)
  self.decision_var.push(true)
  self.phase.push(false)
  self.activity.push(0)
  BoolVar::new(self.next_var)
}

///|
fn SatSolverCore::add_guard_var(self : SatSolverCore) -> BoolVar {
  self.next_var += 1
  self.assignment.push(None)
  self.decision_var.push(false)
  self.phase.push(false)
  self.activity.push(0)
  BoolVar::new(self.next_var)
}

///|
pub fn SatSolverCore::add_clause(
  self : SatSolverCore,
  clause : Clause,
) -> ClauseId {
  self.clause_db.add_root_clause(
    clause.with_extra_literals(self.scope_guard_literals()),
  )
}

///|
pub fn SatSolverCore::add_theory_clause(
  self : SatSolverCore,
  clause : Clause,
  owner~ : String,
  redundant~ : Bool,
  hint~ : String?,
) -> ClauseId {
  self.clause_db.add_clause_with_status(
    clause.with_extra_literals(self.scope_guard_literals()),
    Theory(owner, redundant, hint),
  )
}

///|
pub fn SatSolverCore::reset_search_state(self : SatSolverCore) -> Unit {
  self.assignment = Array::make(self.next_var + 1, None)
  self.trail.truncate(0)
  self.decisions = 0
  self.propagations = 0
  self.last_conflict = None
  self.pending_unknown = None
}

///|
pub fn SatSolverCore::set_extension(
  self : SatSolverCore,
  extension : SatExtension,
) -> Unit {
  (extension.init_use_list)()
  self.extension = Some(extension)
}

///|
pub fn SatSolverCore::watch_external(
  self : SatSolverCore,
  literal : Literal,
  constraint : ExtConstraintId,
) -> Unit {
  match self.extension {
    Some(extension) => if (extension.is_blocked)(constraint) { return }
    None => ()
  }
  self.ext_watches.push(ExternalWatch::{ literal, constraint })
}

///|
pub fn SatSolverCore::external_watch_count(self : SatSolverCore) -> Int {
  self.ext_watches.length()
}

///|
fn SatSolverCore::notify_external_watches(
  self : SatSolverCore,
  literal : Literal,
) -> Unit {
  match self.extension {
    None => ()
    Some(extension) => {
      let remaining : Array[ExternalWatch] = []
      for watch in self.ext_watches {
        if watch.literal == literal {
          match (extension.propagated)(literal, watch.constraint) {
            KeepWatch => remaining.push(watch)
            DropWatch => ()
          }
        } else {
          remaining.push(watch)
        }
      }
      self.ext_watches.truncate(0)
      for watch in remaining {
        self.ext_watches.push(watch)
      }
    }
  }
}

///|
fn SatSolverCore::notify_asserted(
  self : SatSolverCore,
  literal : Literal,
) -> Unit {
  match self.extension {
    Some(extension) => (extension.asserted)(literal)
    None => ()
  }
}

///|
fn SatSolverCore::is_external_var(
  self : SatSolverCore,
  bool_var : BoolVar,
) -> Bool {
  match self.extension {
    Some(extension) => (extension.is_external)(bool_var)
    None => false
  }
}

///|
fn SatSolverCore::scope_guard_literals(self : SatSolverCore) -> Array[Literal] {
  [
    for guard_var in self.scope_guards => Literal::pos(guard_var)
  ]
}

///|
fn SatSolverCore::activate_scope_guards(self : SatSolverCore) -> Bool {
  for guard_var in self.scope_guards {
    if !self.assign_literal(Literal::neg(guard_var)) {
      return false
    }
  }
  true
}

///|
fn SatSolverCore::activate_assumptions(
  self : SatSolverCore,
  assumptions : Array[Literal],
) -> Bool {
  for assumption in assumptions {
    if !self.assign_literal(assumption) {
      return false
    }
  }
  true
}

///|
fn SatSolverCore::materialize_antecedents(
  self : SatSolverCore,
  justification : ExtJustificationId,
) -> Clause {
  match self.extension {
    None => Clause::empty()
    Some(extension) => Clause::new((extension.get_antecedents)(justification))
  }
}

///|
fn SatSolverCore::materialize_theory_conflict(
  self : SatSolverCore,
  justification : ExtJustificationId,
) -> SatConflictRecord {
  match self.extension {
    None => SatConflictRecord::{ clause: Clause::empty(), status: Redundant }
    Some(extension) =>
      SatConflictRecord::{
        clause: self.materialize_antecedents(justification),
        status: (extension.describe_justification)(justification),
      }
  }
}

///|
fn SatSolverCore::record_boolean_conflict(
  self : SatSolverCore,
  clause : Clause,
) -> Unit {
  self.last_conflict = Some(SatConflictRecord::{ clause, status: Redundant })
}

///|
fn SatSolverCore::handle_extension_action(
  self : SatSolverCore,
  action : ExtensionAction,
) -> Bool {
  match action {
    ExtensionNoAction => true
    ExtensionAssign(literal, justification) =>
      if self.assign_literal(literal) {
        true
      } else {
        self.last_conflict = Some(
          self.materialize_theory_conflict(justification),
        )
        false
      }
    ExtensionConflict(justification) => {
      self.last_conflict = Some(self.materialize_theory_conflict(justification))
      false
    }
    ExtensionUnknown(reason) => {
      self.pending_unknown = Some(reason.to_text())
      false
    }
  }
}

///|
fn SatSolverCore::propagate_extension(self : SatSolverCore) -> Bool {
  match self.extension {
    None => true
    Some(extension) => {
      while (extension.can_propagate)() {
        let action = (extension.unit_propagate)()
        match action {
          ExtensionNoAction => return true
          _ => if !self.handle_extension_action(action) { return false }
        }
      }
      true
    }
  }
}

///|
fn SatSolverCore::assignment_view(self : SatSolverCore) -> SatAssignmentView {
  SatAssignmentView::{ assignments: self.assignment.copy() }
}

///|
fn sat_validation_reason_from_availability_reason(
  reason : @util.AvailabilityReason,
) -> @util.ReasonUnknown {
  match reason {
    @util.UnknownReason(reason) => reason
    @util.Unsupported(reason) => reason
    @util.Disabled(_)
    | @util.NoCurrentResult
    | @util.WrongResult(_, _)
    | @util.Stale => @util.ReasonUnknown::ModelValidationFailed
  }
}

///|
fn SatSolverCore::handle_extension_validation(
  self : SatSolverCore,
  result : @util.Availability[Unit],
) -> Bool {
  match result {
    @util.Available(_) => true
    @util.Unavailable(reason) => {
      self.pending_unknown = Some(
        sat_validation_reason_from_availability_reason(reason).to_text(),
      )
      false
    }
  }
}

///|
fn SatSolverCore::final_check_extension(self : SatSolverCore) -> Bool {
  match self.extension {
    None => true
    Some(extension) => {
      let view = self.assignment_view()
      if self.handle_extension_action((extension.check)(view)) {
        self.handle_extension_validation((extension.validate)(view))
      } else {
        false
      }
    }
  }
}

///|
fn SatSolverCore::literal_value(
  self : SatSolverCore,
  literal : Literal,
) -> Bool? {
  literal.value(self.assignment)
}

///|
fn SatSolverCore::assign_literal(
  self : SatSolverCore,
  literal : Literal,
) -> Bool {
  let index = literal.bool_var().to_int()
  if index <= 0 || index > self.next_var {
    false
  } else {
    match self.assignment[index] {
      Some(value) => value == literal.is_positive()
      None => {
        self.assignment[index] = Some(literal.is_positive())
        self.phase[index] = literal.is_positive()
        self.trail.push(literal)
        self.notify_asserted(literal)
        self.notify_external_watches(literal)
        true
      }
    }
  }
}

///|
fn SatSolverCore::bump_clause_vars(
  self : SatSolverCore,
  clause : Clause,
) -> Unit {
  for literal in clause.literals() {
    let index = literal.bool_var().to_int()
    if index > 0 && index <= self.next_var && self.decision_var[index] {
      self.activity[index] += 1
    }
  }
}

///|
fn SatSolverCore::propagate_units(self : SatSolverCore) -> Bool {
  let mut changed = true
  while changed {
    changed = false
    for clause in self.clause_db.active_clauses() {
      let mut satisfied = false
      let unassigned : Array[Literal] = []
      for literal in clause.literals() {
        match self.literal_value(literal) {
          Some(true) => satisfied = true
          Some(false) => ()
          None => unassigned.push(literal)
        }
      }
      if !satisfied {
        match unassigned.length() {
          0 => {
            self.record_boolean_conflict(clause)
            self.bump_clause_vars(clause)
            return false
          }
          1 => {
            if !self.assign_literal(unassigned[0]) {
              self.record_boolean_conflict(clause)
              self.bump_clause_vars(clause)
              return false
            }
            self.propagations += 1
            changed = true
          }
          _ => ()
        }
      }
    }
    if !self.propagate_extension() {
      return false
    }
  }
  true
}

///|
fn SatSolverCore::all_assigned(self : SatSolverCore) -> Bool {
  for i in 1..<=self.next_var {
    let bool_var = BoolVar::new(i)
    if self.decision_var[i] &&
      !self.is_external_var(bool_var) &&
      self.assignment[i] is None {
      return false
    }
  }
  true
}

///|
fn SatSolverCore::choose_var(self : SatSolverCore) -> BoolVar? {
  let mut best = 0
  let mut best_activity = 0
  for i in 1..<=self.next_var {
    let bool_var = BoolVar::new(i)
    if self.decision_var[i] &&
      !self.is_external_var(bool_var) &&
      self.assignment[i] is None {
      if best == 0 || self.activity[i] > best_activity {
        best = i
        best_activity = self.activity[i]
      }
    }
  }
  if best == 0 {
    None
  } else {
    Some(BoolVar::new(best))
  }
}

///|
fn SatSolverCore::backtrack_to(self : SatSolverCore, trail_size : Int) -> Unit {
  for i in trail_size..<self.trail.length() {
    let index = self.trail[i].bool_var().to_int()
    if index > 0 && index <= self.next_var {
      self.assignment[index] = None
    }
  }
  self.trail.truncate(trail_size)
}

///|
fn SatSolverCore::search(self : SatSolverCore) -> Bool {
  if !self.propagate_units() {
    return false
  }
  if self.all_assigned() {
    if self.final_check_extension() {
      return true
    } else {
      return false
    }
  }
  match self.choose_var() {
    None => true
    Some(bool_var) => {
      let preferred = Literal::new(bool_var, self.phase[bool_var.to_int()])
      for literal in [preferred, preferred.negate()] {
        let mark = self.trail.length()
        self.decisions += 1
        if self.assign_literal(literal) && self.search() {
          return true
        }
        self.backtrack_to(mark)
      }
      false
    }
  }
}

///|
fn SatSolverCore::unsat_proof_clause(self : SatSolverCore) -> Clause {
  Clause::empty().with_extra_literals(self.scope_guard_literals())
}

///|
fn SatSolverCore::record_unsat_learned_clause(
  self : SatSolverCore,
  assumptions : Array[Literal],
) -> Unit {
  match self.last_conflict {
    Some(conflict) =>
      ignore(
        self.clause_db.add_clause_with_status(
          if assumptions.is_empty() {
            self.unsat_proof_clause()
          } else {
            conflict.clause
          },
          conflict.status,
        ),
      )
    None => ()
  }
}

///|
fn SatSolverCore::check_core(
  self : SatSolverCore,
  assumptions : Array[Literal],
) -> SatCoreResult {
  self.reset_search_state()
  match self.extension {
    Some(extension) =>
      if !self.handle_extension_action((extension.init_search)()) {
        match self.pending_unknown {
          Some(reason) => return SatCoreUnknown(reason)
          None => return SatCoreUnsat
        }
      }
    None => ()
  }
  if !self.activate_scope_guards() || !self.activate_assumptions(assumptions) {
    SatCoreUnsat
  } else if self.search() {
    SatCoreSat(SatCoreModel::{ assignments: self.assignment.copy() })
  } else if self.pending_unknown is Some(reason) {
    SatCoreUnknown(reason)
  } else {
    self.record_unsat_learned_clause(assumptions)
    self.backtrack_to(0)
    SatCoreUnsat
  }
}

///|
pub fn SatSolverCore::check(self : SatSolverCore) -> SatCoreResult {
  self.check_core([])
}

///|
fn assumptions_without(
  assumptions : Array[Literal],
  skip : Int,
) -> Array[Literal] {
  let result : Array[Literal] = []
  for i in 0..<assumptions.length() {
    if i != skip {
      result.push(assumptions[i])
    }
  }
  result
}

///|
fn push_literal_unique(values : Array[Literal], literal : Literal) -> Unit {
  for existing in values {
    if existing == literal {
      return
    }
  }
  values.push(literal)
}

///|
fn SatSolverCore::extension_tracking_assumptions(
  self : SatSolverCore,
) -> Array[Literal] {
  match self.extension {
    Some(extension) => (extension.tracking_assumptions)()
    None => []
  }
}

///|
fn SatSolverCore::with_extension_tracking_assumptions(
  self : SatSolverCore,
  assumptions : Array[Literal],
) -> Array[Literal] {
  let result : Array[Literal] = []
  for assumption in assumptions {
    push_literal_unique(result, assumption)
  }
  for assumption in self.extension_tracking_assumptions() {
    push_literal_unique(result, assumption)
  }
  result
}

///|
fn SatSolverCore::notify_extension_assumptions(
  self : SatSolverCore,
  assumptions : Array[Literal],
) -> Unit {
  match self.extension {
    Some(extension) => (extension.add_assumptions)(assumptions)
    None => ()
  }
}

///|
fn SatSolverCore::extension_should_research(
  self : SatSolverCore,
  core : AssumptionCore,
) -> Bool {
  match self.extension {
    Some(extension) => (extension.should_research)(core)
    None => false
  }
}

///|
fn SatSolverCore::minimize_assumption_core(
  self : SatSolverCore,
  assumptions : Array[Literal],
) -> AssumptionCore {
  let mut core = assumptions.copy()
  let mut index = 0
  while index < core.length() {
    let candidate = assumptions_without(core, index)
    match self.check_core(candidate) {
      SatCoreUnsat => core = candidate
      SatCoreSat(_) | SatCoreUnknown(_) => index += 1
    }
  }
  AssumptionCore::{ literals: core }
}

///|
fn SatSolverCore::assumption_core_for(
  self : SatSolverCore,
  base_assumptions : Array[Literal],
  assumptions : Array[Literal],
) -> AssumptionCheckResult {
  self.notify_extension_assumptions(assumptions)
  match self.check_core(assumptions) {
    SatCoreSat(model) => AssumptionSat(model)
    SatCoreUnknown(reason) => AssumptionUnknown(reason)
    SatCoreUnsat => {
      let mut core = self.minimize_assumption_core(assumptions)
      while self.extension_should_research(core) {
        let refreshed = self.with_extension_tracking_assumptions(
          base_assumptions,
        )
        self.notify_extension_assumptions(refreshed)
        match self.check_core(refreshed) {
          SatCoreSat(model) => return AssumptionSat(model)
          SatCoreUnknown(reason) => return AssumptionUnknown(reason)
          SatCoreUnsat => core = self.minimize_assumption_core(refreshed)
        }
      }
      AssumptionUnsat(core)
    }
  }
}

///|
pub fn SatSolverCore::check_with_assumptions(
  self : SatSolverCore,
  assumptions : Array[Literal],
) -> AssumptionCheckResult {
  self.assumption_core_for(
    assumptions,
    self.with_extension_tracking_assumptions(assumptions),
  )
}

///|
pub fn SatSolverCore::user_push(self : SatSolverCore) -> Unit {
  self.scope_guards.push(self.add_guard_var())
}

///|
pub fn SatSolverCore::user_pop(self : SatSolverCore, count : Int) -> Unit {
  if count <= 0 {
    return
  }
  let depth = self.scope_guards.length()
  let pop_count = if count > depth { depth } else { count }
  let target = depth - pop_count
  let popped : Array[BoolVar] = []
  for i in target..<depth {
    popped.push(self.scope_guards[i])
  }
  self.scope_guards.truncate(target)
  self.reset_search_state()
  self.clause_db.delete_clauses_touching_vars(popped)
}

///|
pub fn SatSolverCore::user_scope_depth(self : SatSolverCore) -> Int {
  self.scope_guards.length()
}

///|
pub fn SatSolverCore::gc_vars(
  self : SatSolverCore,
  max_guard_var : BoolVar,
) -> Unit {
  self.clause_db.delete_clauses_with_vars_above(max_guard_var)
  match self.extension {
    Some(extension) => (extension.gc_vars)(max_guard_var)
    None => ()
  }
}

///|
pub fn SatSolverCore::gc(self : SatSolverCore) -> Unit {
  match self.extension {
    Some(extension) => (extension.gc)()
    None => ()
  }
}

///|
fn int_array_text(values : Array[Int]) -> String {
  [ for i in 1..<values.length() => "b\{i}=\{values[i]}" ].join(",")
}

///|
fn bool_array_text(values : Array[Bool]) -> String {
  [ for i in 1..<values.length() => "b\{i}=\{values[i]}" ].join(",")
}

///|
pub fn SatSolverCore::clause_event_log_text(self : SatSolverCore) -> String {
  self.clause_db.event_log_text()
}

///|
pub fn SatSolverCore::clause_theory_proof_hints(
  self : SatSolverCore,
) -> Array[ClauseTheoryProofHint] {
  self.clause_db.theory_proof_hints()
}

///|
pub fn SatSolverCore::unhinted_theory_clause_count(self : SatSolverCore) -> Int {
  self.clause_db.unhinted_theory_clause_count()
}

///|
pub fn SatSolverCore::has_unsat_proof_clause(self : SatSolverCore) -> Bool {
  self.clause_db.has_unsat_proof_clause(self.unsat_proof_clause().literals())
}

///|
pub fn SatSolverCore::inspect_state(self : SatSolverCore) -> SatCoreSnapshot {
  {
    vars: self.next_var,
    root_clauses: self.clause_db.root_clause_count(),
    learned_clauses: self.clause_db.learned_clause_count(),
    deleted_clauses: self.clause_db.deleted_clause_count(),
    decisions: self.decisions,
    propagations: self.propagations,
    activity_text: int_array_text(self.activity),
    phase_text: bool_array_text(self.phase),
  }
}

///|
pub fn SatSolverCore::collect_statistics(
  self : SatSolverCore,
) -> @stats.Statistics {
  let statistics = self.inspect_state().to_statistics()
  match self.extension {
    Some(extension) => statistics.merge((extension.collect_statistics)())
    None => ()
  }
  statistics
}
