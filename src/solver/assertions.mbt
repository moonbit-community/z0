///|
pub struct TrackedAssertionId {
  priv value : Int
} derive(Eq, Compare, Hash)

///|
pub fn TrackedAssertionId::new(value : Int) -> TrackedAssertionId {
  { value, }
}

///|
pub fn TrackedAssertionId::to_int(self : TrackedAssertionId) -> Int {
  self.value
}

///|
pub struct TrackedExpr {
  priv tracker : @util.ExprId
  priv display_name : String?
}

///|
pub fn TrackedExpr::new(
  tracker : @util.ExprId,
  display_name : String?,
) -> TrackedExpr {
  { tracker, display_name }
}

///|
pub fn TrackedExpr::tracker(self : TrackedExpr) -> @util.ExprId {
  self.tracker
}

///|
pub fn TrackedExpr::display_name(self : TrackedExpr) -> String {
  match self.display_name {
    Some(name) => name
    None => ""
  }
}

///|
pub struct AssumptionSet {
  priv assumptions : Array[@util.ExprId]
}

///|
pub fn AssumptionSet::new() -> AssumptionSet {
  { assumptions: [] }
}

///|
pub fn AssumptionSet::add(self : AssumptionSet, expr : @util.ExprId) -> Unit {
  for existing in self.assumptions {
    if existing == expr {
      return
    }
  }
  self.assumptions.push(expr)
}

///|
pub fn AssumptionSet::length(self : AssumptionSet) -> Int {
  self.assumptions.length()
}

///|
pub fn AssumptionSet::items(self : AssumptionSet) -> Array[@util.ExprId] {
  self.assumptions.copy()
}

///|
pub struct UnsatAssumptionSet {
  priv assumptions : Array[@util.ExprId]
}

///|
pub fn UnsatAssumptionSet::empty() -> UnsatAssumptionSet {
  { assumptions: [] }
}

///|
pub fn UnsatAssumptionSet::from_exprs(
  assumptions : Array[@util.ExprId],
) -> UnsatAssumptionSet {
  let result = UnsatAssumptionSet::empty()
  for assumption in assumptions {
    result.add(assumption)
  }
  result
}

///|
pub fn UnsatAssumptionSet::length(self : UnsatAssumptionSet) -> Int {
  self.assumptions.length()
}

///|
pub fn UnsatAssumptionSet::items(
  self : UnsatAssumptionSet,
) -> Array[@util.ExprId] {
  self.assumptions.copy()
}

///|
fn UnsatAssumptionSet::contains(
  self : UnsatAssumptionSet,
  assumption : @util.ExprId,
) -> Bool {
  for existing in self.assumptions {
    if existing == assumption {
      return true
    }
  }
  false
}

///|
fn UnsatAssumptionSet::add(
  self : UnsatAssumptionSet,
  assumption : @util.ExprId,
) -> Unit {
  if !self.contains(assumption) {
    self.assumptions.push(assumption)
  }
}

///|
fn UnsatAssumptionSet::with_backend_assumptions(
  self : UnsatAssumptionSet,
  backend : UnsatAssumptionSet,
) -> UnsatAssumptionSet {
  let result = UnsatAssumptionSet::from_exprs(self.assumptions)
  for assumption in backend.assumptions {
    result.add(assumption)
  }
  result
}

///|
pub fn UnsatAssumptionSet::to_text(self : UnsatAssumptionSet) -> String {
  [ for assumption in self.assumptions => "\{assumption}" ].join(",")
}

///|
pub struct UnsatCoreEntry {
  priv expr : @util.ExprId
  priv name : String?
}

///|
pub fn UnsatCoreEntry::new(
  expr : @util.ExprId,
  name : String?,
) -> UnsatCoreEntry {
  { expr, name }
}

///|
pub fn UnsatCoreEntry::to_text(self : UnsatCoreEntry) -> String {
  match self.name {
    Some(name) => name
    None => "\{self.expr}"
  }
}

///|
fn UnsatCoreEntry::same_owner(
  self : UnsatCoreEntry,
  other : UnsatCoreEntry,
) -> Bool {
  self.expr == other.expr && self.name == other.name
}

///|
pub struct UnsatCore {
  priv entries : Array[UnsatCoreEntry]
}

///|
pub fn UnsatCore::empty() -> UnsatCore {
  { entries: [] }
}

///|
fn UnsatCore::from_entries(entries : Array[UnsatCoreEntry]) -> UnsatCore {
  let normalized : Array[UnsatCoreEntry] = []
  for entry in entries {
    if !unsat_core_entries_contain(normalized, entry) {
      normalized.push(entry)
    }
  }
  { entries: normalized }
}

///|
pub fn UnsatCore::single(entry : UnsatCoreEntry) -> UnsatCore {
  UnsatCore::from_entries([entry])
}

///|
fn unsat_core_entries_contain(
  entries : Array[UnsatCoreEntry],
  entry : UnsatCoreEntry,
) -> Bool {
  for existing in entries {
    if existing.same_owner(entry) {
      return true
    }
  }
  false
}

///|
pub fn UnsatCore::with_entry(
  self : UnsatCore,
  entry : UnsatCoreEntry,
) -> UnsatCore {
  let entries = self.entries.copy()
  entries.push(entry)
  UnsatCore::from_entries(entries)
}

///|
fn UnsatCore::merge(self : UnsatCore, other : UnsatCore) -> UnsatCore {
  let entries = self.entries.copy()
  for entry in other.entries {
    entries.push(entry)
  }
  UnsatCore::from_entries(entries)
}

///|
pub fn UnsatCore::length(self : UnsatCore) -> Int {
  self.entries.length()
}

///|
pub fn UnsatCore::to_text(self : UnsatCore) -> String {
  let parts : Array[String] = []
  for entry in self.entries {
    parts.push(entry.to_text())
  }
  parts.join(",")
}

///|
pub fn UnsatCore::to_text_with_expr(
  self : UnsatCore,
  expr_text : (@util.ExprId) -> String,
) -> String {
  let parts : Array[String] = []
  for entry in self.entries {
    match entry.name {
      Some(name) => parts.push(name)
      None => parts.push(expr_text(entry.expr))
    }
  }
  parts.join(",")
}
