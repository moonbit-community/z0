///|
fn checkpoint_to_text(value : Availability[Unit]) -> String {
  match value {
    Available(_) => "ok"
    Unavailable(reason) => reason.to_text()
  }
}

///|
test "resource_limit_allows_until_budget_is_exhausted" {
  let limit = ResourceLimit::with_step_limit(2)
  inspect(checkpoint_to_text(limit.checkpoint()), content="ok")
  inspect(checkpoint_to_text(limit.checkpoint()), content="ok")
  inspect(
    checkpoint_to_text(limit.checkpoint()),
    content="unknown(resource-limit-exceeded)",
  )
  inspect(limit.used_steps(), content="2")
}

///|
test "resource_limit_reset_restores_budget" {
  let limit = ResourceLimit::with_step_limit(1)
  ignore(limit.checkpoint())
  ignore(limit.checkpoint())
  limit.reset()
  inspect(checkpoint_to_text(limit.checkpoint()), content="ok")
}
