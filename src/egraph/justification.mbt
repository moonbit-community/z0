///|
pub struct JustificationId {
  priv value : Int
} derive(Eq, Compare, Hash)

///|
pub fn JustificationId::new(value : Int) -> JustificationId {
  { value, }
}

///|
pub fn JustificationId::to_int(self : JustificationId) -> Int {
  self.value
}

///|
pub impl Show for JustificationId with fn output(self, logger) {
  logger.write_string("just#\{self.value}")
}

///|
priv enum JustificationKind {
  Axiom(@ids.TheoryId)
  Equality(EnodeId, EnodeId)
}

///|
priv struct JustificationRecord {
  kind : JustificationKind
}

///|
fn JustificationRecord::axiom(theory_id : @ids.TheoryId) -> JustificationRecord {
  { kind: Axiom(theory_id) }
}

///|
fn JustificationRecord::equality(
  lhs : EnodeId,
  rhs : EnodeId,
) -> JustificationRecord {
  { kind: Equality(lhs, rhs) }
}

///|
fn JustificationRecord::to_text(self : JustificationRecord) -> String {
  match self.kind {
    Axiom(theory_id) => "axiom(\{theory_id})"
    Equality(lhs, rhs) => "eq(\{lhs},\{rhs})"
  }
}
