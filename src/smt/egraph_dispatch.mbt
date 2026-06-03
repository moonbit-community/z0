///|
priv struct EGraphDispatchScope {
  eq_cursor : Int
  diseq_cursor : Int
  eq_facts_len : Int
  diseq_facts_len : Int
}

///|
pub struct EGraphDispatchState {
  priv mut eq_cursor : Int
  priv mut diseq_cursor : Int
  priv eq_facts : Array[@theory_core.EqFact]
  priv diseq_facts : Array[@theory_core.DiseqFact]
  priv scopes : Array[EGraphDispatchScope]
}

///|
pub fn EGraphDispatchState::new() -> EGraphDispatchState {
  { eq_cursor: 0, diseq_cursor: 0, eq_facts: [], diseq_facts: [], scopes: [] }
}

///|
pub fn EGraphDispatchState::push(self : EGraphDispatchState) -> Unit {
  self.scopes.push(EGraphDispatchScope::{
    eq_cursor: self.eq_cursor,
    diseq_cursor: self.diseq_cursor,
    eq_facts_len: self.eq_facts.length(),
    diseq_facts_len: self.diseq_facts.length(),
  })
}

///|
fn EGraphDispatchState::pop_one(self : EGraphDispatchState) -> Unit {
  let depth = self.scopes.length()
  if depth == 0 {
    return
  }
  let scope = self.scopes[depth - 1]
  self.scopes.truncate(depth - 1)
  self.eq_cursor = scope.eq_cursor
  self.diseq_cursor = scope.diseq_cursor
  self.eq_facts.truncate(scope.eq_facts_len)
  self.diseq_facts.truncate(scope.diseq_facts_len)
}

///|
pub fn EGraphDispatchState::pop(
  self : EGraphDispatchState,
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
pub fn EGraphDispatchState::eq_fact_count(self : EGraphDispatchState) -> Int {
  self.eq_facts.length()
}

///|
pub fn EGraphDispatchState::diseq_fact_count(self : EGraphDispatchState) -> Int {
  self.diseq_facts.length()
}

///|
fn dispatch_eq_fact(
  theories : Array[@theory_core.TheoryPlugin],
  view : @theory_core.TheoryContextView,
  actions_for : (@theory_core.TheoryPlugin) -> @theory_core.TheoryActions,
  fact : @theory_core.EqFact,
) -> Unit {
  for theory in theories {
    if theory.id() == fact.owner() {
      let actions = actions_for(theory)
      theory.new_eq(view, actions, fact)
    }
  }
}

///|
fn dispatch_diseq_fact(
  theories : Array[@theory_core.TheoryPlugin],
  view : @theory_core.TheoryContextView,
  actions_for : (@theory_core.TheoryPlugin) -> @theory_core.TheoryActions,
  fact : @theory_core.DiseqFact,
) -> Unit {
  for theory in theories {
    if theory.id() == fact.owner() {
      let actions = actions_for(theory)
      theory.new_diseq(view, actions, fact)
    }
  }
}

///|
fn EGraphDispatchState::drain_eq(
  self : EGraphDispatchState,
  graph : @egraph.EGraph,
  link : @egraph.EnodeParentLink,
  theories : Array[@theory_core.TheoryPlugin],
  view : @theory_core.TheoryContextView,
  actions_for : (@theory_core.TheoryPlugin) -> @theory_core.TheoryActions,
) -> Unit {
  let left = graph.theory_attachments(link.child())
  let right = graph.theory_attachments(link.parent())
  for lhs in left {
    for rhs in right {
      if lhs.theory_id() == rhs.theory_id() {
        let fact = @theory_core.EqFact::new(
          lhs.theory_id(),
          self.eq_facts.length(),
          scope_generation=view.scope_depth(),
        )
        self.eq_facts.push(fact)
        dispatch_eq_fact(theories, view, actions_for, fact)
      }
    }
  }
}

///|
fn EGraphDispatchState::drain_diseq(
  self : EGraphDispatchState,
  graph : @egraph.EGraph,
  eq : @egraph.EnodeId,
  theories : Array[@theory_core.TheoryPlugin],
  view : @theory_core.TheoryContextView,
  actions_for : (@theory_core.TheoryPlugin) -> @theory_core.TheoryActions,
) -> Unit {
  for attachment in graph.theory_attachments(eq) {
    let fact = @theory_core.DiseqFact::new(
      attachment.theory_id(),
      self.diseq_facts.length(),
      scope_generation=view.scope_depth(),
    )
    self.diseq_facts.push(fact)
    dispatch_diseq_fact(theories, view, actions_for, fact)
  }
}

///|
pub fn EGraphDispatchState::drain_new_facts(
  self : EGraphDispatchState,
  graph : @egraph.EGraph,
  theories : Array[@theory_core.TheoryPlugin],
  view : @theory_core.TheoryContextView,
  actions_for : (@theory_core.TheoryPlugin) -> @theory_core.TheoryActions,
) -> Unit {
  while self.eq_cursor < graph.new_eq_count() {
    match graph.new_eq(self.eq_cursor) {
      Some(link) => self.drain_eq(graph, link, theories, view, actions_for)
      None => ()
    }
    self.eq_cursor += 1
  }
  while self.diseq_cursor < graph.new_diseq_count() {
    match graph.new_diseq(self.diseq_cursor) {
      Some(eq) => self.drain_diseq(graph, eq, theories, view, actions_for)
      None => ()
    }
    self.diseq_cursor += 1
  }
}
