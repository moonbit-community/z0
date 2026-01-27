///|
pub type Symbol = String

///|
pub(all) enum Sort {
  Bool
  Int
  Real
  BitVec(Int)
  FloatingPoint(Int, Int)
  Array(Sort, Sort)
  Uninterpreted(Symbol)
} derive(Show, ToJson, Eq, Hash)

///|
pub fn Sort::to_string(self : Sort) -> String {
  match self {
    Bool => "Bool"
    Int => "Int"
    Real => "Real"
    BitVec(width) => "(_ BitVec \{width})"
    FloatingPoint(eb, sb) => "(_ FloatingPoint \{eb} \{sb})"
    Array(dom, rng) => "(Array \{dom.to_string()} \{rng.to_string()})"
    Uninterpreted(name) => name
  }
}
