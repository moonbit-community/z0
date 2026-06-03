///|
priv struct EGraphCongruenceScope {
  parents : Array[EnodeId]
  ranks : Array[Int]
  terms_len : Int
  disequalities_len : Int
  conflict : Bool
}

///|
priv struct EGraphDisequality {
  lhs : EnodeId
  rhs : EnodeId
}

///|
pub struct EGraphCongruence {
  priv parents : Array[EnodeId]
  priv ranks : Array[Int]
  priv terms : Array[EnodeId]
  priv disequalities : Array[EGraphDisequality]
  priv scopes : Array[EGraphCongruenceScope]
  priv mut conflict : Bool
}

///|
pub fn EGraphCongruence::new() -> EGraphCongruence {
  {
    parents: [],
    ranks: [],
    terms: [],
    disequalities: [],
    scopes: [],
    conflict: false,
  }
}

///|
fn EGraphCongruence::ensure(self : EGraphCongruence, id : EnodeId) -> Unit {
  while self.parents.length() <= id.to_int() {
    let next = EnodeId::new(self.parents.length())
    self.parents.push(next)
    self.ranks.push(0)
  }
}

///|
pub fn EGraphCongruence::add_term(
  self : EGraphCongruence,
  id : EnodeId,
) -> Unit {
  self.ensure(id)
  for term in self.terms {
    if term == id {
      return
    }
  }
  self.terms.push(id)
}

///|
pub fn EGraphCongruence::find(self : EGraphCongruence, id : EnodeId) -> EnodeId {
  self.ensure(id)
  let mut current = id
  let mut parent = self.parents[current.to_int()]
  while parent != current {
    current = parent
    parent = self.parents[current.to_int()]
  }
  current
}

///|
fn EGraphCongruence::check_disequalities(self : EGraphCongruence) -> Unit {
  for diseq in self.disequalities {
    if self.find(diseq.lhs) == self.find(diseq.rhs) {
      self.conflict = true
      return
    }
  }
}

///|
pub fn EGraphCongruence::merge(
  self : EGraphCongruence,
  lhs : EnodeId,
  rhs : EnodeId,
) -> Bool {
  self.add_term(lhs)
  self.add_term(rhs)
  let lhs_root = self.find(lhs)
  let rhs_root = self.find(rhs)
  if lhs_root == rhs_root {
    false
  } else {
    let lhs_index = lhs_root.to_int()
    let rhs_index = rhs_root.to_int()
    let lhs_rank = self.ranks[lhs_index]
    let rhs_rank = self.ranks[rhs_index]
    if lhs_rank < rhs_rank {
      self.parents[lhs_index] = rhs_root
    } else if lhs_rank > rhs_rank {
      self.parents[rhs_index] = lhs_root
    } else {
      self.parents[rhs_index] = lhs_root
      self.ranks[lhs_index] = lhs_rank + 1
    }
    self.check_disequalities()
    true
  }
}

///|
pub fn EGraphCongruence::same_class(
  self : EGraphCongruence,
  lhs : EnodeId,
  rhs : EnodeId,
) -> Bool {
  self.find(lhs) == self.find(rhs)
}

///|
pub fn EGraphCongruence::assert_disequal(
  self : EGraphCongruence,
  lhs : EnodeId,
  rhs : EnodeId,
) -> Unit {
  self.add_term(lhs)
  self.add_term(rhs)
  self.disequalities.push(EGraphDisequality::{ lhs, rhs })
  self.check_disequalities()
}

///|
pub fn EGraphCongruence::has_conflict(self : EGraphCongruence) -> Bool {
  self.conflict
}

///|
fn EGraphCongruence::congruent(
  self : EGraphCongruence,
  graph : EGraph,
  lhs : EnodeId,
  rhs : EnodeId,
) -> Bool {
  let key = graph.operator_key(lhs)
  if key < 0 || key != graph.operator_key(rhs) {
    return false
  }
  let lhs_args = graph.args(lhs)
  let rhs_args = graph.args(rhs)
  if lhs_args.length() != rhs_args.length() {
    return false
  }
  for i in 0..<lhs_args.length() {
    if self.find(lhs_args[i]) != self.find(rhs_args[i]) {
      return false
    }
  }
  true
}

///|
pub fn EGraphCongruence::close(self : EGraphCongruence, graph : EGraph) -> Unit {
  let mut changed = true
  while changed {
    changed = false
    for i in 0..<self.terms.length() {
      for j in (i + 1)..<self.terms.length() {
        let lhs = self.terms[i]
        let rhs = self.terms[j]
        if self.find(lhs) != self.find(rhs) &&
          self.congruent(graph, lhs, rhs) &&
          self.merge(lhs, rhs) {
          changed = true
        }
      }
    }
  }
  self.check_disequalities()
}

///|
pub fn EGraphCongruence::push(self : EGraphCongruence) -> Unit {
  self.scopes.push(EGraphCongruenceScope::{
    parents: self.parents.copy(),
    ranks: self.ranks.copy(),
    terms_len: self.terms.length(),
    disequalities_len: self.disequalities.length(),
    conflict: self.conflict,
  })
}

///|
pub fn EGraphCongruence::pop(self : EGraphCongruence, count : Int) -> Unit {
  if count <= 0 {
    return
  }
  let depth = self.scopes.length()
  let pop_count = if count > depth { depth } else { count }
  if pop_count == 0 {
    return
  }
  let target = depth - pop_count
  let scope = self.scopes[target]
  self.parents.clear()
  for parent in scope.parents {
    self.parents.push(parent)
  }
  self.ranks.clear()
  for rank in scope.ranks {
    self.ranks.push(rank)
  }
  self.terms.truncate(scope.terms_len)
  self.disequalities.truncate(scope.disequalities_len)
  self.conflict = scope.conflict
  self.scopes.truncate(target)
}
