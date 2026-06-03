///|
pub(all) enum SolverResult {
  Sat
  Unsat
  Unknown(String)
} derive(Eq)

///|
pub struct SmtUnsatCoreEntry {
  priv expr : @util.ExprId
  priv name : String?
} derive(Eq)

///|
pub fn SmtUnsatCoreEntry::new(
  expr : @util.ExprId,
  name : String?,
) -> SmtUnsatCoreEntry {
  { expr, name }
}

///|
pub fn SmtUnsatCoreEntry::expr(self : SmtUnsatCoreEntry) -> @util.ExprId {
  self.expr
}

///|
pub fn SmtUnsatCoreEntry::name(self : SmtUnsatCoreEntry) -> String? {
  self.name
}

///|
pub fn SmtUnsatCoreEntry::to_text(self : SmtUnsatCoreEntry) -> String {
  match self.name {
    Some(name) => name
    None => "\{self.expr}"
  }
}

///|
pub(all) enum SolverAssumptionResult {
  AssumptionSat
  AssumptionUnsat(Array[@util.ExprId], Array[SmtUnsatCoreEntry])
  AssumptionUnknown(String)
} derive(Eq)
