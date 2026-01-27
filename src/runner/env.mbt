///|
pub struct FunDef {
  params : Array[BoundVar]
  range : Sort
  body : Term
} derive(Show, ToJson, Eq)

///|
pub struct EnvFrame {
  sorts : Map[String, Sort]
  consts : Map[String, Sort]
  funcs : Map[String, FuncDecl]
  fun_defs : Map[String, FunDef]
}

///|
fn EnvFrame::new() -> EnvFrame {
  {
    sorts: Map::new(),
    consts: Map::new(),
    funcs: Map::new(),
    fun_defs: Map::new(),
  }
}

///|
pub struct Env {
  frames : Array[EnvFrame]
}

///|
pub fn Env::new() -> Env {
  { frames: [EnvFrame::new()] }
}

///|
fn Env::current_index(self : Env) -> Int {
  self.frames.length() - 1
}

///|
fn Env::current(self : Env) -> EnvFrame {
  self.frames[self.current_index()]
}

///|
fn Env::replace_current(self : Env, frame : EnvFrame) -> Unit {
  let idx = self.current_index()
  self.frames[idx] = frame
}

///|
pub fn Env::push(self : Env) -> Unit {
  let frame = self.current()
  let next = {
    sorts: frame.sorts.copy(),
    consts: frame.consts.copy(),
    funcs: frame.funcs.copy(),
    fun_defs: frame.fun_defs.copy(),
  }
  self.frames.push(next)
}

///|
pub fn Env::pop(self : Env, n : Int) -> Unit raise Smt2Error {
  if n <= 0 {
    return ()
  }
  let available = self.frames.length() - 1
  if n > available {
    raise Smt2Error::ScopeUnderflow(expected=n, available~)
  }
  for _ in 0..<n {
    ignore(self.frames.pop())
  }
}

///|
pub fn Env::declare_sort(
  self : Env,
  name : String,
  arity : Int,
) -> Unit raise Smt2Error {
  if arity != 0 {
    raise Smt2Error::Unsupported("only 0-arity sorts are supported")
  }
  let frame = self.current()
  frame.sorts[name] = Sort::Uninterpreted(name)
  self.replace_current(frame)
}

///|
pub fn Env::define_sort(
  self : Env,
  name : String,
  params : Array[String],
  body : Sort,
) -> Unit raise Smt2Error {
  if params.length() != 0 {
    raise Smt2Error::Unsupported("parametric define-sort is not supported")
  }
  let frame = self.current()
  frame.sorts[name] = body
  self.replace_current(frame)
}

///|
pub fn Env::declare_const(
  self : Env,
  name : String,
  sort : Sort,
) -> Unit raise Smt2Error {
  let frame = self.current()
  frame.consts[name] = sort
  self.replace_current(frame)
}

///|
pub fn Env::declare_fun(
  self : Env,
  name : String,
  domain : Array[Sort],
  range : Sort,
) -> Unit raise Smt2Error {
  let frame = self.current()
  frame.funcs[name] = { name, domain, range }
  self.replace_current(frame)
}

///|
pub fn Env::define_fun(
  self : Env,
  name : String,
  params : Array[BoundVar],
  range : Sort,
  body : Term,
) -> Unit raise Smt2Error {
  let frame = self.current()
  frame.fun_defs[name] = { params, range, body }
  self.replace_current(frame)
}

///|
pub fn Env::find_sort(self : Env, name : String) -> Sort? {
  match name {
    "Bool" => Some(Sort::Bool)
    "Int" => Some(Sort::Int)
    "Real" => Some(Sort::Real)
    _ => self.current().sorts.get(name)
  }
}

///|
pub fn Env::find_const(self : Env, name : String) -> Sort? {
  self.current().consts.get(name)
}

///|
pub fn Env::find_fun(self : Env, name : String) -> FuncDecl? {
  self.current().funcs.get(name)
}

///|
pub fn Env::find_def(self : Env, name : String) -> FunDef? {
  self.current().fun_defs.get(name)
}
