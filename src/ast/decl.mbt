///|
pub(all) struct FuncDecl {
  name : Symbol
  domain : Array[Sort]
  range : Sort
} derive(Show, ToJson, Eq, Hash)

///|
pub fn FuncDecl::arity(self : FuncDecl) -> Int {
  self.domain.length()
}
