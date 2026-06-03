///|
priv struct SmtBoolModelEntry {
  decl : @util.FuncDeclId
  name : String
  value : Bool
}

///|
priv struct SmtEufValueTerm {
  enode : @egraph.EnodeId
  expr : @util.ExprId
  decl : @util.FuncDeclId
  name : String
  sort : @util.SortId
  sort_name : String
}

///|
priv struct SmtEufClassValue {
  root : @egraph.EnodeId
  value : @model.ModelValue
}

///|
priv enum SmtEufValuePendingState {
  SmtEufValuePendingOpen
  SmtEufValuePendingResolving
  SmtEufValuePendingDone
}

///|
priv struct SmtEufValuePending {
  term : SmtEufValueTerm
  root : @egraph.EnodeId
  value_expr : @util.ExprId
  mut state : SmtEufValuePendingState
}

///|
priv struct SmtEufFuncTerm {
  enode : @egraph.EnodeId
  decl : @util.FuncDeclId
  name : String
  domain : Array[String]
  sort : @util.SortId
  range : String
  args : Array[@util.ExprId]
}

///|
priv struct SmtEufFuncEntry {
  args : Array[String]
  value : String
}

///|
priv struct SmtEufFuncModel {
  decl : @util.FuncDeclId
  name : String
  domain : Array[String]
  range : String
  entries : Array[SmtEufFuncEntry]
}

///|
priv struct SmtModelBuilder {
  model : @model.Model
}

///|
priv enum SmtModelBuildResult {
  SmtModelBuildSuccess(@model.Model)
  SmtModelBuildUnknown(@util.ReasonUnknown)
}

///|
priv enum SmtTheoryValueHookResult {
  SmtTheoryValueReady(@util.ExprId?)
  SmtTheoryValueFailed(@util.ReasonUnknown)
}

///|
fn SmtModelBuilder::init_model() -> SmtModelBuilder {
  { model: @model.Model::new() }
}

///|
fn SmtModelBuilder::mk_bool_model(
  self : SmtModelBuilder,
  entries : Array[SmtBoolModelEntry],
) -> Unit {
  for entry in entries {
    self.model.add_bool_const(entry.decl, entry.name, entry.value)
  }
}

///|
fn smt_model_decl_domain_names(
  manager : @ast.AstManager,
  decl : @ast.FuncDecl,
) -> Array[String] {
  let names : Array[String] = []
  for sort in decl.domain {
    names.push(manager.sort_name(sort))
  }
  names
}

///|
fn smt_model_collect_euf_value_terms(
  manager : @ast.AstManager,
  graph : @egraph.EGraph,
) -> Array[SmtEufValueTerm] {
  let terms : Array[SmtEufValueTerm] = []
  for i in 0..<graph.node_count() {
    match graph.expr_handle(@egraph.EnodeId::new(i)) {
      Some(handle) =>
        match manager.get_expr(handle.expr()).kind {
          App(decl_id, args) => {
            let decl = manager.get_decl(decl_id)
            if args.is_empty() &&
              decl.family == manager.uf_family() &&
              decl.range != manager.bool_sort() {
              terms.push(SmtEufValueTerm::{
                enode: handle.enode(),
                expr: handle.expr(),
                decl: decl_id,
                name: decl.name,
                sort: decl.range,
                sort_name: manager.sort_name(decl.range),
              })
            }
          }
          _ => ()
        }
      None => ()
    }
  }
  terms
}

///|
fn smt_model_collect_euf_func_terms(
  manager : @ast.AstManager,
  graph : @egraph.EGraph,
) -> Array[SmtEufFuncTerm] {
  let terms : Array[SmtEufFuncTerm] = []
  for i in 0..<graph.node_count() {
    match graph.expr_handle(@egraph.EnodeId::new(i)) {
      Some(handle) =>
        match manager.get_expr(handle.expr()).kind {
          App(decl_id, args) => {
            let decl = manager.get_decl(decl_id)
            if !args.is_empty() &&
              decl.family == manager.uf_family() &&
              decl.range != manager.bool_sort() {
              terms.push(SmtEufFuncTerm::{
                enode: handle.enode(),
                decl: decl_id,
                name: decl.name,
                domain: smt_model_decl_domain_names(manager, decl),
                sort: decl.range,
                range: manager.sort_name(decl.range),
                args: args.copy(),
              })
            }
          }
          _ => ()
        }
      None => ()
    }
  }
  terms
}

///|
fn smt_model_include_func_interp(
  theories : Array[@theory_core.TheoryPlugin],
  manager : @ast.AstManager,
  decl : @util.FuncDeclId,
) -> Bool {
  let family = manager.get_decl(decl).family
  let mut has_owner = false
  for theory in theories {
    if theory.owns_family(family) {
      has_owner = true
      if theory.include_func_interp(decl) {
        return true
      }
    }
  }
  !has_owner
}

///|
fn smt_model_congruence_from_egraph(
  graph : @egraph.EGraph,
) -> @egraph.EGraphCongruence {
  let congruence = @egraph.EGraphCongruence::new()
  for i in 0..<graph.node_count() {
    congruence.add_term(@egraph.EnodeId::new(i))
  }
  for i in 0..<graph.new_eq_count() {
    match graph.new_eq(i) {
      Some(eq) => ignore(congruence.merge(eq.child(), eq.parent()))
      None => ()
    }
  }
  congruence.close(graph)
  congruence
}

///|
fn smt_model_class_value(
  values : Array[SmtEufClassValue],
  root : @egraph.EnodeId,
) -> @model.ModelValue? {
  for value in values {
    if value.root == root {
      return Some(value.value)
    }
  }
  None
}

///|
fn smt_model_record_class_value(
  values : Array[SmtEufClassValue],
  root : @egraph.EnodeId,
  value : @model.ModelValue,
) -> Unit {
  for existing in values {
    if existing.root == root {
      return
    }
  }
  values.push(SmtEufClassValue::{ root, value })
}

///|
fn smt_model_value_matches(
  lhs : @model.ModelValue,
  rhs : @model.ModelValue,
) -> Bool {
  lhs.sort() == rhs.sort() && lhs.to_text() == rhs.to_text()
}

///|
fn smt_model_push_unique_pending_dep(deps : Array[Int], index : Int) -> Unit {
  for existing in deps {
    if existing == index {
      return
    }
  }
  deps.push(index)
}

///|
fn smt_model_pending_index_for_decl(
  pending : Array[SmtEufValuePending],
  decl : @util.FuncDeclId,
) -> Int? {
  for i, item in pending {
    if item.term.decl == decl {
      return Some(i)
    }
  }
  None
}

///|
fn smt_model_collect_pending_deps(
  manager : @ast.AstManager,
  pending : Array[SmtEufValuePending],
  expr : @util.ExprId,
  deps : Array[Int],
) -> Unit {
  match manager.get_expr(expr).kind {
    BoolValue(_) | IntValue(_) => ()
    App(decl, args) => {
      if args.is_empty() {
        match smt_model_pending_index_for_decl(pending, decl) {
          Some(index) => smt_model_push_unique_pending_dep(deps, index)
          None => ()
        }
      }
      for arg in args {
        smt_model_collect_pending_deps(manager, pending, arg, deps)
      }
    }
    MacroRef(_) => ()
    Not(arg) => smt_model_collect_pending_deps(manager, pending, arg, deps)
    And(args) =>
      for arg in args {
        smt_model_collect_pending_deps(manager, pending, arg, deps)
      }
    Or(args) =>
      for arg in args {
        smt_model_collect_pending_deps(manager, pending, arg, deps)
      }
    Implies(lhs, rhs) => {
      smt_model_collect_pending_deps(manager, pending, lhs, deps)
      smt_model_collect_pending_deps(manager, pending, rhs, deps)
    }
    Xor(lhs, rhs) => {
      smt_model_collect_pending_deps(manager, pending, lhs, deps)
      smt_model_collect_pending_deps(manager, pending, rhs, deps)
    }
    Eq(lhs, rhs) => {
      smt_model_collect_pending_deps(manager, pending, lhs, deps)
      smt_model_collect_pending_deps(manager, pending, rhs, deps)
    }
    ArithCompare(_, lhs, rhs) => {
      smt_model_collect_pending_deps(manager, pending, lhs, deps)
      smt_model_collect_pending_deps(manager, pending, rhs, deps)
    }
    Distinct(args) =>
      for arg in args {
        smt_model_collect_pending_deps(manager, pending, arg, deps)
      }
  }
}

///|
fn smt_model_notify_theory_value_hooks(
  manager : @ast.AstManager,
  theories : Array[@theory_core.TheoryPlugin],
  graph : @egraph.EGraph,
  term : SmtEufValueTerm,
) -> SmtTheoryValueHookResult {
  let view = @theory_core.TheoryContextView::new(scope_depth=0)
  let actions = @theory_core.TheoryActions::noop()
  let mut value_expr : @util.ExprId? = None
  for attachment in graph.theory_attachments(term.enode) {
    let theory_id = attachment.theory_id()
    let theory_var = attachment.theory_var()
    let theory_term = @theory_core.TheoryTermRef::new(
      theory_id,
      theory_var.to_int(),
      scope_generation=0,
    )
    let mut owner_found = false
    for theory in theories {
      if theory.id() == theory_id {
        owner_found = true
        theory.model_add_dep(view, actions, theory_term, term.expr)
        match theory.mk_value(view, actions, theory_term) {
          Some(expr) =>
            if manager.expr_sort(expr) == term.sort {
              match value_expr {
                Some(existing) =>
                  if existing != expr {
                    return SmtTheoryValueFailed(
                      @util.ReasonUnknown::InvalidModel,
                    )
                  }
                None => value_expr = Some(expr)
              }
            } else {
              return SmtTheoryValueFailed(@util.ReasonUnknown::InvalidModel)
            }
          None => return SmtTheoryValueFailed(@util.ReasonUnknown::InvalidModel)
        }
      }
    }
    if !owner_found {
      return SmtTheoryValueFailed(@util.ReasonUnknown::InvalidModel)
    }
  }
  SmtTheoryValueReady(value_expr)
}

///|
fn smt_model_notify_theory_value_added(
  theories : Array[@theory_core.TheoryPlugin],
  graph : @egraph.EGraph,
  term : SmtEufValueTerm,
  value_expr : @util.ExprId,
) -> Unit {
  let view = @theory_core.TheoryContextView::new(scope_depth=0)
  let actions = @theory_core.TheoryActions::noop()
  for attachment in graph.theory_attachments(term.enode) {
    let theory_id = attachment.theory_id()
    let theory_var = attachment.theory_var()
    let theory_term = @theory_core.TheoryTermRef::new(
      theory_id,
      theory_var.to_int(),
      scope_generation=0,
    )
    for theory in theories {
      if theory.id() == theory_id {
        theory.model_add_value(view, actions, theory_term, value_expr)
      }
    }
  }
}

///|
fn smt_model_eval_arg_texts(
  model : @model.Model,
  manager : @ast.AstManager,
  args : Array[@util.ExprId],
) -> Array[String]? {
  let values : Array[String] = []
  for arg in args {
    match model.eval(manager, arg, completion=false) {
      Some(value) => values.push(value.to_text())
      None => return None
    }
  }
  Some(values)
}

///|
fn smt_model_find_func_model_index(
  functions : Array[SmtEufFuncModel],
  decl : @util.FuncDeclId,
) -> Int? {
  for i, entry in functions {
    if entry.decl == decl {
      return Some(i)
    }
  }
  None
}

///|
fn smt_model_add_func_entry(
  functions : Array[SmtEufFuncModel],
  term : SmtEufFuncTerm,
  args : Array[String],
  value : String,
) -> Unit {
  match smt_model_find_func_model_index(functions, term.decl) {
    Some(index) =>
      functions[index].entries.push(SmtEufFuncEntry::{ args, value })
    None =>
      functions.push(SmtEufFuncModel::{
        decl: term.decl,
        name: term.name,
        domain: term.domain,
        range: term.range,
        entries: [SmtEufFuncEntry::{ args, value }],
      })
  }
}

///|
fn SmtModelBuilder::install_euf_func_models(
  self : SmtModelBuilder,
  functions : Array[SmtEufFuncModel],
) -> Unit {
  for function in functions {
    let interp = @model.FuncInterp::new(
      function.name,
      function.domain,
      function.range,
    )
    for entry in function.entries {
      interp.add_entry(entry.args, entry.value)
    }
    self.model.add_func_interp(function.decl, interp)
  }
}

///|
fn SmtModelBuilder::euf_func_class_value(
  self : SmtModelBuilder,
  class_values : Array[SmtEufClassValue],
  root : @egraph.EnodeId,
  term : SmtEufFuncTerm,
) -> @model.ModelValue {
  match smt_model_class_value(class_values, root) {
    Some(value) => value
    None => {
      let value = self.model.fresh_uninterpreted_value(term.sort, term.range)
      smt_model_record_class_value(class_values, root, value)
      value
    }
  }
}

///|
fn SmtModelBuilder::mk_euf_func_interps(
  self : SmtModelBuilder,
  manager : @ast.AstManager,
  graph : @egraph.EGraph,
  theories : Array[@theory_core.TheoryPlugin],
  congruence : @egraph.EGraphCongruence,
  class_values : Array[SmtEufClassValue],
) -> Unit {
  let terms = smt_model_collect_euf_func_terms(manager, graph)
  let processed = [ for _ in terms => false ]
  let functions : Array[SmtEufFuncModel] = []
  let mut remaining = terms.length()
  let mut progress = true
  while remaining > 0 && progress {
    progress = false
    for i, term in terms {
      if !processed[i] {
        if smt_model_include_func_interp(theories, manager, term.decl) {
          match smt_model_eval_arg_texts(self.model, manager, term.args) {
            Some(args) => {
              let value = self.euf_func_class_value(
                class_values,
                congruence.find(term.enode),
                term,
              )
              smt_model_add_func_entry(functions, term, args, value.to_text())
              processed[i] = true
              remaining -= 1
              progress = true
              self.install_euf_func_models(functions)
            }
            None => ()
          }
        } else {
          processed[i] = true
          remaining -= 1
          progress = true
        }
      }
    }
  }
}

///|
fn SmtModelBuilder::add_euf_value_term(
  self : SmtModelBuilder,
  term : SmtEufValueTerm,
  value : @model.ModelValue,
) -> Unit {
  self.model.add_value_const(
    term.decl,
    term.sort,
    term.sort_name,
    value,
    name=term.name,
  )
}

///|
fn SmtModelBuilder::resolve_euf_value_pending(
  self : SmtModelBuilder,
  manager : @ast.AstManager,
  graph : @egraph.EGraph,
  theories : Array[@theory_core.TheoryPlugin],
  class_values : Array[SmtEufClassValue],
  pending : Array[SmtEufValuePending],
  index : Int,
) -> @util.ReasonUnknown? {
  match pending[index].state {
    SmtEufValuePendingDone => None
    SmtEufValuePendingResolving => Some(@util.ReasonUnknown::InvalidModel)
    SmtEufValuePendingOpen => {
      pending[index].state = SmtEufValuePendingResolving
      let item = pending[index]
      let deps : Array[Int] = []
      smt_model_collect_pending_deps(manager, pending, item.value_expr, deps)
      for dep_index in deps {
        if dep_index != index {
          match
            self.resolve_euf_value_pending(
              manager, graph, theories, class_values, pending, dep_index,
            ) {
            Some(reason) => return Some(reason)
            None => ()
          }
        }
      }
      match smt_model_class_value(class_values, item.root) {
        Some(value) => {
          if item.value_expr != item.term.expr {
            match self.model.eval(manager, item.value_expr, completion=true) {
              Some(expr_value) =>
                if !smt_model_value_matches(expr_value, value) {
                  return Some(@util.ReasonUnknown::InvalidModel)
                }
              None => return Some(@util.ReasonUnknown::InvalidModel)
            }
          }
          self.add_euf_value_term(item.term, value)
          smt_model_notify_theory_value_added(
            theories,
            graph,
            item.term,
            item.value_expr,
          )
          pending[index].state = SmtEufValuePendingDone
          None
        }
        None =>
          match self.model.eval(manager, item.value_expr, completion=true) {
            Some(value) => {
              smt_model_record_class_value(class_values, item.root, value)
              self.add_euf_value_term(item.term, value)
              smt_model_notify_theory_value_added(
                theories,
                graph,
                item.term,
                item.value_expr,
              )
              pending[index].state = SmtEufValuePendingDone
              None
            }
            None => Some(@util.ReasonUnknown::InvalidModel)
          }
      }
    }
  }
}

///|
fn SmtModelBuilder::mk_euf_value_deps(
  self : SmtModelBuilder,
  manager : @ast.AstManager,
  graph : @egraph.EGraph,
  theories : Array[@theory_core.TheoryPlugin],
) -> @util.ReasonUnknown? {
  let terms = smt_model_collect_euf_value_terms(manager, graph)
  let congruence = smt_model_congruence_from_egraph(graph)
  let class_values : Array[SmtEufClassValue] = []
  let pending : Array[SmtEufValuePending] = []
  for term in terms {
    let value_expr = match
      smt_model_notify_theory_value_hooks(manager, theories, graph, term) {
      SmtTheoryValueFailed(reason) => return Some(reason)
      SmtTheoryValueReady(value_expr) => value_expr
    }
    let root = congruence.find(term.enode)
    let selected_value_expr = match value_expr {
      Some(expr) => expr
      None => term.expr
    }
    pending.push(SmtEufValuePending::{
      term,
      root,
      value_expr: selected_value_expr,
      state: SmtEufValuePendingOpen,
    })
  }
  for i in 0..<pending.length() {
    match
      self.resolve_euf_value_pending(
        manager, graph, theories, class_values, pending, i,
      ) {
      Some(reason) => return Some(reason)
      None => ()
    }
  }
  self.mk_euf_func_interps(manager, graph, theories, congruence, class_values)
  None
}

///|
fn SmtModelBuilder::finalize_model(self : SmtModelBuilder) -> @model.Model {
  self.model
}
