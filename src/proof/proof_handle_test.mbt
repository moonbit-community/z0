///|
fn proof_availability_text(
  value : @util.Availability[@proof.ProofRef],
) -> String {
  match value {
    Available(proof) => proof.to_text()
    Unavailable(reason) => reason.to_text()
  }
}

///|
fn unit_availability_text(value : @util.Availability[Unit]) -> String {
  match value {
    Available(_) => "available"
    Unavailable(reason) => reason.to_text()
  }
}

///|
test "proof_handle_is_unavailable_when_disabled" {
  let handle = @proof.ProofHandle::disabled("produce-proofs")
  inspect(
    proof_availability_text(handle.view()),
    content="disabled(produce-proofs)",
  )
}

///|
test "proof_handle_does_not_fake_success_for_missing_proof" {
  let handle = @proof.ProofHandle::no_current_result()
  inspect(proof_availability_text(handle.view()), content="no-current-result")
}

///|
test "proof_handle_can_carry_opaque_proof_object" {
  let object = @proof.ProofObject::from_root_and_hints(
    "sat-events:add clause#0",
    [@proof.ProofHint::with_owner("fake-euf", "congruence")],
  )
  let handle = @proof.ProofHandle::from_object(
    5,
    @proof.ProofKind::ast(),
    object,
  )
  match handle.view() {
    Available(proof) => {
      inspect(proof.to_text(), content="proof#5(ast)")
      match proof.object() {
        Some(proof_object) => {
          inspect(proof_object.root_text(), content="sat-events:add clause#0")
          let hints = proof_object.hints()
          inspect(hints.length(), content="1")
          inspect(hints[0].owner_text(), content="fake-euf")
          inspect(hints[0].kind_text(), content="congruence")
        }
        None => inspect("missing-object", content="has-object")
      }
    }
    Unavailable(reason) => inspect(reason.to_text(), content="available")
  }
}

///|
test "proof_checker_reports_unsupported_seed_mode" {
  let checker = @proof.ProofChecker::unsupported("sat-rup-checker")
  match @proof.ProofHandle::new(4, @proof.ProofKind::ast()).view() {
    Available(proof) =>
      inspect(
        unit_availability_text(checker.check(proof)),
        content="unsupported(sat-rup-checker)",
      )
    Unavailable(reason) =>
      inspect(reason.to_text(), content="unsupported(sat-rup-checker)")
  }
}

///|
test "proof_hint_checker_plugin_trait_is_explicit" {
  let plugin = @proof.ProofHintChecker::new("fake-euf", fn(hint) {
    Unavailable(
      @util.AvailabilityReason::unsupported(
        @util.ReasonUnknown::unsupported_fragment(hint.kind_text()),
      ),
    )
  })
  let hint = @proof.ProofHint::new("congruence")
  inspect(plugin.name(), content="fake-euf")
  inspect(
    unit_availability_text(plugin.check_hint(hint)),
    content="unsupported(congruence)",
  )
}

///|
test "proof_object_checker_accepts_valid_hint_plugin" {
  let plugin = @proof.ProofHintChecker::new("fake-euf", fn(hint) {
    if hint.kind_text() == "congruence" {
      Available(())
    } else {
      Unavailable(@util.AvailabilityReason::unknown(InvalidProof))
    }
  })
  let proof = @proof.ProofObject::from_root_and_hints("false", [
    @proof.ProofHint::with_owner("fake-euf", "congruence"),
  ])
  let checker = @proof.ProofObjectChecker::new([plugin])
  inspect(unit_availability_text(checker.check(proof)), content="available")
}

///|
test "proof_object_checker_rejects_bad_hint_as_invalid_proof" {
  let plugin = @proof.ProofHintChecker::new("fake-euf", fn(_) {
    Unavailable(
      @util.AvailabilityReason::unsupported(
        @util.ReasonUnknown::unsupported_fragment("bad-hint"),
      ),
    )
  })
  let proof = @proof.ProofObject::from_root_and_hints("false", [
    @proof.ProofHint::with_owner("fake-euf", "bad"),
  ])
  let checker = @proof.ProofObjectChecker::new([plugin])
  inspect(
    unit_availability_text(checker.check(proof)),
    content="unknown(invalid-proof)",
  )
}

///|
test "proof_object_checker_rejects_missing_hint_plugin_as_invalid_proof" {
  let proof = @proof.ProofObject::from_root_and_hints("false", [
    @proof.ProofHint::with_owner("missing", "congruence"),
  ])
  let checker = @proof.ProofObjectChecker::new([])
  inspect(
    unit_availability_text(checker.check(proof)),
    content="unknown(invalid-proof)",
  )
}
