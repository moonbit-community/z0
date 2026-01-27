///|
pub suberror Smt2Error {
  Malformed(String)
  UnknownSort(String)
  UnknownSymbol(String)
  ArityMismatch(name~ : String, expected~ : Int, found~ : Int)
  ScopeUnderflow(expected~ : Int, available~ : Int)
  Unsupported(String)
} derive(Show, ToJson, Eq)
