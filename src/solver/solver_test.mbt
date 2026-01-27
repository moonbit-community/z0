///|
using @ast {type Sort, type Term, type BuiltinOp}

///|
test "sat bool" {
  let s = Solver::new()
  s.declare_const("a", Sort::Bool)
  let a = Term::Var("a", Sort::Bool)
  s.assert_term(a)
  match s.check_sat() {
    CheckSatResult::Sat(model) =>
      match model.get("a") {
        Some((_, Term::BoolVal(value))) => assert_true(value)
        _ => fail("unexpected model")
      }
    _ => fail("expected sat")
  }
}

///|
test "unsat bool" {
  let s = Solver::new()
  let a = Term::Var("a", Sort::Bool)
  s.assert_term(a)
  s.assert_term(Term::Builtin(BuiltinOp::Not, [a], Sort::Bool))
  match s.check_sat() {
    CheckSatResult::Unsat => ()
    _ => fail("expected unsat")
  }
}

///|
test "unsat euf" {
  let s = Solver::new()
  let u = Sort::Uninterpreted("U")
  let a = Term::Var("a", u)
  let b = Term::Var("b", u)
  s.assert_term(Term::Builtin(BuiltinOp::Eq, [a, b], Sort::Bool))
  s.assert_term(Term::Builtin(BuiltinOp::Distinct, [a, b], Sort::Bool))
  match s.check_sat() {
    CheckSatResult::Unsat => ()
    _ => fail("expected unsat")
  }
}

///|
test "model int" {
  let s = Solver::new()
  s.declare_const("x", Sort::Int)
  let x = Term::Var("x", Sort::Int)
  s.assert_term(Term::Builtin(BuiltinOp::Eq, [x, Term::IntVal(3)], Sort::Bool))
  match s.check_sat() {
    CheckSatResult::Sat(model) =>
      match model.get("x") {
        Some((_, Term::IntVal(value))) => assert_eq(value, 3)
        _ => fail("unexpected model")
      }
    _ => fail("expected sat")
  }
}
