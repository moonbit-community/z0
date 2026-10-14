///|
pub struct ProofObjectChecker {
  priv checkers : Array[ProofHintChecker]
}

///|
pub fn ProofObjectChecker::new(
  checkers : Array[ProofHintChecker],
) -> ProofObjectChecker {
  { checkers: checkers.copy(), }
}

///|
fn invalid_proof() -> @util.Availability[Unit] {
  Unavailable(@util.AvailabilityReason::unknown(InvalidProof))
}

///|
fn ProofObjectChecker::find_checker(
  self : ProofObjectChecker,
  owner : String,
) -> ProofHintChecker? {
  for checker in self.checkers {
    if checker.name() == owner {
      return Some(checker)
    }
  }
  None
}

///|
fn ProofObjectChecker::check_hint(
  self : ProofObjectChecker,
  hint : ProofHint,
) -> @util.Availability[Unit] {
  match self.find_checker(hint.owner_text()) {
    Some(checker) =>
      match checker.check_hint(hint) {
        Available(_) => Available(())
        Unavailable(_) => invalid_proof()
      }
    None => invalid_proof()
  }
}

///|
pub fn ProofObjectChecker::check(
  self : ProofObjectChecker,
  proof : ProofObject,
) -> @util.Availability[Unit] {
  for hint in proof.hints() {
    match self.check_hint(hint) {
      Available(_) => ()
      Unavailable(reason) => return Unavailable(reason)
    }
  }
  Available(())
}
