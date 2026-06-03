///|
pub struct ClauseId {
  priv value : Int
} derive(Eq, Compare, Hash)

///|
pub fn ClauseId::new(value : Int) -> ClauseId {
  { value, }
}

///|
pub fn ClauseId::to_int(self : ClauseId) -> Int {
  self.value
}

///|
pub impl Show for ClauseId with fn output(self, logger) {
  logger.write_string("clause#\{self.value}")
}

///|
pub(all) enum ClauseStatus {
  Input
  Asserted
  Redundant
  Deleted
  Theory(String, Bool, String?)
} derive(Eq)

///|
pub struct ClauseTheoryProofHint {
  priv owner : String
  priv kind : String
} derive(Eq)

///|
pub fn ClauseTheoryProofHint::owner_text(
  self : ClauseTheoryProofHint,
) -> String {
  self.owner
}

///|
pub fn ClauseTheoryProofHint::kind_text(self : ClauseTheoryProofHint) -> String {
  self.kind
}

///|
fn theory_status_text(
  owner : String,
  redundant : Bool,
  hint : String?,
) -> String {
  let kind = if redundant { "redundant" } else { "asserted" }
  match hint {
    Some(hint) => "theory \{owner} \{kind} hint \{hint}"
    None => "theory \{owner} \{kind}"
  }
}

///|
fn ClauseStatus::event_text(self : ClauseStatus) -> String {
  match self {
    Input => "asserted input"
    Asserted => "asserted"
    Redundant => "redundant learned"
    Deleted => "deleted"
    Theory(owner, redundant, hint) => theory_status_text(owner, redundant, hint)
  }
}

///|
fn ClauseStatus::is_learned(self : ClauseStatus) -> Bool {
  match self {
    Redundant | Theory(_, true, _) => true
    Input | Asserted | Deleted | Theory(_, false, _) => false
  }
}

///|
fn literal_array_contains(values : Array[Literal], value : Literal) -> Bool {
  for existing in values {
    if existing == value {
      return true
    }
  }
  false
}

///|
fn clause_has_exact_literals(
  clause : Clause,
  expected : Array[Literal],
) -> Bool {
  let literals = clause.literals()
  if literals.length() != expected.length() {
    return false
  }
  for literal in literals {
    if !literal_array_contains(expected, literal) {
      return false
    }
  }
  true
}

///|
priv struct ClauseRecord {
  clause : Clause
  status : ClauseStatus
  mut deleted : Bool
}

///|
pub(all) struct ClauseEvent {
  action : String
  clause_id : ClauseId
  status : ClauseStatus
} derive(Eq)

///|
fn ClauseEvent::to_text(self : ClauseEvent) -> String {
  "\{self.action} \{self.clause_id} \{self.status.event_text()}"
}

///|
fn ClauseEvent::theory_proof_hint(self : ClauseEvent) -> ClauseTheoryProofHint? {
  match self {
    { action: "add", status: Theory(owner, _, Some(kind)), .. } =>
      Some(ClauseTheoryProofHint::{ owner, kind })
    _ => None
  }
}

///|
fn ClauseEvent::is_unhinted_theory_clause(self : ClauseEvent) -> Bool {
  match self {
    { action: "add", status: Theory(_, _, None), .. } => true
    _ => false
  }
}

///|
pub struct ClauseDb {
  priv records : Array[ClauseRecord]
  priv events : Array[ClauseEvent]
}

///|
pub fn ClauseDb::new() -> ClauseDb {
  { records: [], events: [] }
}

///|
fn ClauseDb::add_clause_with_status(
  self : ClauseDb,
  clause : Clause,
  status : ClauseStatus,
) -> ClauseId {
  let clause_id = ClauseId::new(self.records.length())
  self.records.push(ClauseRecord::{ clause, status, deleted: false })
  self.events.push(ClauseEvent::{ action: "add", clause_id, status })
  clause_id
}

///|
pub fn ClauseDb::add_root_clause(self : ClauseDb, clause : Clause) -> ClauseId {
  self.add_clause_with_status(clause, Input)
}

///|
pub fn ClauseDb::add_learned_clause(
  self : ClauseDb,
  clause : Clause,
) -> ClauseId {
  self.add_clause_with_status(clause, Redundant)
}

///|
pub fn ClauseDb::delete_clause(self : ClauseDb, clause_id : ClauseId) -> Unit {
  let index = clause_id.to_int()
  if index >= 0 && index < self.records.length() && !self.records[index].deleted {
    self.records[index].deleted = true
    self.events.push(ClauseEvent::{
      action: "delete",
      clause_id,
      status: Deleted,
    })
  }
}

///|
pub fn ClauseDb::delete_clauses_touching_vars(
  self : ClauseDb,
  vars : Array[BoolVar],
) -> Unit {
  for i in 0..<self.records.length() {
    if !self.records[i].deleted {
      for bool_var in vars {
        if self.records[i].clause.contains_bool_var(bool_var) {
          self.delete_clause(ClauseId::new(i))
          break
        }
      }
    }
  }
}

///|
pub fn ClauseDb::delete_clauses_with_vars_above(
  self : ClauseDb,
  max_var : BoolVar,
) -> Unit {
  for i in 0..<self.records.length() {
    if !self.records[i].deleted && self.records[i].clause.has_var_above(max_var) {
      self.delete_clause(ClauseId::new(i))
    }
  }
}

///|
pub fn ClauseDb::active_clauses(self : ClauseDb) -> Array[Clause] {
  let clauses : Array[Clause] = []
  for record in self.records {
    if !record.deleted && !record.clause.is_tautology() {
      clauses.push(record.clause)
    }
  }
  clauses
}

///|
pub fn ClauseDb::clause_literals(
  self : ClauseDb,
  clause_id : ClauseId,
) -> Array[Literal] {
  self.records[clause_id.to_int()].clause.literals()
}

///|
pub fn ClauseDb::root_clause_count(self : ClauseDb) -> Int {
  let mut count = 0
  for record in self.records {
    if !record.deleted && record.status == Input {
      count += 1
    }
  }
  count
}

///|
pub fn ClauseDb::learned_clause_count(self : ClauseDb) -> Int {
  let mut count = 0
  for record in self.records {
    if !record.deleted && record.status.is_learned() {
      count += 1
    }
  }
  count
}

///|
pub fn ClauseDb::clause_count(self : ClauseDb) -> Int {
  let mut count = 0
  for record in self.records {
    if !record.deleted {
      count += 1
    }
  }
  count
}

///|
pub fn ClauseDb::deleted_clause_count(self : ClauseDb) -> Int {
  let mut count = 0
  for record in self.records {
    if record.deleted {
      count += 1
    }
  }
  count
}

///|
pub fn ClauseDb::event_log_text(self : ClauseDb) -> String {
  [ for event in self.events => event.to_text() ].join(";")
}

///|
fn ClauseDb::theory_proof_hints(
  self : ClauseDb,
) -> Array[ClauseTheoryProofHint] {
  let hints : Array[ClauseTheoryProofHint] = []
  for event in self.events {
    match event.theory_proof_hint() {
      Some(hint) => hints.push(hint)
      None => ()
    }
  }
  hints
}

///|
fn ClauseDb::unhinted_theory_clause_count(self : ClauseDb) -> Int {
  let mut count = 0
  for event in self.events {
    if event.is_unhinted_theory_clause() {
      count += 1
    }
  }
  count
}

///|
fn ClauseDb::has_unsat_proof_clause(
  self : ClauseDb,
  final_literals : Array[Literal],
) -> Bool {
  for record in self.records {
    if !record.deleted &&
      record.status.is_learned() &&
      clause_has_exact_literals(record.clause, final_literals) {
      return true
    }
  }
  false
}
