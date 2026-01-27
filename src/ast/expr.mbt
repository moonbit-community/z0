///|
pub(all) enum BuiltinOp {
  Not
  And
  Or
  Implies
  Iff
  Xor
  Eq
  Distinct
  Ite
  Add
  Sub
  Mul
  Div
  Mod
  Neg
  Lt
  Le
  Gt
  Ge
} derive(Show, ToJson, Eq, Hash)

///|
pub(all) enum QuantifierKind {
  Forall
  Exists
} derive(Show, ToJson, Eq, Hash)

///|
pub(all) struct BoundVar {
  name : Symbol
  sort : Sort
} derive(Show, ToJson, Eq, Hash)

///|
pub(all) struct BitVecValue {
  width : Int
  repr : String
} derive(Show, ToJson, Eq, Hash)

///|
pub(all) struct FpValue {
  sign : BitVecValue
  exponent : BitVecValue
  significand : BitVecValue
} derive(Show, ToJson, Eq, Hash)

///|
pub(all) enum Term {
  BoolVal(Bool)
  IntVal(Int)
  RealVal(String)
  BitVecVal(BitVecValue)
  FpVal(FpValue)
  Var(Symbol, Sort)
  App(FuncDecl, Array[Term])
  Builtin(BuiltinOp, Array[Term], Sort)
  Let(Array[(Symbol, Term)], Term)
  Quantifier(QuantifierKind, Array[BoundVar], Term)
} derive(Show, ToJson, Eq, Hash)

///|
pub fn Term::sort(self : Term) -> Sort {
  match self {
    BoolVal(_) => Sort::Bool
    IntVal(_) => Sort::Int
    RealVal(_) => Sort::Real
    BitVecVal(value) => Sort::BitVec(value.width)
    FpVal(value) =>
      Sort::FloatingPoint(value.exponent.width, value.significand.width + 1)
    Var(_, sort) => sort
    App(decl, _) => decl.range
    Builtin(_, _, sort) => sort
    Let(_, body) => body.sort()
    Quantifier(_, _, _) => Sort::Bool
  }
}

///|
pub fn term_bool(value : Bool) -> Term {
  Term::BoolVal(value)
}

///|
pub fn term_int(value : Int) -> Term {
  Term::IntVal(value)
}

///|
pub fn term_real(value : String) -> Term {
  Term::RealVal(value)
}

///|
pub fn term_var(name : Symbol, sort : Sort) -> Term {
  Term::Var(name, sort)
}

///|
pub fn term_app(decl : FuncDecl, args : Array[Term]) -> Term {
  Term::App(decl, args)
}

///|
pub fn term_builtin(op : BuiltinOp, args : Array[Term], sort : Sort) -> Term {
  Term::Builtin(op, args, sort)
}

///|
pub fn term_let(bindings : Array[(Symbol, Term)], body : Term) -> Term {
  Term::Let(bindings, body)
}

///|
pub fn term_quantifier(
  kind : QuantifierKind,
  vars : Array[BoundVar],
  body : Term,
) -> Term {
  Term::Quantifier(kind, vars, body)
}
