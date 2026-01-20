///|
pub(all) enum Atom {
  Symbol(String)
  Keyword(String)
  Numeral(String)
  Decimal(String)
  String(String)
  BitvectorBinary(String)
  BitvectorHex(String)
} derive(Show, ToJson, Eq)

///|
pub(all) enum SExpr {
  Atom(Atom)
  List(Array[SExpr])
} derive(Show, ToJson, Eq)
