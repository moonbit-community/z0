///|
pub struct ScopedVector[T] {
  items : Array[T]
  scopes : Array[Int]
}

///|
pub fn[T] ScopedVector::new() -> ScopedVector[T] {
  ScopedVector::{ items: [], scopes: [] }
}

///|
pub fn[T] ScopedVector::push_item(self : ScopedVector[T], item : T) -> Unit {
  self.items.push(item)
}

///|
pub fn[T] ScopedVector::items(self : ScopedVector[T]) -> Array[T] {
  self.items.copy()
}

///|
pub fn[T] ScopedVector::length(self : ScopedVector[T]) -> Int {
  self.items.length()
}

///|
pub fn[T] ScopedVector::scope_depth(self : ScopedVector[T]) -> Int {
  self.scopes.length()
}

///|
pub fn[T] ScopedVector::push_scope(self : ScopedVector[T]) -> Unit {
  self.scopes.push(self.items.length())
}

///|
pub fn[T] ScopedVector::pop_scope(
  self : ScopedVector[T],
  count : Int,
) -> Unit raise @solver_error.SolverError {
  let depth = self.scopes.length()
  if count < 0 {
    raise @solver_error.SolverError("cannot pop a negative number of scopes")
  } else if count > depth {
    raise @solver_error.SolverError(
      "cannot pop \{count} scope(s); only \{depth} scope(s) are active",
    )
  } else {
    let target_depth = depth - count
    if count > 0 {
      let item_len = self.scopes[target_depth]
      self.items.truncate(item_len)
      self.scopes.truncate(target_depth)
    }
  }
}

///|
pub fn[T] ScopedVector::commit_scope(
  self : ScopedVector[T],
  count : Int,
) -> Unit raise @solver_error.SolverError {
  let depth = self.scopes.length()
  if count < 0 {
    raise @solver_error.SolverError("cannot commit a negative number of scopes")
  } else if count > depth {
    raise @solver_error.SolverError(
      "cannot commit \{count} scope(s); only \{depth} scope(s) are active",
    )
  } else if count > 0 {
    self.scopes.truncate(depth - count)
  }
}
