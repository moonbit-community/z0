///|
pub suberror SolverError {
  Unsupported(String)
  InvalidAssertion(String)
  ScopeUnderflow(expected~ : Int, available~ : Int)
} derive(Show, Eq)

///|
pub enum CheckSatResult {
  Sat(Model)
  Unsat
  Unknown(String)
} derive(Show, Eq)
