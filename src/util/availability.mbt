///|
pub(all) enum ResultKind {
  NoResult
  Sat
  Unsat
  Unknown(Bool)
} derive(Eq)

///|
pub fn ResultKind::unknown_with_model() -> ResultKind {
  Unknown(true)
}

///|
pub fn ResultKind::unknown_no_model() -> ResultKind {
  Unknown(false)
}

///|
pub fn ResultKind::to_text(self : ResultKind) -> String {
  match self {
    NoResult => "no-result"
    Sat => "sat"
    Unsat => "unsat"
    Unknown(true) => "unknown-with-model"
    Unknown(false) => "unknown-no-model"
  }
}

///|
pub(all) enum ReasonUnknown {
  Timeout
  Memout
  MaxConflictsReached
  ResourceLimitExceeded
  Canceled(String)
  IncompleteTheory(String)
  IncompleteQuantifiers
  IncompleteLambdas
  UnsupportedFragment(String)
  InvalidCore
  InvalidProof
  InvalidModel
  ModelEvalFailed
  ModelValidationFailed
  Other(String)
} derive(Eq)

///|
pub fn ReasonUnknown::unsupported_fragment(fragment : String) -> ReasonUnknown {
  UnsupportedFragment(fragment)
}

///|
pub fn ReasonUnknown::canceled(kind : String) -> ReasonUnknown {
  Canceled(kind)
}

///|
pub fn ReasonUnknown::to_text(self : ReasonUnknown) -> String {
  match self {
    Timeout => "timeout"
    Memout => "memout"
    MaxConflictsReached => "max-conflicts"
    ResourceLimitExceeded => "resource-limit-exceeded"
    Canceled(kind) => "canceled(\{kind})"
    IncompleteTheory(name) => "incomplete-theory(\{name})"
    IncompleteQuantifiers => "incomplete-quantifiers"
    IncompleteLambdas => "incomplete-lambdas"
    UnsupportedFragment(fragment) => "unsupported-fragment(\{fragment})"
    InvalidCore => "invalid-core"
    InvalidProof => "invalid-proof"
    InvalidModel => "invalid-model"
    ModelEvalFailed => "model-eval-failed"
    ModelValidationFailed => "model-validation-failed"
    Other(reason) => reason
  }
}

///|
pub(all) enum AvailabilityReason {
  Disabled(String)
  Unsupported(ReasonUnknown)
  NoCurrentResult
  WrongResult(ResultKind, ResultKind)
  Stale
  UnknownReason(ReasonUnknown)
} derive(Eq)

///|
pub fn AvailabilityReason::unsupported(
  reason : ReasonUnknown,
) -> AvailabilityReason {
  Unsupported(reason)
}

///|
pub fn AvailabilityReason::wrong_result(
  expected : ResultKind,
  actual : ResultKind,
) -> AvailabilityReason {
  WrongResult(expected, actual)
}

///|
pub fn AvailabilityReason::unknown(
  reason : ReasonUnknown,
) -> AvailabilityReason {
  UnknownReason(reason)
}

///|
pub fn AvailabilityReason::to_text(self : AvailabilityReason) -> String {
  match self {
    Disabled(feature) => "disabled(\{feature})"
    Unsupported(UnsupportedFragment(fragment)) => "unsupported(\{fragment})"
    Unsupported(reason) => "unsupported(\{reason.to_text()})"
    NoCurrentResult => "no-current-result"
    WrongResult(expected, actual) =>
      "wrong-result(expected=\{expected.to_text()}, actual=\{actual.to_text()})"
    Stale => "stale"
    UnknownReason(reason) => "unknown(\{reason.to_text()})"
  }
}

///|
pub(all) enum Availability[T] {
  Available(T)
  Unavailable(AvailabilityReason)
} derive(Eq)
