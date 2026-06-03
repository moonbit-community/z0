///|
pub struct EnodeId {
  priv value : Int
} derive(Eq, Compare, Hash)

///|
pub fn EnodeId::new(value : Int) -> EnodeId {
  { value, }
}

///|
pub fn EnodeId::to_int(self : EnodeId) -> Int {
  self.value
}

///|
pub impl Show for EnodeId with fn output(self, logger) {
  logger.write_string("enode#\{self.value}")
}

///|
pub struct EnodeExpr {
  priv enode : EnodeId
  priv expr : @util.ExprId
}

///|
pub fn EnodeExpr::new(enode : EnodeId, expr : @util.ExprId) -> EnodeExpr {
  { enode, expr }
}

///|
pub fn EnodeExpr::enode(self : EnodeExpr) -> EnodeId {
  self.enode
}

///|
pub fn EnodeExpr::expr(self : EnodeExpr) -> @util.ExprId {
  self.expr
}

///|
pub struct EnodeParentLink {
  priv child : EnodeId
  priv parent : EnodeId
}

///|
pub fn EnodeParentLink::new(
  child : EnodeId,
  parent : EnodeId,
) -> EnodeParentLink {
  { child, parent }
}

///|
pub fn EnodeParentLink::child(self : EnodeParentLink) -> EnodeId {
  self.child
}

///|
pub fn EnodeParentLink::parent(self : EnodeParentLink) -> EnodeId {
  self.parent
}

///|
pub struct EnodeTheoryVarAttachment {
  priv theory_id : @ids.TheoryId
  priv theory_var : @ids.TheoryVar
}

///|
pub fn EnodeTheoryVarAttachment::new(
  theory_id : @ids.TheoryId,
  theory_var : @ids.TheoryVar,
) -> EnodeTheoryVarAttachment {
  { theory_id, theory_var }
}

///|
pub fn EnodeTheoryVarAttachment::theory_id(
  self : EnodeTheoryVarAttachment,
) -> @ids.TheoryId {
  self.theory_id
}

///|
pub fn EnodeTheoryVarAttachment::theory_var(
  self : EnodeTheoryVarAttachment,
) -> @ids.TheoryVar {
  self.theory_var
}

///|
priv struct EnodeRecord {
  id : EnodeId
  expr : @util.ExprId
  operator_key : Int
  generation : Int
  args : Array[EnodeId]
  parents : Array[EnodeId]
  theory_vars : Array[EnodeTheoryVarAttachment]
  mut relevant : Bool
}

///|
fn EnodeRecord::new(
  id : EnodeId,
  expr : @util.ExprId,
  args : Array[EnodeId],
  generation : Int,
  operator_key : Int,
) -> EnodeRecord {
  EnodeRecord::{
    id,
    expr,
    operator_key,
    generation,
    args: args.copy(),
    parents: [],
    theory_vars: [],
    relevant: false,
  }
}
