///|
pub struct JustificationId {
  priv value : Int32
} derive(Eq, Compare, Hash)

///|
#deprecated
#doc(hidden)
pub extend JustificationId with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend JustificationId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
#doc(hidden)
pub extend JustificationId with Hash::{hash, hash_combine}

///|
pub fn JustificationId::new(value : Int32) -> JustificationId {
  { value, }
}

///|
pub fn JustificationId::to_int(self : JustificationId) -> Int32 {
  self.value
}

///|
pub impl Show for JustificationId with fn output(self, logger) {
  logger.write_string("just#\{self.value}")
}

///|
#deprecated
#doc(hidden)
pub extend JustificationId with Show::{to_string, output}

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
  { kind: Axiom(theory_id), }
}

///|
fn JustificationRecord::equality(
  lhs : EnodeId,
  rhs : EnodeId,
) -> JustificationRecord {
  { kind: Equality(lhs, rhs), }
}

///|
fn JustificationRecord::to_text(self : JustificationRecord) -> String {
  match self.kind {
    Axiom(theory_id) => "axiom(\{theory_id})"
    Equality(lhs, rhs) => "eq(\{lhs},\{rhs})"
  }
}
