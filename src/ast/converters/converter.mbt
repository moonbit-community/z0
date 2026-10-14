///|
fn unsupported_reason(feature : String) -> @util.AvailabilityReason {
  @util.AvailabilityReason::unsupported(
    @util.ReasonUnknown::unsupported_fragment(feature),
  )
}

///|
fn[T] converter_unavailable(feature : String) -> @util.Availability[T] {
  Unavailable(unsupported_reason(feature))
}

///|
fn converter_join_steps(steps : Array[String]) -> String {
  steps.join(">")
}
