///|
pub struct ResourceLimit {
  priv mut used : Int
  priv max_steps : Int?
}

///|
pub fn ResourceLimit::unlimited() -> ResourceLimit {
  { used: 0, max_steps: None }
}

///|
pub fn ResourceLimit::with_step_limit(max_steps : Int) -> ResourceLimit {
  { used: 0, max_steps: Some(max_steps) }
}

///|
pub fn ResourceLimit::checkpoint(self : ResourceLimit) -> Availability[Unit] {
  match self.max_steps {
    None => {
      self.used += 1
      Available(())
    }
    Some(limit) =>
      if self.used < limit {
        self.used += 1
        Available(())
      } else {
        Unavailable(AvailabilityReason::unknown(ResourceLimitExceeded))
      }
  }
}

///|
pub fn ResourceLimit::used_steps(self : ResourceLimit) -> Int {
  self.used
}

///|
pub fn ResourceLimit::reset(self : ResourceLimit) -> Unit {
  self.used = 0
}
