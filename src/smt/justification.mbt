///|
priv struct SmtProofHintRecord {
  hint : @theory_core.ProofHintId
  kind : String
}

///|
priv struct SmtJustificationScope {
  proof_hints_len : Int
}

///|
priv struct SmtJustificationStore {
  proof_hints : Array[SmtProofHintRecord]
  scopes : Array[SmtJustificationScope]
}

///|
fn SmtJustificationStore::new() -> SmtJustificationStore {
  { proof_hints: [], scopes: [] }
}

///|
fn SmtJustificationStore::push(self : SmtJustificationStore) -> Unit {
  self.scopes.push(SmtJustificationScope::{
    proof_hints_len: self.proof_hints.length(),
  })
}

///|
fn SmtJustificationStore::pop_one(self : SmtJustificationStore) -> Unit {
  let depth = self.scopes.length()
  if depth == 0 {
    return
  }
  let scope = self.scopes[depth - 1]
  self.scopes.truncate(depth - 1)
  self.proof_hints.truncate(scope.proof_hints_len)
}

///|
fn SmtJustificationStore::pop(
  self : SmtJustificationStore,
  count : Int,
) -> Unit {
  if count <= 0 {
    return
  }
  let pop_count = if count > self.scopes.length() {
    self.scopes.length()
  } else {
    count
  }
  for _ in 0..<pop_count {
    self.pop_one()
  }
}

///|
fn SmtJustificationStore::create_proof_hint(
  self : SmtJustificationStore,
  owner : @theory_ids.TheoryId,
  kind : String,
  scope_depth : Int,
) -> @theory_core.ProofHintId {
  let hint = @theory_core.ProofHintId::new(
    owner,
    self.proof_hints.length(),
    scope_generation=scope_depth,
  )
  self.proof_hints.push(SmtProofHintRecord::{ hint, kind })
  hint
}

///|
fn SmtJustificationStore::proof_hint_log_text(
  self : SmtJustificationStore,
) -> String {
  [
    for record in self.proof_hints => "\{record.hint}:\{record.kind}"
  ].join(";")
}

///|
fn SmtJustificationStore::proof_hint_kind_text(
  self : SmtJustificationStore,
  hint : @theory_core.ProofHintId,
) -> String? {
  for record in self.proof_hints {
    if record.hint == hint {
      return Some(record.kind)
    }
  }
  None
}
