///|
pub struct SatProofStatusHook {
  priv events : Array[String]
}

///|
pub fn SatProofStatusHook::new() -> SatProofStatusHook {
  { events: [] }
}

///|
pub fn SatProofStatusHook::clause_added(
  self : SatProofStatusHook,
  clause_id : ClauseId,
  status : ClauseStatus,
) -> Unit {
  self.events.push("add \{clause_id} \{status.event_text()}")
}

///|
pub fn SatProofStatusHook::clause_deleted(
  self : SatProofStatusHook,
  clause_id : ClauseId,
) -> Unit {
  self.events.push("delete \{clause_id}")
}

///|
pub fn SatProofStatusHook::result(
  self : SatProofStatusHook,
  result : SatCoreResult,
) -> Unit {
  let text = match result {
    SatCoreSat(_) => "sat"
    SatCoreUnsat => "unsat"
    SatCoreUnknown(reason) => "unknown:\{reason}"
  }
  self.events.push("result \{text}")
}

///|
pub fn SatProofStatusHook::events_text(self : SatProofStatusHook) -> String {
  self.events.join(";")
}
