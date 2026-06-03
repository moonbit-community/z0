///|
fn model_availability_text(value : @util.Availability[ModelRef]) -> String {
  match value {
    @util.Available(model) => model.to_text()
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
test "model_handle_ref_is_available_after_sat_result" {
  let handle = ModelHandle::new(1, @util.ResultKind::Sat)
  inspect(model_availability_text(handle.view()), content="model#1(sat)")
  inspect(handle.to_text(), content="model-handle#1:sat")
}

///|
test "model_handle_ref_rejects_wrong_result_and_disabled_mode" {
  let disabled = ModelHandle::disabled("produce-models")
  inspect(
    model_availability_text(disabled.view()),
    content="disabled(produce-models)",
  )
  let unsat = ModelHandle::new(2, @util.ResultKind::Unsat)
  inspect(
    model_availability_text(unsat.view()),
    content="wrong-result(expected=sat, actual=unsat)",
  )
}

///|
test "model_handle_ref_reports_stale_state" {
  let handle = ModelHandle::new(3, @util.ResultKind::Sat)
  handle.mark_stale()
  inspect(model_availability_text(handle.view()), content="stale")
}
