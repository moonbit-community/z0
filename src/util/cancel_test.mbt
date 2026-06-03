///|
fn cancel_checkpoint_to_text(value : Availability[Unit]) -> String {
  match value {
    Available(_) => "ok"
    Unavailable(reason) => reason.to_text()
  }
}

///|
test "cancel_flag_reports_api_cancel" {
  let flag = CancelFlag::new()
  inspect(cancel_checkpoint_to_text(flag.checkpoint()), content="ok")
  flag.cancel_api()
  inspect(flag.is_canceled(), content="true")
  inspect(
    cancel_checkpoint_to_text(flag.checkpoint()),
    content="unknown(canceled(api))",
  )
}

///|
test "cancel_flag_reset_clears_cancel_state" {
  let flag = CancelFlag::new()
  flag.cancel_user()
  flag.reset()
  inspect(flag.is_canceled(), content="false")
  inspect(cancel_checkpoint_to_text(flag.checkpoint()), content="ok")
}
