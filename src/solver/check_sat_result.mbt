///|
pub(all) enum CheckSatResult {
  CheckSat
  CheckUnsat
  CheckUnknown(@util.ReasonUnknown, Bool)
} derive(Eq)

///|
pub fn CheckSatResult::sat() -> CheckSatResult {
  CheckSat
}

///|
pub fn CheckSatResult::unsat() -> CheckSatResult {
  CheckUnsat
}

///|
pub fn CheckSatResult::unknown_no_model(
  reason : @util.ReasonUnknown,
) -> CheckSatResult {
  CheckUnknown(reason, false)
}

///|
pub fn CheckSatResult::unknown_with_model(
  reason : @util.ReasonUnknown,
) -> CheckSatResult {
  CheckUnknown(reason, true)
}

///|
pub fn CheckSatResult::result_kind(self : CheckSatResult) -> @util.ResultKind {
  match self {
    CheckSat => @util.ResultKind::Sat
    CheckUnsat => @util.ResultKind::Unsat
    CheckUnknown(_, true) => @util.ResultKind::unknown_with_model()
    CheckUnknown(_, false) => @util.ResultKind::unknown_no_model()
  }
}

///|
pub fn CheckSatResult::to_text(self : CheckSatResult) -> String {
  match self {
    CheckSat => "sat"
    CheckUnsat => "unsat"
    CheckUnknown(reason, _) => "unknown: \{reason.to_text()}"
  }
}

///|
pub fn CheckSatResult::reason_unknown(
  self : CheckSatResult,
) -> @util.ReasonUnknown? {
  match self {
    CheckUnknown(reason, _) => Some(reason)
    _ => None
  }
}

///|
pub struct CheckSatAssumingResult {
  priv result : CheckSatResult
  priv unsat_assumptions : UnsatAssumptionSet
  priv unsat_core : UnsatCore
}

///|
pub fn CheckSatAssumingResult::new(
  result : CheckSatResult,
  unsat_assumptions : UnsatAssumptionSet,
) -> CheckSatAssumingResult {
  { result, unsat_assumptions, unsat_core: UnsatCore::empty() }
}

///|
pub fn CheckSatAssumingResult::new_with_core(
  result : CheckSatResult,
  unsat_assumptions : UnsatAssumptionSet,
  unsat_core : UnsatCore,
) -> CheckSatAssumingResult {
  { result, unsat_assumptions, unsat_core }
}

///|
pub fn CheckSatAssumingResult::from_result(
  result : CheckSatResult,
) -> CheckSatAssumingResult {
  {
    result,
    unsat_assumptions: UnsatAssumptionSet::empty(),
    unsat_core: UnsatCore::empty(),
  }
}

///|
pub fn CheckSatAssumingResult::result(
  self : CheckSatAssumingResult,
) -> CheckSatResult {
  self.result
}

///|
pub fn CheckSatAssumingResult::unsat_assumptions(
  self : CheckSatAssumingResult,
) -> UnsatAssumptionSet {
  self.unsat_assumptions
}

///|
pub fn CheckSatAssumingResult::unsat_core(
  self : CheckSatAssumingResult,
) -> UnsatCore {
  self.unsat_core
}
