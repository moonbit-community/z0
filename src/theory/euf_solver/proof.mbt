///|
priv struct EufProofHintRecord {
  hint : @theory_core.ProofHintId
  kind : String
}

///|
pub struct EufProofHints {
  priv records : Array[EufProofHintRecord]
}

///|
pub fn EufProofHints::new() -> EufProofHints {
  { records: [] }
}

///|
pub fn EufProofHints::add_congruence(
  self : EufProofHints,
  owner : @ids.TheoryId,
  detail : String,
) -> @theory_core.ProofHintId {
  let hint = @theory_core.ProofHintId::new(
    owner,
    self.records.length(),
    scope_generation=0,
  )
  self.records.push(EufProofHintRecord::{ hint, kind: "congruence(\{detail})" })
  hint
}

///|
pub fn EufProofHints::kind_text(
  self : EufProofHints,
  hint : @theory_core.ProofHintId,
) -> String {
  for record in self.records {
    if record.hint == hint {
      return record.kind
    }
  }
  "invalid"
}
