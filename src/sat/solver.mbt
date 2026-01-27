///|
pub enum SatResult {
  Sat(Array[Bool])
  Unsat
} derive(Show, Eq)

///|
fn clause_satisfied(clause : Array[Lit], assignment : Array[LBool]) -> Bool {
  for lit in clause {
    match lit.eval(assignment[lit.idx]) {
      LBool::True => return true
      _ => ()
    }
  }
  false
}

///|
fn clause_unit_literal(clause : Array[Lit], assignment : Array[LBool]) -> Lit? {
  let mut unassigned : Lit? = None
  for lit in clause {
    match lit.eval(assignment[lit.idx]) {
      LBool::True => return None
      LBool::Undef =>
        match unassigned {
          None => unassigned = Some(lit)
          Some(_) => return None
        }
      LBool::False => ()
    }
  }
  unassigned
}

///|
fn propagate(clauses : Array[Array[Lit]], assignment : Array[LBool]) -> Bool {
  let mut changed = true
  while changed {
    changed = false
    for clause in clauses {
      if clause_satisfied(clause, assignment) {
        continue
      }
      let unit = clause_unit_literal(clause, assignment)
      match unit {
        Some(lit) => {
          let cur = assignment[lit.idx]
          match cur {
            LBool::Undef => {
              assignment[lit.idx] = if lit.neg {
                LBool::False
              } else {
                LBool::True
              }
              changed = true
            }
            _ => ()
          }
        }
        None => {
          // If no unit and not satisfied, clause may be conflicting.
          let mut any_undef = false
          for lit in clause {
            if assignment[lit.idx] == LBool::Undef {
              any_undef = true
              break
            }
          }
          if !any_undef {
            return false
          }
        }
      }
    }
  }
  true
}

///|
fn pick_unassigned(assignment : Array[LBool]) -> Int? {
  for i in 0..<assignment.length() {
    if assignment[i] == LBool::Undef {
      return Some(i)
    }
  }
  None
}

///|
fn is_complete(assignment : Array[LBool]) -> Bool {
  pick_unassigned(assignment) is None
}

///|
fn dpll(
  clauses : Array[Array[Lit]],
  assignment : Array[LBool],
) -> Array[LBool]? {
  if !propagate(clauses, assignment) {
    return None
  }
  if is_complete(assignment) {
    return Some(assignment)
  }
  match pick_unassigned(assignment) {
    None => Some(assignment)
    Some(choice) => {
      let assignment_true = assignment.copy()
      assignment_true[choice] = LBool::True
      match dpll(clauses, assignment_true) {
        Some(model) => Some(model)
        None => {
          let assignment_false = assignment.copy()
          assignment_false[choice] = LBool::False
          dpll(clauses, assignment_false)
        }
      }
    }
  }
}

///|
pub fn solve(clauses : Array[Array[Lit]], num_vars : Int) -> SatResult {
  let assignment : Array[LBool] = []
  for _ in 0..<num_vars {
    assignment.push(LBool::Undef)
  }
  match dpll(clauses, assignment) {
    Some(model) => {
      let bools : Array[Bool] = []
      for v in model {
        match v {
          LBool::True => bools.push(true)
          LBool::False => bools.push(false)
          LBool::Undef => bools.push(false)
        }
      }
      SatResult::Sat(bools)
    }
    None => SatResult::Unsat
  }
}
