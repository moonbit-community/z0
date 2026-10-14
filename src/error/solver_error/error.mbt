///|
pub(all) suberror SolverError {
  SolverError(String)
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend SolverError with Eq::{not_equal, equal}

///|
pub fn SolverError::prefix(_self : SolverError) -> String {
  "solver"
}

///|
pub fn SolverError::format(self : SolverError) -> String {
  match self {
    SolverError(message) => "\{self.prefix()}: \{message}"
  }
}

///|
pub impl Show for SolverError with fn output(self, logger) {
  logger.write_string(self.format())
}

///|
#deprecated
#doc(hidden)
pub extend SolverError with Show::{to_string, output}
