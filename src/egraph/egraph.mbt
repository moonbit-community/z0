///|
priv struct ExprEnodeBinding {
  expr : @util.ExprId
  enode : EnodeId
}

///|
priv struct ScopedLength {
  index : Int
  length : Int
}

///|
priv struct EGraphScope {
  nodes_len : Int
  bindings_len : Int
  justifications_len : Int
  new_eqs_len : Int
  new_diseqs_len : Int
  parent_lengths : Array[ScopedLength]
  theory_var_lengths : Array[ScopedLength]
}

///|
pub struct EGraph {
  priv nodes : Array[EnodeRecord]
  priv expr_bindings : Array[ExprEnodeBinding]
  priv justifications : Array[JustificationRecord]
  priv scopes : Array[EGraphScope]
  priv new_eqs : Array[EnodeParentLink]
  priv new_diseqs : Array[EnodeId]
}

///|
pub fn EGraph::new() -> EGraph {
  {
    nodes: [],
    expr_bindings: [],
    justifications: [],
    scopes: [],
    new_eqs: [],
    new_diseqs: [],
  }
}

///|
fn EGraph::valid_index(self : EGraph, id : EnodeId) -> Bool {
  id.to_int() >= 0 && id.to_int() < self.nodes.length()
}

///|
pub fn EGraph::find(self : EGraph, expr : @util.ExprId) -> EnodeId? {
  for binding in self.expr_bindings {
    if binding.expr == expr {
      return Some(binding.enode)
    }
  }
  None
}

///|
pub fn EGraph::mk_enode(
  self : EGraph,
  expr : @util.ExprId,
  args : Array[EnodeId],
  generation : Int,
) -> EnodeId {
  self.mk_enode_with_key(expr, args, generation, expr.to_int())
}

///|
pub fn EGraph::mk_enode_with_key(
  self : EGraph,
  expr : @util.ExprId,
  args : Array[EnodeId],
  generation : Int,
  operator_key : Int,
) -> EnodeId {
  match self.find(expr) {
    Some(id) => id
    None => {
      let id = EnodeId::new(self.nodes.length())
      self.nodes.push(
        EnodeRecord::new(id, expr, args, generation, operator_key),
      )
      self.expr_bindings.push(ExprEnodeBinding::{ expr, enode: id })
      for arg in args {
        if self.valid_index(arg) {
          self.nodes[arg.to_int()].parents.push(id)
        }
      }
      id
    }
  }
}

///|
pub fn EGraph::expr_handle(self : EGraph, id : EnodeId) -> EnodeExpr? {
  if self.valid_index(id) {
    Some(
      EnodeExpr::new(self.nodes[id.to_int()].id, self.nodes[id.to_int()].expr),
    )
  } else {
    None
  }
}

///|
pub fn EGraph::parents(self : EGraph, id : EnodeId) -> Array[EnodeId] {
  if self.valid_index(id) {
    self.nodes[id.to_int()].parents.copy()
  } else {
    []
  }
}

///|
pub fn EGraph::args(self : EGraph, id : EnodeId) -> Array[EnodeId] {
  if self.valid_index(id) {
    self.nodes[id.to_int()].args.copy()
  } else {
    []
  }
}

///|
pub fn EGraph::operator_key(self : EGraph, id : EnodeId) -> Int {
  if self.valid_index(id) {
    self.nodes[id.to_int()].operator_key
  } else {
    -1
  }
}

///|
pub fn EGraph::set_relevant(self : EGraph, id : EnodeId) -> Unit {
  if self.valid_index(id) {
    self.nodes[id.to_int()].relevant = true
  }
}

///|
pub fn EGraph::is_relevant(self : EGraph, id : EnodeId) -> Bool {
  self.valid_index(id) && self.nodes[id.to_int()].relevant
}

///|
pub fn EGraph::generation(self : EGraph, id : EnodeId) -> Int {
  if self.valid_index(id) {
    self.nodes[id.to_int()].generation
  } else {
    -1
  }
}

///|
pub fn EGraph::push(self : EGraph) -> Unit {
  let parent_lengths : Array[ScopedLength] = []
  let theory_var_lengths : Array[ScopedLength] = []
  for i in 0..<self.nodes.length() {
    parent_lengths.push(ScopedLength::{
      index: i,
      length: self.nodes[i].parents.length(),
    })
    theory_var_lengths.push(ScopedLength::{
      index: i,
      length: self.nodes[i].theory_vars.length(),
    })
  }
  self.scopes.push(EGraphScope::{
    nodes_len: self.nodes.length(),
    bindings_len: self.expr_bindings.length(),
    justifications_len: self.justifications.length(),
    new_eqs_len: self.new_eqs.length(),
    new_diseqs_len: self.new_diseqs.length(),
    parent_lengths,
    theory_var_lengths,
  })
}

///|
fn EGraph::pop_one(self : EGraph) -> Unit {
  let depth = self.scopes.length()
  if depth == 0 {
    return
  }
  let scope = self.scopes[depth - 1]
  self.scopes.truncate(depth - 1)
  for saved in scope.parent_lengths {
    if saved.index >= 0 && saved.index < self.nodes.length() {
      self.nodes[saved.index].parents.truncate(saved.length)
    }
  }
  for saved in scope.theory_var_lengths {
    if saved.index >= 0 && saved.index < self.nodes.length() {
      self.nodes[saved.index].theory_vars.truncate(saved.length)
    }
  }
  self.nodes.truncate(scope.nodes_len)
  self.expr_bindings.truncate(scope.bindings_len)
  self.justifications.truncate(scope.justifications_len)
  self.new_eqs.truncate(scope.new_eqs_len)
  self.new_diseqs.truncate(scope.new_diseqs_len)
}

///|
pub fn EGraph::pop(self : EGraph, count : Int) -> Unit {
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
pub fn EGraph::attach_theory_var(
  self : EGraph,
  id : EnodeId,
  theory_id : @ids.TheoryId,
  theory_var : @ids.TheoryVar,
) -> Unit {
  if self.valid_index(id) {
    self.nodes[id.to_int()].theory_vars.push(
      EnodeTheoryVarAttachment::new(theory_id, theory_var),
    )
  }
}

///|
pub fn EGraph::theory_var_text(
  self : EGraph,
  id : EnodeId,
  theory_id : @ids.TheoryId,
) -> String {
  if !self.valid_index(id) {
    return "missing"
  }
  let attachments = self.nodes[id.to_int()].theory_vars
  let mut index = attachments.length()
  while index > 0 {
    index -= 1
    if attachments[index].theory_id() == theory_id {
      return "\{attachments[index].theory_var()}"
    }
  }
  "missing"
}

///|
pub fn EGraph::theory_attachments(
  self : EGraph,
  id : EnodeId,
) -> Array[EnodeTheoryVarAttachment] {
  if self.valid_index(id) {
    self.nodes[id.to_int()].theory_vars.copy()
  } else {
    []
  }
}

///|
pub fn EGraph::add_axiom_justification(
  self : EGraph,
  theory_id : @ids.TheoryId,
) -> JustificationId {
  let id = JustificationId::new(self.justifications.length())
  self.justifications.push(JustificationRecord::axiom(theory_id))
  id
}

///|
pub fn EGraph::add_equality_justification(
  self : EGraph,
  lhs : EnodeId,
  rhs : EnodeId,
) -> JustificationId {
  let id = JustificationId::new(self.justifications.length())
  self.justifications.push(JustificationRecord::equality(lhs, rhs))
  id
}

///|
pub fn EGraph::justification_valid(self : EGraph, id : JustificationId) -> Bool {
  id.to_int() >= 0 && id.to_int() < self.justifications.length()
}

///|
pub fn EGraph::justification_text(
  self : EGraph,
  id : JustificationId,
) -> String {
  if self.justification_valid(id) {
    self.justifications[id.to_int()].to_text()
  } else {
    "invalid"
  }
}

///|
pub fn EGraph::new_eq_count(self : EGraph) -> Int {
  self.new_eqs.length()
}

///|
pub fn EGraph::enqueue_new_eq(
  self : EGraph,
  child : EnodeId,
  root : EnodeId,
) -> Unit {
  if self.valid_index(child) && self.valid_index(root) {
    self.new_eqs.push(EnodeParentLink::new(child, root))
  }
}

///|
pub fn EGraph::new_eq(self : EGraph, index : Int) -> EnodeParentLink? {
  match self.new_eqs.get(index) {
    Some(link) => Some(link)
    None => None
  }
}

///|
pub fn EGraph::new_eq_text(self : EGraph, index : Int) -> String {
  match self.new_eq(index) {
    Some(link) => "\{link.child()}->\{link.parent()}"
    None => "missing"
  }
}

///|
pub fn EGraph::new_diseq_count(self : EGraph) -> Int {
  self.new_diseqs.length()
}

///|
pub fn EGraph::enqueue_new_diseq(self : EGraph, eq : EnodeId) -> Unit {
  if self.valid_index(eq) {
    self.new_diseqs.push(eq)
  }
}

///|
pub fn EGraph::new_diseq(self : EGraph, index : Int) -> EnodeId? {
  match self.new_diseqs.get(index) {
    Some(eq) => Some(eq)
    None => None
  }
}

///|
pub fn EGraph::new_diseq_text(self : EGraph, index : Int) -> String {
  match self.new_diseq(index) {
    Some(eq) => "\{eq}"
    None => "missing"
  }
}

///|
pub fn EGraph::scope_depth(self : EGraph) -> Int {
  self.scopes.length()
}

///|
pub fn EGraph::node_count(self : EGraph) -> Int {
  self.nodes.length()
}
