///|
pub struct Solver {
  assertions : Array[Term]
  scopes : Array[Int]
  consts : Map[String, Sort]
  mut last_model : Model?
}

///|
pub fn Solver::new() -> Solver {
  { assertions: [], scopes: [], consts: Map::new(), last_model: None }
}

///|
pub fn Solver::declare_const(self : Solver, name : String, sort : Sort) -> Unit {
  self.consts[name] = sort
}

///|
pub fn Solver::assert_term(self : Solver, term : Term) -> Unit {
  self.assertions.push(term)
}

///|
pub fn Solver::push(self : Solver) -> Unit {
  self.scopes.push(self.assertions.length())
}

///|
pub fn Solver::pop(self : Solver, n : Int) -> Result[Unit, SolverError] {
  if n <= 0 {
    return Ok(())
  }
  let available = self.scopes.length()
  if n > available {
    return Err(SolverError::ScopeUnderflow(expected=n, available~))
  }
  let target = self.scopes[available - n]
  for _ in 0..<n {
    ignore(self.scopes.pop())
  }
  while self.assertions.length() > target {
    ignore(self.assertions.pop())
  }
  Ok(())
}

///|
pub fn Solver::get_model(self : Solver) -> Model? {
  self.last_model
}

///|
fn uf_find(parent : Array[Int], x : Int) -> Int {
  if parent[x] == x {
    x
  } else {
    let root = uf_find(parent, parent[x])
    parent[x] = root
    root
  }
}

///|
fn bitvec_zero(width : Int) -> BitVecValue {
  let sb = StringBuilder::new()
  sb..write_string("#b")
  for _ in 0..<width {
    sb..write_char('0')
  }
  { width, repr: sb.to_string() }
}

///|
fn fp_zero(eb : Int, sb : Int) -> Term {
  let sign = bitvec_zero(1)
  let exponent = bitvec_zero(eb)
  let significand = bitvec_zero(sb - 1)
  Term::FpVal({ sign, exponent, significand })
}

///|
fn default_value(sort : Sort, idx : Int) -> Term {
  match sort {
    Sort::Bool => Term::BoolVal(false)
    Sort::Int => Term::IntVal(0)
    Sort::Real => Term::RealVal("0")
    Sort::BitVec(width) => Term::BitVecVal(bitvec_zero(width))
    Sort::FloatingPoint(eb, sb) => fp_zero(eb, sb)
    Sort::Array(_, _) => Term::Var("k!\{idx}", sort)
    Sort::Uninterpreted(_) => Term::Var("k!\{idx}", sort)
  }
}

///|
fn is_value_term(term : Term) -> Bool {
  match term {
    Term::BoolVal(_) => true
    Term::IntVal(_) => true
    Term::RealVal(_) => true
    Term::BitVecVal(_) => true
    Term::FpVal(_) => true
    _ => false
  }
}

///|
fn is_var_term(term : Term) -> Bool {
  match term {
    Term::Var(_, _) => true
    _ => false
  }
}

///|
fn build_model(
  consts : Map[String, Sort],
  term_var : Map[Term, Int],
  assignment : Array[Bool],
  equalities : Array[(Term, Term)],
  disequalities : Array[(Term, Term)],
) -> Model {
  let model = Model::new()
  let (ids, parent) = @euf.build_classes(equalities, disequalities)
  let reps : Map[Int, Term] = Map::new()
  for term, id in ids {
    let root = uf_find(parent, id)
    match reps.get(root) {
      None => reps[root] = term
      Some(existing) =>
        if is_value_term(term) && !is_value_term(existing) {
          reps[root] = term
        } else if !is_value_term(existing) &&
          is_var_term(existing) &&
          !is_var_term(term) {
          reps[root] = term
        }
    }
  }
  let mut fresh = 0
  for name, sort in consts {
    let term = Term::Var(name, sort)
    let value = if sort == Sort::Bool {
      match term_var.get(term) {
        Some(idx) => Term::BoolVal(assignment[idx])
        None => default_value(sort, fresh)
      }
    } else {
      match ids.get(term) {
        Some(id) => {
          let root = uf_find(parent, id)
          match reps.get(root) {
            Some(rep) => rep
            None => default_value(sort, fresh)
          }
        }
        None => default_value(sort, fresh)
      }
    }
    model.set(name, sort, value)
    fresh = fresh + 1
  }
  model
}

///|
fn check_theory(
  atom_terms : Map[Int, Term],
  assignment : Array[Bool],
) -> Result[(Array[(Term, Term)], Array[(Term, Term)]), String] {
  let equalities : Array[(Term, Term)] = []
  let disequalities : Array[(Term, Term)] = []
  for idx, term in atom_terms {
    let value = assignment[idx]
    match term {
      Term::Builtin(BuiltinOp::Eq, args, _) => {
        if args.length() != 2 {
          return Err("unsupported equality arity")
        }
        if value {
          equalities.push((args[0], args[1]))
        } else {
          disequalities.push((args[0], args[1]))
        }
      }
      Term::Builtin(BuiltinOp::Distinct, args, _) => {
        if args.length() != 2 {
          return Err("unsupported distinct arity")
        }
        if value {
          disequalities.push((args[0], args[1]))
        } else {
          equalities.push((args[0], args[1]))
        }
      }
      Term::Builtin(BuiltinOp::Lt, _, _)
      | Term::Builtin(BuiltinOp::Le, _, _)
      | Term::Builtin(BuiltinOp::Gt, _, _)
      | Term::Builtin(BuiltinOp::Ge, _, _) =>
        return Err("arithmetic comparisons are not supported")
      _ => return Err("unsupported theory atom")
    }
  }
  Ok((equalities, disequalities))
}

///|
pub fn Solver::check_sat(self : Solver) -> CheckSatResult {
  let cnf = match build_cnf(self.assertions) {
    Ok(result) => result
    Err(err) => return CheckSatResult::Unknown(err.to_string())
  }
  let clauses = cnf.clauses.copy()
  let loop_clauses = clauses
  while true {
    match @sat.solve(loop_clauses, cnf.num_vars) {
      SatResult::Unsat => {
        self.last_model = None
        return CheckSatResult::Unsat
      }
      SatResult::Sat(assignment) => {
        let theory = check_theory(cnf.atom_terms, assignment)
        match theory {
          Err(msg) => {
            self.last_model = None
            return CheckSatResult::Unknown(msg)
          }
          Ok((equalities, disequalities)) =>
            match @euf.check_euf(equalities, disequalities) {
              EufResult::Sat => {
                let model = build_model(
                  self.consts,
                  cnf.term_var,
                  assignment,
                  equalities,
                  disequalities,
                )
                self.last_model = Some(model)
                return CheckSatResult::Sat(model)
              }
              EufResult::Unsat => {
                let block : Array[Lit] = []
                for idx, _term in cnf.atom_terms {
                  let lit = if assignment[idx] {
                    @sat.lit_neg(idx)
                  } else {
                    @sat.lit_pos(idx)
                  }
                  block.push(lit)
                }
                if block.length() == 0 {
                  self.last_model = None
                  return CheckSatResult::Unsat
                }
                loop_clauses.push(block)
              }
            }
        }
      }
    }
  }
  CheckSatResult::Unknown("unreachable")
}
