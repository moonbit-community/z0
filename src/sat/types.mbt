///|
pub enum LBool {
  True
  False
  Undef
} derive(Show, Eq)

///|
pub struct Lit {
  idx : Int
  neg : Bool
} derive(Show, Eq, Hash)

///|
pub fn lit_pos(idx : Int) -> Lit {
  { idx, neg: false }
}

///|
pub fn lit_neg(idx : Int) -> Lit {
  { idx, neg: true }
}

///|
pub fn Lit::not(self : Lit) -> Lit {
  { idx: self.idx, neg: !self.neg }
}

///|
pub fn Lit::eval(self : Lit, value : LBool) -> LBool {
  match value {
    LBool::Undef => LBool::Undef
    LBool::True => if self.neg { LBool::False } else { LBool::True }
    LBool::False => if self.neg { LBool::True } else { LBool::False }
  }
}
