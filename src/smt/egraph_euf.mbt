///|
enum EGraphAssertionRoute {
  EGraphAssertBool
  EGraphAssertEuf
  EGraphAssertUnsupported(String)
} derive(Eq)

///|
enum EGraphEufCheckResult {
  EGraphEufConsistent
  EGraphEufConflict
  EGraphEufUnknown(@util.ReasonUnknown)
} derive(Eq)

///|
priv struct EGraphEufSearch {
  manager : @ast.AstManager
  internalizer : SmtInternalizer
  graph : @egraph.EGraph
  congruence : @egraph.EGraphCongruence
}

///|
fn EGraphEufSearch::new(
  manager : @ast.AstManager,
  internalizer : SmtInternalizer,
  graph : @egraph.EGraph,
) -> EGraphEufSearch {
  { manager, internalizer, graph, congruence: @egraph.EGraphCongruence::new() }
}

///|
fn egraph_euf_same_sort(
  manager : @ast.AstManager,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  if manager.expr_sort(lhs) != manager.expr_sort(rhs) {
    raise @type_error.TypeError("EUF terms have different sorts", None)
  }
}

///|
fn egraph_euf_expect_term(
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  if manager.expr_sort(expr) == manager.bool_sort() {
    raise @type_error.TypeError("expected non-Bool EUF term", None)
  }
}

///|
fn EGraphEufSearch::remember_term(
  self : EGraphEufSearch,
  id : @egraph.EnodeId,
) -> Unit {
  self.congruence.add_term(id)
}

///|
fn EGraphEufSearch::materialize_term(
  self : EGraphEufSearch,
  expr : @util.ExprId,
) -> @egraph.EnodeId raise @type_error.TypeError {
  let expanded = self.manager.expand_macros(expr).result()
  egraph_euf_expect_term(self.manager, expanded)
  match self.manager.get_expr(expanded).kind {
    App(_, args) => {
      for arg in args {
        ignore(self.materialize_term(arg))
      }
      let id = self.internalizer.mk_enode(expanded)
      self.remember_term(id)
      id
    }
    _ => raise @type_error.TypeError("expected uninterpreted term", None)
  }
}

///|
fn EGraphEufSearch::close(self : EGraphEufSearch) -> Unit {
  self.congruence.close(self.graph)
}

///|
fn EGraphEufSearch::has_conflict(self : EGraphEufSearch) -> Bool {
  self.congruence.has_conflict()
}

///|
fn EGraphEufSearch::assert_equal(
  self : EGraphEufSearch,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  egraph_euf_same_sort(self.manager, lhs, rhs)
  let lhs_node = self.materialize_term(lhs)
  let rhs_node = self.materialize_term(rhs)
  ignore(self.congruence.merge(lhs_node, rhs_node))
  self.close()
}

///|
fn EGraphEufSearch::assert_disequal(
  self : EGraphEufSearch,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  egraph_euf_same_sort(self.manager, lhs, rhs)
  let lhs_node = self.materialize_term(lhs)
  let rhs_node = self.materialize_term(rhs)
  self.congruence.assert_disequal(lhs_node, rhs_node)
  self.close()
}

///|
fn egraph_euf_route_bool_arg(
  manager : @ast.AstManager,
  arg : @util.ExprId,
) -> Bool {
  manager.expr_sort(arg) == manager.bool_sort()
}

///|
fn smt_euf_assertion_route(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  polarity : Bool,
) -> EGraphAssertionRoute {
  let expanded = manager.expand_macros(expr) catch {
    err => return EGraphAssertUnsupported(err.to_string())
  }
  let expr = expanded.result()
  match manager.get_expr(expr).kind {
    MacroRef(_) => EGraphAssertUnsupported("unexpanded macro in EUF route")
    Not(inner) => smt_euf_assertion_route(manager, inner, !polarity)
    And(args) =>
      if polarity {
        let mut any_euf = false
        let mut any_bool = false
        for arg in args {
          match smt_euf_assertion_route(manager, arg, true) {
            EGraphAssertEuf => {
              if any_bool {
                return EGraphAssertUnsupported("mixed Bool/EUF conjunction")
              }
              any_euf = true
            }
            EGraphAssertBool => {
              if any_euf {
                return EGraphAssertUnsupported("mixed Bool/EUF conjunction")
              }
              any_bool = true
            }
            EGraphAssertUnsupported(reason) =>
              return EGraphAssertUnsupported(reason)
          }
        }
        if any_euf {
          EGraphAssertEuf
        } else {
          EGraphAssertBool
        }
      } else {
        EGraphAssertBool
      }
    Eq(lhs, rhs) =>
      if egraph_euf_route_bool_arg(manager, lhs) ||
        egraph_euf_route_bool_arg(manager, rhs) {
        EGraphAssertBool
      } else {
        EGraphAssertEuf
      }
    Distinct(args) =>
      if args.is_empty() || egraph_euf_route_bool_arg(manager, args[0]) {
        EGraphAssertBool
      } else if !polarity && args.length() != 2 {
        EGraphAssertUnsupported("negated n-ary distinct")
      } else {
        EGraphAssertEuf
      }
    ArithCompare(_, _, _) =>
      EGraphAssertUnsupported("arith comparison requires theory")
    IntValue(_) => EGraphAssertUnsupported("Int value is not a Bool assertion")
    BoolValue(_) | App(_, _) | Or(_) | Implies(_, _) | Xor(_, _) =>
      EGraphAssertBool
  }
}

///|
fn EGraphEufSearch::assert_formula(
  self : EGraphEufSearch,
  expr : @util.ExprId,
  polarity : Bool,
) -> Unit raise @type_error.TypeError {
  let expanded = self.manager.expand_macros(expr).result()
  match self.manager.get_expr(expanded).kind {
    MacroRef(_) =>
      raise @type_error.TypeError("unexpanded macro in EUF assertion", None)
    Not(inner) => self.assert_formula(inner, !polarity)
    And(args) =>
      if polarity {
        for arg in args {
          self.assert_formula(arg, true)
        }
      } else {
        raise @type_error.TypeError("negated EUF conjunction", None)
      }
    Eq(lhs, rhs) =>
      if self.manager.expr_sort(lhs) == self.manager.bool_sort() {
        ()
      } else if polarity {
        self.assert_equal(lhs, rhs)
      } else {
        self.assert_disequal(lhs, rhs)
      }
    Distinct(args) =>
      if args.length() == 0 ||
        self.manager.expr_sort(args[0]) == self.manager.bool_sort() {
        ()
      } else if polarity {
        for i in 0..<args.length() {
          for j in (i + 1)..<args.length() {
            self.assert_disequal(args[i], args[j])
          }
        }
      } else if args.length() == 2 {
        self.assert_equal(args[0], args[1])
      } else {
        raise @type_error.TypeError("negated n-ary distinct", None)
      }
    IntValue(_) | ArithCompare(_, _, _) =>
      raise @type_error.TypeError("unsupported arithmetic EUF assertion", None)
    BoolValue(_) | App(_, _) | Or(_) | Implies(_, _) | Xor(_, _) => ()
  }
}

///|
fn smt_euf_enqueue_assertion_facts(
  manager : @ast.AstManager,
  internalizer : SmtInternalizer,
  graph : @egraph.EGraph,
  expr : @util.ExprId,
  polarity : Bool,
) -> Unit raise @type_error.TypeError {
  let expanded = manager.expand_macros(expr).result()
  match manager.get_expr(expanded).kind {
    MacroRef(_) =>
      raise @type_error.TypeError("unexpanded macro in EUF assertion", None)
    Not(inner) =>
      smt_euf_enqueue_assertion_facts(
        manager,
        internalizer,
        graph,
        inner,
        !polarity,
      )
    And(args) =>
      if polarity {
        for arg in args {
          smt_euf_enqueue_assertion_facts(
            manager, internalizer, graph, arg, true,
          )
        }
      } else {
        raise @type_error.TypeError("negated EUF conjunction", None)
      }
    Eq(lhs, rhs) =>
      if manager.expr_sort(lhs) != manager.bool_sort() {
        if polarity {
          graph.enqueue_new_eq(
            internalizer.mk_enode(lhs),
            internalizer.mk_enode(rhs),
          )
        } else {
          graph.enqueue_new_diseq(internalizer.mk_enode(expanded))
        }
      }
    Distinct(args) =>
      if args.length() > 0 && manager.expr_sort(args[0]) != manager.bool_sort() {
        if polarity {
          graph.enqueue_new_diseq(internalizer.mk_enode(expanded))
        } else if args.length() == 2 {
          graph.enqueue_new_eq(
            internalizer.mk_enode(args[0]),
            internalizer.mk_enode(args[1]),
          )
        } else {
          raise @type_error.TypeError("negated n-ary distinct", None)
        }
      }
    IntValue(_) | ArithCompare(_, _, _) =>
      raise @type_error.TypeError("unsupported arithmetic EUF assertion", None)
    BoolValue(_) | App(_, _) | Or(_) | Implies(_, _) | Xor(_, _) => ()
  }
}

///|
fn smt_euf_check_assertions(
  manager : @ast.AstManager,
  internalizer : SmtInternalizer,
  graph : @egraph.EGraph,
  assertions : Array[@util.ExprId],
) -> EGraphEufCheckResult {
  let search = EGraphEufSearch::new(manager, internalizer, graph)
  for assertion in assertions {
    match smt_euf_assertion_route(manager, assertion, true) {
      EGraphAssertEuf => {
        search.assert_formula(assertion, true) catch {
          err =>
            return EGraphEufUnknown(
              @util.ReasonUnknown::unsupported_fragment(err.to_string()),
            )
        }
        if search.has_conflict() {
          return EGraphEufConflict
        }
      }
      EGraphAssertBool => ()
      EGraphAssertUnsupported(reason) =>
        return EGraphEufUnknown(
          @util.ReasonUnknown::unsupported_fragment(reason),
        )
    }
  }
  EGraphEufConsistent
}
