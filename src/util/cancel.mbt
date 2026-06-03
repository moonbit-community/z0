///|
pub struct CancelFlag {
  priv mut reason : ReasonUnknown?
}

///|
pub fn CancelFlag::new() -> CancelFlag {
  { reason: None }
}

///|
pub fn CancelFlag::cancel_api(self : CancelFlag) -> Unit {
  self.reason = Some(ReasonUnknown::canceled("api"))
}

///|
pub fn CancelFlag::cancel_user(self : CancelFlag) -> Unit {
  self.reason = Some(ReasonUnknown::canceled("user"))
}

///|
pub fn CancelFlag::is_canceled(self : CancelFlag) -> Bool {
  self.reason is Some(_)
}

///|
pub fn CancelFlag::checkpoint(self : CancelFlag) -> Availability[Unit] {
  match self.reason {
    Some(reason) => Unavailable(AvailabilityReason::unknown(reason))
    None => Available(())
  }
}

///|
pub fn CancelFlag::reset(self : CancelFlag) -> Unit {
  self.reason = None
}
