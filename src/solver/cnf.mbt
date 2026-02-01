///|
priv struct CnfBuilder {
  mut next_var : Int
  clauses : Array[Array[Lit]]
  term_var : Map[Term, Int]
  atom_terms : Map[Int, Term]
}

///|
fn CnfBuilder::new() -> CnfBuilder {
  { next_var: 0, clauses: [], term_var: Map::new(), atom_terms: Map::new() }
}

///|
fn CnfBuilder::new_var(self : CnfBuilder) -> Int {
  let v = self.next_var
  self.next_var = self.next_var + 1
  v
}

///|
fn CnfBuilder::get_var(self : CnfBuilder, term : Term) -> Int {
  match self.term_var.get(term) {
    Some(v) => v
    None => {
      let v = self.new_var()
      self.term_var[term] = v
      v
    }
  }
}

///|
fn CnfBuilder::add_clause(self : CnfBuilder, clause : Array[Lit]) -> Unit {
  self.clauses.push(clause)
}

///|
fn is_theory_atom(term : Term) -> Bool {
  match term {
    Term::Builtin(op, args, _) =>
      match op {
        BuiltinOp::Eq =>
          if args.length() >= 2 {
            args[0].sort() != Sort::Bool
          } else {
            true
          }
        BuiltinOp::Distinct =>
          if args.length() >= 2 {
            args[0].sort() != Sort::Bool
          } else {
            true
          }
        BuiltinOp::Lt => true
        BuiltinOp::Le => true
        BuiltinOp::Gt => true
        BuiltinOp::Ge => true
        _ => false
      }
    _ => false
  }
}

///|
fn is_bool_atom(term : Term) -> Bool {
  match term {
    Term::Var(_, sort) => sort == Sort::Bool
    Term::App(decl, _) => decl.range == Sort::Bool
    Term::Quantifier(_, _, _) => true
    _ => false
  }
}

///|
fn encode_term(b : CnfBuilder, term : Term) -> Lit {
  match term {
    Term::BoolVal(value) => {
      let v = b.get_var(term)
      let lit = if value { @sat.lit_pos(v) } else { @sat.lit_neg(v) }
      b.add_clause([lit])
      @sat.lit_pos(v)
    }
    _ => {
      if is_theory_atom(term) || is_bool_atom(term) {
        let v = b.get_var(term)
        if is_theory_atom(term) {
          b.atom_terms[v] = term
        }
        return @sat.lit_pos(v)
      }
      match term {
        Term::Builtin(BuiltinOp::Eq, args, _) => {
          let a = encode_term(b, args[0])
          let c = encode_term(b, args[1])
          let v = b.get_var(term)
          let v_lit = @sat.lit_pos(v)
          b.add_clause([v_lit.not(), a.not(), c])
          b.add_clause([v_lit.not(), a, c.not()])
          b.add_clause([v_lit, a, c])
          b.add_clause([v_lit, a.not(), c.not()])
          v_lit
        }
        Term::Builtin(BuiltinOp::Distinct, args, _) => {
          let a = encode_term(b, args[0])
          let c = encode_term(b, args[1])
          let v = b.get_var(term)
          let v_lit = @sat.lit_pos(v)
          b.add_clause([v_lit.not(), a.not(), c.not()])
          b.add_clause([v_lit.not(), a, c])
          b.add_clause([v_lit, a.not(), c])
          b.add_clause([v_lit, a, c.not()])
          v_lit
        }
        Term::Builtin(BuiltinOp::Not, args, _) => {
          let arg = encode_term(b, args[0])
          let v = b.get_var(term)
          let v_lit = @sat.lit_pos(v)
          b.add_clause([v_lit.not(), arg.not()])
          b.add_clause([v_lit, arg])
          v_lit
        }
        Term::Builtin(BuiltinOp::And, args, _) => {
          if args.length() == 0 {
            return encode_term(b, Term::BoolVal(true))
          }
          if args.length() == 1 {
            return encode_term(b, args[0])
          }
          let v = b.get_var(term)
          let v_lit = @sat.lit_pos(v)
          let neg_args : Array[Lit] = [v_lit]
          for arg in args {
            let lit = encode_term(b, arg)
            b.add_clause([v_lit.not(), lit])
            neg_args.push(lit.not())
          }
          b.add_clause(neg_args)
          v_lit
        }
        Term::Builtin(BuiltinOp::Or, args, _) => {
          if args.length() == 0 {
            return encode_term(b, Term::BoolVal(false))
          }
          if args.length() == 1 {
            return encode_term(b, args[0])
          }
          let v = b.get_var(term)
          let v_lit = @sat.lit_pos(v)
          let pos_args : Array[Lit] = [v_lit.not()]
          for arg in args {
            let lit = encode_term(b, arg)
            b.add_clause([v_lit, lit.not()])
            pos_args.push(lit)
          }
          b.add_clause(pos_args)
          v_lit
        }
        Term::Builtin(BuiltinOp::Implies, args, _) => {
          let a = encode_term(b, args[0])
          let c = encode_term(b, args[1])
          let v = b.get_var(term)
          let v_lit = @sat.lit_pos(v)
          b.add_clause([v_lit.not(), a.not(), c])
          b.add_clause([v_lit, a])
          b.add_clause([v_lit, c.not()])
          v_lit
        }
        Term::Builtin(BuiltinOp::Iff, args, _) => {
          let a = encode_term(b, args[0])
          let c = encode_term(b, args[1])
          let v = b.get_var(term)
          let v_lit = @sat.lit_pos(v)
          b.add_clause([v_lit.not(), a.not(), c])
          b.add_clause([v_lit.not(), a, c.not()])
          b.add_clause([v_lit, a, c])
          b.add_clause([v_lit, a.not(), c.not()])
          v_lit
        }
        Term::Builtin(BuiltinOp::Xor, args, _) => {
          let a = encode_term(b, args[0])
          let c = encode_term(b, args[1])
          let v = b.get_var(term)
          let v_lit = @sat.lit_pos(v)
          b.add_clause([v_lit.not(), a.not(), c.not()])
          b.add_clause([v_lit.not(), a, c])
          b.add_clause([v_lit, a.not(), c])
          b.add_clause([v_lit, a, c.not()])
          v_lit
        }
        Term::Builtin(BuiltinOp::Ite, args, _) => {
          let c = encode_term(b, args[0])
          let t = encode_term(b, args[1])
          let e = encode_term(b, args[2])
          let v = b.get_var(term)
          let v_lit = @sat.lit_pos(v)
          b.add_clause([c.not(), t.not(), v_lit])
          b.add_clause([c.not(), t, v_lit.not()])
          b.add_clause([c, e.not(), v_lit])
          b.add_clause([c, e, v_lit.not()])
          v_lit
        }
        _ => {
          // Non-boolean terms are unsupported at this level.
          let v = b.get_var(term)
          @sat.lit_pos(v)
        }
      }
    }
  }
}

///|
fn subst_term(
  term : Term,
  subst : Map[String, Term],
  bound : Map[String, Bool],
) -> Term {
  match term {
    Term::Var(name, sort) =>
      if bound.contains(name) {
        Term::Var(name, sort)
      } else {
        match subst.get(name) {
          Some(value) => value
          None => Term::Var(name, sort)
        }
      }
    Term::App(decl, args) => {
      let new_args = args.map(arg => subst_term(arg, subst, bound))
      Term::App(decl, new_args)
    }
    Term::Builtin(op, args, sort) => {
      let new_args = args.map(arg => subst_term(arg, subst, bound))
      Term::Builtin(op, new_args, sort)
    }
    Term::Let(bindings, body) => {
      let new_bindings : Array[(String, Term)] = []
      for binding in bindings {
        let (name, value) = binding
        new_bindings.push((name, subst_term(value, subst, bound)))
      }
      let bound2 = bound.copy()
      for binding in bindings {
        let (name, _) = binding
        bound2[name] = true
      }
      let new_body = subst_term(body, subst, bound2)
      Term::Let(new_bindings, new_body)
    }
    Term::Quantifier(kind, vars, body) => {
      let bound2 = bound.copy()
      for bound in vars {
        bound2[bound.name] = true
      }
      let new_body = subst_term(body, subst, bound2)
      Term::Quantifier(kind, vars, new_body)
    }
    _ => term
  }
}

///|
fn elim_let(term : Term) -> Term {
  match term {
    Term::Let(bindings, body) => {
      let subst : Map[String, Term] = Map::new()
      for binding in bindings {
        let (name, value) = binding
        subst[name] = elim_let(value)
      }
      let body2 = subst_term(body, subst, Map::new())
      elim_let(body2)
    }
    Term::App(decl, args) => {
      let new_args = args.map(elim_let)
      Term::App(decl, new_args)
    }
    Term::Builtin(op, args, sort) => {
      let new_args = args.map(elim_let)
      Term::Builtin(op, new_args, sort)
    }
    Term::Quantifier(kind, vars, body) => {
      let new_body = elim_let(body)
      Term::Quantifier(kind, vars, new_body)
    }
    _ => term
  }
}

///|
fn term_has_free_var(
  term : Term,
  name : String,
  bound : Map[String, Bool],
) -> Bool {
  match term {
    Term::Var(var_name, _) => var_name == name && !bound.contains(var_name)
    Term::App(_, args) => {
      for arg in args {
        if term_has_free_var(arg, name, bound) {
          return true
        }
      }
      false
    }
    Term::Builtin(_, args, _) => {
      for arg in args {
        if term_has_free_var(arg, name, bound) {
          return true
        }
      }
      false
    }
    Term::Let(bindings, body) => {
      for binding in bindings {
        let (_, value) = binding
        if term_has_free_var(value, name, bound) {
          return true
        }
      }
      let bound2 = bound.copy()
      for binding in bindings {
        let (binding_name, _) = binding
        bound2[binding_name] = true
      }
      term_has_free_var(body, name, bound2)
    }
    Term::Quantifier(_, vars, body) => {
      let bound2 = bound.copy()
      for bound_var in vars {
        bound2[bound_var.name] = true
      }
      term_has_free_var(body, name, bound2)
    }
    _ => false
  }
}

///|
fn term_uses_var(term : Term, name : String) -> Bool {
  term_has_free_var(term, name, Map::new())
}

///|
fn antecedent_implies(antecedent : Term, consequent : Term) -> Bool {
  if antecedent == consequent {
    return true
  }
  match antecedent {
    Term::Builtin(BuiltinOp::And, args, _) => {
      for arg in args {
        if antecedent_implies(arg, consequent) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn flatten_implies(term : Term) -> (Array[Term], Term) {
  match term {
    Term::Builtin(BuiltinOp::Implies, args, _) =>
      if args.length() == 2 {
        let (rest, consequent) = flatten_implies(args[1])
        let out : Array[Term] = [args[0]]
        for item in rest {
          out.push(item)
        }
        (out, consequent)
      } else {
        ([], term)
      }
    _ => ([], term)
  }
}

///|
fn forall_inequality_unsat(vars : Array[BoundVar], body : Term) -> Bool {
  match body {
    Term::Builtin(op, args, _) =>
      match op {
        BuiltinOp::Le | BuiltinOp::Ge =>
          if args.length() == 2 {
            let lhs_expr = lin_of_term(args[0])
            let rhs_expr = lin_of_term(args[1])
            match (lhs_expr, rhs_expr) {
              (Some(lhs), Some(rhs)) => {
                let diff = if op == BuiltinOp::Le {
                  lin_sub(lhs, rhs)
                } else {
                  lin_sub(rhs, lhs)
                }
                for bound_var in vars {
                  match bound_var.sort {
                    Sort::Int | Sort::Real =>
                      if !rat_is_zero(lin_coeff(diff, bound_var.name)) {
                        return true
                      }
                    _ => ()
                  }
                }
                false
              }
              _ => false
            }
          } else {
            false
          }
        _ => false
      }
    _ => false
  }
}

///|
fn simplify_quantifier_term(
  kind : QuantifierKind,
  vars : Array[BoundVar],
  body : Term,
) -> Term {
  let body_s = simplify_term(body)
  let kept : Array[BoundVar] = []
  for bound_var in vars {
    if term_uses_var(body_s, bound_var.name) {
      kept.push(bound_var)
    }
  }
  if kept.length() == 0 {
    return body_s
  }
  match body_s {
    Term::BoolVal(_) => return body_s
    _ => ()
  }
  let term = Term::Quantifier(kind, kept, body_s)
  if quantifier_unsat(term) {
    return Term::BoolVal(false)
  }
  if kind == QuantifierKind::Forall && forall_inequality_unsat(kept, body_s) {
    return Term::BoolVal(false)
  }
  term
}

///|
fn simplify_term(term : Term) -> Term {
  match term {
    Term::App(decl, args) => {
      let new_args = args.map(simplify_term)
      Term::App(decl, new_args)
    }
    Term::Builtin(op, args, sort) => {
      let new_args = args.map(simplify_term)
      match op {
        BuiltinOp::Not =>
          if new_args.length() == 1 {
            match new_args[0] {
              Term::BoolVal(value) => Term::BoolVal(!value)
              Term::Builtin(BuiltinOp::Not, inner, _) =>
                if inner.length() == 1 {
                  inner[0]
                } else {
                  Term::Builtin(op, new_args, sort)
                }
              _ => Term::Builtin(op, new_args, sort)
            }
          } else {
            Term::Builtin(op, new_args, sort)
          }
        BuiltinOp::And => {
          let flat : Array[Term] = []
          for arg in new_args {
            match arg {
              Term::BoolVal(false) => return Term::BoolVal(false)
              Term::BoolVal(true) => ()
              Term::Builtin(BuiltinOp::And, inner, _) =>
                for item in inner {
                  flat.push(item)
                }
              _ => flat.push(arg)
            }
          }
          if flat.length() == 0 {
            Term::BoolVal(true)
          } else if flat.length() == 1 {
            flat[0]
          } else {
            Term::Builtin(op, flat, sort)
          }
        }
        BuiltinOp::Or => {
          let flat : Array[Term] = []
          for arg in new_args {
            match arg {
              Term::BoolVal(true) => return Term::BoolVal(true)
              Term::BoolVal(false) => ()
              Term::Builtin(BuiltinOp::Or, inner, _) =>
                for item in inner {
                  flat.push(item)
                }
              _ => flat.push(arg)
            }
          }
          if flat.length() == 0 {
            Term::BoolVal(false)
          } else if flat.length() == 1 {
            flat[0]
          } else {
            Term::Builtin(op, flat, sort)
          }
        }
        BuiltinOp::Implies =>
          if new_args.length() == 2 {
            let lhs = new_args[0]
            let rhs = new_args[1]
            match (lhs, rhs) {
              (Term::BoolVal(false), _) => Term::BoolVal(true)
              (Term::BoolVal(true), _) => rhs
              (_, Term::BoolVal(true)) => Term::BoolVal(true)
              (_, Term::BoolVal(false)) =>
                simplify_term(Term::Builtin(BuiltinOp::Not, [lhs], Sort::Bool))
              _ => {
                let (ants, cons) = flatten_implies(
                  Term::Builtin(BuiltinOp::Implies, [lhs, rhs], Sort::Bool),
                )
                for ant in ants {
                  if antecedent_implies(ant, cons) {
                    return Term::BoolVal(true)
                  }
                }
                Term::Builtin(op, [lhs, rhs], sort)
              }
            }
          } else {
            Term::Builtin(op, new_args, sort)
          }
        BuiltinOp::Iff =>
          if new_args.length() == 2 {
            let lhs = new_args[0]
            let rhs = new_args[1]
            if lhs == rhs {
              Term::BoolVal(true)
            } else {
              match (lhs, rhs) {
                (Term::BoolVal(true), _) => rhs
                (Term::BoolVal(false), _) =>
                  simplify_term(
                    Term::Builtin(BuiltinOp::Not, [rhs], Sort::Bool),
                  )
                (_, Term::BoolVal(true)) => lhs
                (_, Term::BoolVal(false)) =>
                  simplify_term(
                    Term::Builtin(BuiltinOp::Not, [lhs], Sort::Bool),
                  )
                _ => Term::Builtin(op, [lhs, rhs], sort)
              }
            }
          } else {
            Term::Builtin(op, new_args, sort)
          }
        BuiltinOp::Xor =>
          if new_args.length() == 2 {
            let lhs = new_args[0]
            let rhs = new_args[1]
            match (lhs, rhs) {
              (Term::BoolVal(l), Term::BoolVal(r)) => Term::BoolVal(l != r)
              (Term::BoolVal(false), _) => rhs
              (Term::BoolVal(true), _) =>
                simplify_term(Term::Builtin(BuiltinOp::Not, [rhs], Sort::Bool))
              (_, Term::BoolVal(false)) => lhs
              (_, Term::BoolVal(true)) =>
                simplify_term(Term::Builtin(BuiltinOp::Not, [lhs], Sort::Bool))
              _ => Term::Builtin(op, [lhs, rhs], sort)
            }
          } else {
            Term::Builtin(op, new_args, sort)
          }
        BuiltinOp::Ite =>
          if new_args.length() == 3 {
            let cond = new_args[0]
            let then_t = new_args[1]
            let else_t = new_args[2]
            match cond {
              Term::BoolVal(true) => then_t
              Term::BoolVal(false) => else_t
              _ =>
                if then_t == else_t {
                  then_t
                } else {
                  Term::Builtin(op, [cond, then_t, else_t], sort)
                }
            }
          } else {
            Term::Builtin(op, new_args, sort)
          }
        _ => Term::Builtin(op, new_args, sort)
      }
    }
    Term::Quantifier(kind, vars, body) =>
      simplify_quantifier_term(kind, vars, body)
    _ => term
  }
}

///|
priv enum BoundKind {
  Lower
  Upper
}

///|
priv struct Bound {
  kind : BoundKind
  expr : LinExpr
}

///|
fn collect_conjuncts(term : Term, out : Array[Term]) -> Unit {
  match term {
    Term::Builtin(BuiltinOp::And, args, _) =>
      for arg in args {
        collect_conjuncts(arg, out)
      }
    _ => out.push(term)
  }
}

///|
fn flatten_and(term : Term) -> Array[Term] {
  let out : Array[Term] = []
  collect_conjuncts(term, out)
  out
}

///|
fn bound_from_cmp(
  op : BuiltinOp,
  lhs : Term,
  rhs : Term,
  name : String,
) -> Bound? {
  let lhs_expr = lin_of_term(lhs)
  let rhs_expr = lin_of_term(rhs)
  match (lhs_expr, rhs_expr) {
    (Some(l), Some(r)) => {
      let mut expr = lin_sub(l, r)
      match op {
        BuiltinOp::Ge => ()
        BuiltinOp::Le => expr = lin_scale(expr, rat_neg(rat_one()))
        _ => return None
      }
      let coeff = lin_coeff(expr, name)
      if rat_is_zero(coeff) {
        return None
      }
      let rest = lin_remove_var(expr, name)
      let bound_expr = lin_scale(rest, rat_neg(rat_div(rat_one(), coeff)))
      if rat_sign(coeff) > 0 {
        Some({ kind: BoundKind::Lower, expr: bound_expr })
      } else {
        Some({ kind: BoundKind::Upper, expr: bound_expr })
      }
    }
    _ => None
  }
}

///|
fn linear_leq_forall(
  lower : LinExpr,
  upper : LinExpr,
  uvars : Map[String, Bool],
) -> Bool {
  let diff = lin_sub(lower, upper)
  for name, coeff in diff.coeffs {
    if !uvars.contains(name) {
      return true
    }
    if !rat_is_zero(coeff) {
      return false
    }
  }
  rat_le_zero(diff.constant)
}

///|
fn quantifier_unsat(term : Term) -> Bool {
  match term {
    Term::Quantifier(QuantifierKind::Forall, uvars, body) =>
      match body {
        Term::Quantifier(QuantifierKind::Exists, evars, inner) => {
          if evars.length() != 1 {
            return false
          }
          let evar = evars[0].name
          let lowers : Array[LinExpr] = []
          let uppers : Array[LinExpr] = []
          for atom in flatten_and(inner) {
            match atom {
              Term::Builtin(BuiltinOp::Ge, args, _)
              | Term::Builtin(BuiltinOp::Le, args, _) =>
                if args.length() == 2 {
                  let op = match atom {
                    Term::Builtin(op, _, _) => op
                    _ => BuiltinOp::Eq
                  }
                  match bound_from_cmp(op, args[0], args[1], evar) {
                    Some(bound) =>
                      match bound.kind {
                        BoundKind::Lower => lowers.push(bound.expr)
                        BoundKind::Upper => uppers.push(bound.expr)
                      }
                    None => ()
                  }
                }
              _ => ()
            }
          }
          if lowers.length() == 0 || uppers.length() == 0 {
            return false
          }
          let uvar_set : Map[String, Bool] = Map::new()
          for bound_var in uvars {
            uvar_set[bound_var.name] = true
          }
          for lower in lowers {
            for upper in uppers {
              if !linear_leq_forall(lower, upper, uvar_set) {
                return true
              }
            }
          }
          false
        }
        _ => false
      }
    _ => false
  }
}

///|
fn simplify_quantifier(term : Term) -> Term {
  simplify_term(term)
}

///|
priv struct CnfResult {
  clauses : Array[Array[Lit]]
  num_vars : Int
  atom_terms : Map[Int, Term]
  term_var : Map[Term, Int]
}

///|
fn build_cnf(assertions : Array[Term]) -> Result[CnfResult, SolverError] {
  let builder = CnfBuilder::new()
  for assertion in assertions {
    let norm = elim_let(assertion)
    match norm.sort() {
      Sort::Bool => ()
      _ => return Err(SolverError::InvalidAssertion("assert expects Bool"))
    }
    let simplified = simplify_quantifier(norm)
    let lit = encode_term(builder, simplified)
    builder.add_clause([lit])
  }
  Ok({
    clauses: builder.clauses,
    num_vars: builder.next_var,
    atom_terms: builder.atom_terms,
    term_var: builder.term_var,
  })
}
