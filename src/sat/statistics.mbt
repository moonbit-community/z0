///|
pub(all) struct SatCoreSnapshot {
  vars : Int32
  root_clauses : Int32
  learned_clauses : Int32
  deleted_clauses : Int32
  decisions : Int32
  propagations : Int32
  activity_text : String
  phase_text : String
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend SatCoreSnapshot with Eq::{not_equal, equal}

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
