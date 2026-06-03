///|
pub(all) suberror SolverError {
  SolverError(String)
} derive(Eq)

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
