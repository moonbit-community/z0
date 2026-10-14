///|
fn availability_to_text(value : @util.Availability[Int32]) -> String {
  match value {
    Available(v) => "available:\{v}"
    Unavailable(reason) => "unavailable:\{reason.to_text()}"
  }
}

///|
test "availability_wraps_available_value" {
  inspect(availability_to_text(Available(42)), content="available:42")
}

///|
test "availability_reports_typed_unsupported_reason" {
  let reason = @util.AvailabilityReason::unsupported(
    @util.ReasonUnknown::unsupported_fragment("array"),
  )
  inspect(
    availability_to_text(Unavailable(reason)),
    content="unavailable:unsupported(array)",
  )
}

///|
test "result_kind_distinguishes_unknown_model_availability" {
  inspect(
    @util.ResultKind::unknown_with_model().to_text(),
    content="unknown-with-model",
  )
  inspect(
    @util.ResultKind::unknown_no_model().to_text(),
    content="unknown-no-model",
  )
}

///|
test "wrong_result_reason_formats_expected_and_actual" {
  let reason = @util.AvailabilityReason::wrong_result(Unsat, Sat)
  inspect(reason.to_text(), content="wrong-result(expected=unsat, actual=sat)")
}

///|
test "model_availability_reasons_are_typed" {
  inspect(@util.ReasonUnknown::InvalidModel.to_text(), content="invalid-model")
  inspect(
    @util.ReasonUnknown::ModelEvalFailed.to_text(),
    content="model-eval-failed",
  )
  inspect(
    @util.ReasonUnknown::ModelValidationFailed.to_text(),
    content="model-validation-failed",
  )
}
