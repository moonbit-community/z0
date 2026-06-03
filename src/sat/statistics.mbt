///|
pub(all) struct SatCoreSnapshot {
  vars : Int
  root_clauses : Int
  learned_clauses : Int
  deleted_clauses : Int
  decisions : Int
  propagations : Int
  activity_text : String
  phase_text : String
} derive(Eq)

///|
pub fn SatCoreSnapshot::to_statistics(
  self : SatCoreSnapshot,
) -> @stats.Statistics {
  let statistics = @stats.Statistics::new()
  statistics.inc_counter(
    "sat.core.clauses",
    self.root_clauses + self.learned_clauses,
  )
  statistics.inc_counter("sat.core.decisions", self.decisions)
  statistics.inc_counter("sat.core.deleted_clauses", self.deleted_clauses)
  statistics.inc_counter("sat.core.learned_clauses", self.learned_clauses)
  statistics.inc_counter("sat.core.propagations", self.propagations)
  statistics.inc_counter("sat.core.vars", self.vars)
  statistics
}
