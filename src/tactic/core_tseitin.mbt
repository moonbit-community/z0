///|
priv struct TseitinCnfEncoder {
  manager : @ast.AstManager
  clauses : Array[@util.ExprId]
  aux_names : Array[String]
  mut next_id : Int
}

///|
fn tseitin_unavailable(message : String) -> @util.Availability[TacticResult] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment("tseitin-cnf:\{message}"),
    ),
  )
}

///|
fn TseitinCnfEncoder::new(manager : @ast.AstManager) -> TseitinCnfEncoder {
  { manager, clauses: [], aux_names: [], next_id: 0 }
}

///|
fn TseitinCnfEncoder::fresh_aux(self : TseitinCnfEncoder) -> @util.ExprId raise {
  while true {
    let name = "tseitin!\{self.next_id}"
    self.next_id += 1
    if self.manager.lookup_decl(name) is None &&
      self.manager.lookup_macro(name) is None {
      let decl = self.manager.declare_const(name, self.manager.bool_sort())
      self.aux_names.push(name)
      return self.manager.mk_app(decl, [])
    }
  }
  self.manager.mk_bool(false)
}

///|
fn TseitinCnfEncoder::append_aux_model_converter(
  self : TseitinCnfEncoder,
  goal : Goal,
) -> Unit {
  if !self.aux_names.is_empty() {
    let converter = @converters.GenericModelConverter::new()
    for name in self.aux_names {
      converter.hide(name)
    }
    goal.append_model_converter(converter.as_model_converter())
  }
}

///|
fn TseitinCnfEncoder::append_aux_proof_and_dependency_metadata(
  self : TseitinCnfEncoder,
  goal : Goal,
) -> Unit {
  if !self.aux_names.is_empty() {
    let converter = @converters.GenericProofConverter::new()
    for name in self.aux_names {
      let label = "tseitin-aux:\{name}"
      converter.add_label(label)
      goal.dependency_converter().add_label(label)
    }
    goal.append_proof_converter(converter.as_proof_converter())
  }
}

///|
fn TseitinCnfEncoder::append_aux_metadata(
  self : TseitinCnfEncoder,
  goal : Goal,
) -> Unit {
  self.append_aux_model_converter(goal)
  self.append_aux_proof_and_dependency_metadata(goal)
}

///|
fn tseitin_is_atom(manager : @ast.AstManager, expr : @util.ExprId) -> Bool {
  match manager.get_expr(expr).kind {
    BoolValue(_)
    | App(_, _)
    | MacroRef(_)
    | Eq(_, _)
    | Distinct(_)
    | ArithCompare(_, _, _) => true
    _ => false
  }
}

///|
fn TseitinCnfEncoder::negate(
  self : TseitinCnfEncoder,
  expr : @util.ExprId,
) -> @util.ExprId raise {
  match self.manager.get_expr(expr).kind {
    BoolValue(value) => self.manager.mk_bool(!value)
    Not(inner) => inner
    _ => self.manager.mk_not(expr)
  }
}

///|
fn TseitinCnfEncoder::add_clause(
  self : TseitinCnfEncoder,
  literals : Array[@util.ExprId],
) -> Unit raise {
  match literals.length() {
    0 => self.clauses.push(self.manager.mk_bool(false))
    1 => self.clauses.push(literals[0])
    _ => self.clauses.push(self.manager.mk_or(literals))
  }
}

///|
fn TseitinCnfEncoder::encode_args(
  self : TseitinCnfEncoder,
  args : Array[@util.ExprId],
) -> Array[@util.ExprId] raise {
  let literals : Array[@util.ExprId] = []
  for arg in args {
    literals.push(self.encode(arg))
  }
  literals
}

///|
fn TseitinCnfEncoder::encode_and(
  self : TseitinCnfEncoder,
  args : Array[@util.ExprId],
) -> @util.ExprId raise {
  let literals = self.encode_args(args)
  let aux = self.fresh_aux()
  let not_aux = self.negate(aux)
  for literal in literals {
    self.add_clause([not_aux, literal])
  }
  let reverse_clause = [aux]
  for literal in literals {
    reverse_clause.push(self.negate(literal))
  }
  self.add_clause(reverse_clause)
  aux
}

///|
fn TseitinCnfEncoder::encode_or(
  self : TseitinCnfEncoder,
  args : Array[@util.ExprId],
) -> @util.ExprId raise {
  let literals = self.encode_args(args)
  let aux = self.fresh_aux()
  let forward_clause = [self.negate(aux)]
  for literal in literals {
    forward_clause.push(literal)
  }
  self.add_clause(forward_clause)
  for literal in literals {
    self.add_clause([aux, self.negate(literal)])
  }
  aux
}

///|
fn TseitinCnfEncoder::encode(
  self : TseitinCnfEncoder,
  expr : @util.ExprId,
) -> @util.ExprId raise {
  match self.manager.get_expr(expr).kind {
    BoolValue(_)
    | IntValue(_)
    | App(_, _)
    | MacroRef(_)
    | Eq(_, _)
    | Distinct(_)
    | ArithCompare(_, _, _) => expr
    Not(inner) =>
      match self.manager.get_expr(inner).kind {
        Not(grandchild) => self.encode(grandchild)
        _ =>
          if tseitin_is_atom(self.manager, inner) {
            expr
          } else {
            self.negate(self.encode(inner))
          }
      }
    And(args) => self.encode_and(args)
    Or(args) => self.encode_or(args)
    Implies(lhs, rhs) =>
      self.encode(self.manager.mk_or([self.manager.mk_not(lhs), rhs]))
    Xor(lhs, rhs) =>
      self.encode(
        self.manager.mk_or([
          self.manager.mk_and([lhs, self.manager.mk_not(rhs)]),
          self.manager.mk_and([self.manager.mk_not(lhs), rhs]),
        ]),
      )
  }
}

///|
pub fn Tactic::tseitin_cnf() -> Tactic {
  Tactic::new("tseitin-cnf", fn(goal) {
    let cnf_goal = goal.simplified_copy()
    let encoder = TseitinCnfEncoder::new(goal.manager)
    for formula in goal.formulas {
      let rewritten = @rewriter.rewrite_bool(goal.manager, formula) catch {
        err => return tseitin_unavailable(err.to_string())
      }
      match bool_value(goal.manager, rewritten) {
        Some(true) => ()
        Some(false) => {
          cnf_goal.add(rewritten)
          encoder.append_aux_metadata(cnf_goal)
          return @util.Available(TacticResult::from_goals([cnf_goal]))
        }
        None => {
          let root = encoder.encode(rewritten) catch {
            err => return tseitin_unavailable(err.to_string())
          }
          for clause in encoder.clauses {
            cnf_goal.add(clause)
          }
          encoder.clauses.truncate(0)
          cnf_goal.add(root)
        }
      }
    }
    encoder.append_aux_metadata(cnf_goal)
    @util.Available(TacticResult::from_goals([cnf_goal]))
  })
}
