///|
pub struct AstManager {
  priv mut families : Array[FamilyDescriptor]
  priv mut sorts : @util.ScopedVector[Sort]
  priv mut decls : @util.ScopedVector[FuncDecl]
  priv mut macros : MacroManager
  priv mut exprs : Array[Expr]
}

///|
pub fn AstManager::new() -> AstManager {
  let manager = AstManager::{
    families: default_family_descriptors(),
    sorts: @util.ScopedVector::new(),
    decls: @util.ScopedVector::new(),
    macros: MacroManager::new(),
    exprs: [],
  }
  manager.init_builtin_sorts()
  manager
}

///|
fn AstManager::init_builtin_sorts(self : AstManager) -> Unit {
  let sorts = @util.ScopedVector::new()
  sorts.push_item(Sort::{
    id: @util.SortId::new(0),
    name: "Bool",
    kind: BoolSort,
    family: self.bool_family(),
  })
  sorts.push_item(Sort::{
    id: @util.SortId::new(1),
    name: "Int",
    kind: IntSort,
    family: self.arith_family(),
  })
  self.sorts = sorts
}

///|
pub fn AstManager::bool_sort(_self : AstManager) -> @util.SortId {
  @util.SortId::new(0)
}

///|
pub fn AstManager::int_sort(_self : AstManager) -> @util.SortId {
  @util.SortId::new(1)
}

///|
pub fn AstManager::bool_family(_self : AstManager) -> FamilyId {
  FamilyId::new(0)
}

///|
pub fn AstManager::uf_family(_self : AstManager) -> FamilyId {
  FamilyId::new(1)
}

///|
pub fn AstManager::arith_family(_self : AstManager) -> FamilyId {
  FamilyId::new(2)
}

///|
pub fn AstManager::family_name(self : AstManager, id : FamilyId) -> String {
  self.family_descriptor(id).name()
}

///|
pub fn AstManager::family_descriptor(
  self : AstManager,
  id : FamilyId,
) -> FamilyDescriptor {
  self.families[id.to_int()]
}

///|
pub fn AstManager::lookup_family(self : AstManager, name : String) -> FamilyId? {
  for descriptor in self.families {
    if descriptor.name() == name {
      return Some(descriptor.id())
    }
  }
  None
}

///|
pub fn AstManager::ensure_family_supported(
  self : AstManager,
  id : FamilyId,
) -> @util.Availability[Unit] {
  let descriptor = self.family_descriptor(id)
  if descriptor.is_supported() {
    @util.Available(())
  } else {
    @util.Unavailable(
      @util.AvailabilityReason::unsupported(
        @util.ReasonUnknown::unsupported_fragment(descriptor.name()),
      ),
    )
  }
}

///|
pub fn AstManager::sort_family(
  self : AstManager,
  sort : @util.SortId,
) -> FamilyId {
  self.sorts_snapshot()[sort.to_int()].family
}

///|
pub fn AstManager::decl_family(
  self : AstManager,
  decl : @util.FuncDeclId,
) -> FamilyId {
  self.get_decl(decl).family
}

///|
pub fn AstManager::expr_family(
  self : AstManager,
  expr_id : @util.ExprId,
) -> FamilyId {
  let expr = self.get_expr(expr_id)
  match expr.kind {
    BoolValue(_) | Not(_) | And(_) | Or(_) | Implies(_, _) | Xor(_, _) =>
      self.bool_family()
    IntValue(_) | ArithCompare(_, _, _) => self.arith_family()
    MacroRef(_) => self.sort_family(expr.sort)
    Eq(lhs, _) =>
      if self.expr_sort(lhs) == self.int_sort() {
        self.arith_family()
      } else if self.expr_sort(lhs) == self.bool_sort() {
        self.bool_family()
      } else {
        self.uf_family()
      }
    Distinct(args) =>
      if !args.is_empty() && self.expr_sort(args[0]) == self.int_sort() {
        self.arith_family()
      } else {
        self.uf_family()
      }
    App(decl, _) => self.decl_family(decl)
  }
}

///|
pub fn AstManager::full_reset(self : AstManager) -> Unit {
  self.families = default_family_descriptors()
  self.sorts = @util.ScopedVector::new()
  self.decls = @util.ScopedVector::new()
  self.macros = MacroManager::new()
  self.exprs = []
  self.init_builtin_sorts()
}

///|
fn AstManager::sorts_snapshot(self : AstManager) -> Array[Sort] {
  self.sorts.items()
}

///|
fn AstManager::decls_snapshot(self : AstManager) -> Array[FuncDecl] {
  self.decls.items()
}

///|
pub fn AstManager::lookup_sort(
  self : AstManager,
  name : String,
) -> @util.SortId? {
  for sort in self.sorts_snapshot() {
    if sort.name == name {
      return Some(sort.id)
    }
  }
  None
}

///|
pub fn AstManager::sort_name(
  self : AstManager,
  sort_id : @util.SortId,
) -> String {
  self.sorts_snapshot()[sort_id.to_int()].name
}

///|
pub fn AstManager::declare_sort(
  self : AstManager,
  name : String,
  arity : Int,
) -> @util.SortId raise {
  if arity != 0 {
    raise @unsupported_error.UnsupportedError(
      "sort arity is not supported",
      None,
    )
  } else {
    match self.lookup_sort(name) {
      Some(_) =>
        raise @type_error.TypeError("sort already declared: \{name}", None)
      None => {
        let id = @util.SortId::new(self.sorts.length())
        self.sorts.push_item(Sort::{
          id,
          name,
          kind: UninterpretedSort(name),
          family: self.uf_family(),
        })
        id
      }
    }
  }
}

///|
pub fn AstManager::lookup_decl(
  self : AstManager,
  name : String,
) -> @util.FuncDeclId? {
  for decl in self.decls_snapshot() {
    if decl.name == name {
      return Some(decl.id)
    }
  }
  None
}

///|
pub fn AstManager::lookup_macro(
  self : AstManager,
  name : String,
) -> @util.ExprId? {
  self.macros.lookup(name)
}

///|
fn AstManager::name_is_free(self : AstManager, name : String) -> Bool {
  self.lookup_decl(name) is None && self.lookup_macro(name) is None
}

///|
pub fn AstManager::declare_const(
  self : AstManager,
  name : String,
  sort : @util.SortId,
) -> @util.FuncDeclId raise @type_error.TypeError {
  self.declare_fun(name, [], sort)
}

///|
pub fn AstManager::declare_fun(
  self : AstManager,
  name : String,
  domain : Array[@util.SortId],
  range : @util.SortId,
) -> @util.FuncDeclId raise @type_error.TypeError {
  if !self.name_is_free(name) {
    raise @type_error.TypeError("declaration already exists: \{name}", None)
  } else {
    let id = @util.FuncDeclId::new(self.decls.length())
    self.decls.push_item(FuncDecl::{
      id,
      name,
      domain: domain.copy(),
      range,
      family: self.uf_family(),
    })
    id
  }
}

///|
pub fn AstManager::define_bool_macro(
  self : AstManager,
  name : String,
  expr : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  if self.expr_sort(expr) != self.bool_sort() {
    raise @type_error.TypeError("expected Bool macro body", None)
  } else {
    self.define_macro(name, expr)
  }
}

///|
pub fn AstManager::define_macro(
  self : AstManager,
  name : String,
  expr : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  if !self.name_is_free(name) {
    raise @type_error.TypeError("declaration already exists: \{name}", None)
  } else {
    self.macros.insert(name, expr)
  }
}

///|
pub fn AstManager::define_scoped_macro(
  self : AstManager,
  name : String,
  expr : @util.ExprId,
) -> Unit {
  self.macros.insert(name, expr)
}

///|
pub fn AstManager::push_scope(self : AstManager) -> Unit {
  self.sorts.push_scope()
  self.decls.push_scope()
  self.macros.push()
}

///|
pub fn AstManager::pop_scope(
  self : AstManager,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  self.sorts.pop_scope(count)
  self.decls.pop_scope(count)
  self.macros.pop(count)
}

///|
pub fn AstManager::commit_scope(
  self : AstManager,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  self.sorts.commit_scope(count)
  self.decls.commit_scope(count)
  self.macros.commit(count)
}

///|
pub fn AstManager::install_macros(
  self : AstManager,
  macros : MacroManager,
) -> Unit {
  macros.copy_to(self.macros)
}

///|
pub fn AstManager::expand_macros(
  self : AstManager,
  expr : @util.ExprId,
) -> MacroExpansion raise @type_error.TypeError {
  self.macros.expand_macros(self, expr)
}

///|
pub fn AstManager::get_decl(
  self : AstManager,
  id : @util.FuncDeclId,
) -> FuncDecl {
  self.decls_snapshot()[id.to_int()]
}

///|
pub fn AstManager::get_expr(self : AstManager, id : @util.ExprId) -> Expr {
  self.exprs[id.to_int()]
}

///|
pub fn AstManager::expr_sort(
  self : AstManager,
  id : @util.ExprId,
) -> @util.SortId {
  self.get_expr(id).sort
}

///|
fn AstManager::intern(
  self : AstManager,
  kind : ExprKind,
  sort : @util.SortId,
) -> @util.ExprId {
  for expr in self.exprs {
    if expr.kind == kind && expr.sort == sort {
      return expr.id
    }
  }
  let id = @util.ExprId::new(self.exprs.length())
  self.exprs.push(Expr::{ id, kind, sort })
  id
}

///|
pub fn AstManager::mk_bool(self : AstManager, value : Bool) -> @util.ExprId {
  self.intern(BoolValue(value), self.bool_sort())
}

///|
pub fn AstManager::mk_int(self : AstManager, value : Int) -> @util.ExprId {
  self.intern(IntValue(value), self.int_sort())
}

///|
fn AstManager::expect_bool(
  self : AstManager,
  expr : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  if self.expr_sort(expr) != self.bool_sort() {
    raise @type_error.TypeError("expected Bool argument", None)
  }
}

///|
fn AstManager::expect_all_bool(
  self : AstManager,
  args : Array[@util.ExprId],
) -> Unit raise @type_error.TypeError {
  for arg in args {
    self.expect_bool(arg)
  }
}

///|
fn AstManager::expect_int(
  self : AstManager,
  expr : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  if self.expr_sort(expr) != self.int_sort() {
    raise @type_error.TypeError("expected Int argument", None)
  }
}

///|
pub fn AstManager::mk_app(
  self : AstManager,
  decl_id : @util.FuncDeclId,
  args : Array[@util.ExprId],
) -> @util.ExprId raise @type_error.TypeError {
  let decl = self.get_decl(decl_id)
  if decl.domain.length() != args.length() {
    raise @type_error.TypeError("wrong number of arguments", None)
  } else {
    for i in 0..<args.length() {
      if self.expr_sort(args[i]) != decl.domain[i] {
        raise @type_error.TypeError("argument sort mismatch", None)
      }
    }
    self.intern(App(decl_id, args.copy()), decl.range)
  }
}

///|
pub fn AstManager::mk_arith_compare(
  self : AstManager,
  op : ArithCompareOp,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  self.expect_int(lhs)
  self.expect_int(rhs)
  self.intern(ArithCompare(op, lhs, rhs), self.bool_sort())
}

///|
pub fn AstManager::mk_lt(
  self : AstManager,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  self.mk_arith_compare(Lt, lhs, rhs)
}

///|
pub fn AstManager::mk_le(
  self : AstManager,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  self.mk_arith_compare(Le, lhs, rhs)
}

///|
pub fn AstManager::mk_gt(
  self : AstManager,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  self.mk_arith_compare(Gt, lhs, rhs)
}

///|
pub fn AstManager::mk_ge(
  self : AstManager,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  self.mk_arith_compare(Ge, lhs, rhs)
}

///|
pub fn AstManager::mk_macro_ref(
  self : AstManager,
  name : String,
) -> @util.ExprId raise @type_error.TypeError {
  match self.lookup_macro(name) {
    Some(body) => self.intern(MacroRef(name), self.expr_sort(body))
    None => raise @type_error.TypeError("unknown macro: \{name}", None)
  }
}

///|
pub fn AstManager::mk_not(
  self : AstManager,
  expr : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  self.expect_bool(expr)
  self.intern(Not(expr), self.bool_sort())
}

///|
pub fn AstManager::mk_and(
  self : AstManager,
  args : Array[@util.ExprId],
) -> @util.ExprId raise @type_error.TypeError {
  self.expect_all_bool(args)
  self.intern(And(args.copy()), self.bool_sort())
}

///|
pub fn AstManager::mk_or(
  self : AstManager,
  args : Array[@util.ExprId],
) -> @util.ExprId raise @type_error.TypeError {
  self.expect_all_bool(args)
  self.intern(Or(args.copy()), self.bool_sort())
}

///|
pub fn AstManager::mk_implies(
  self : AstManager,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  self.expect_bool(lhs)
  self.expect_bool(rhs)
  self.intern(Implies(lhs, rhs), self.bool_sort())
}

///|
pub fn AstManager::mk_xor(
  self : AstManager,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  self.expect_bool(lhs)
  self.expect_bool(rhs)
  self.intern(Xor(lhs, rhs), self.bool_sort())
}

///|
pub fn AstManager::mk_eq(
  self : AstManager,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  if self.expr_sort(lhs) != self.expr_sort(rhs) {
    raise @type_error.TypeError("equality arguments have different sorts", None)
  } else {
    self.intern(Eq(lhs, rhs), self.bool_sort())
  }
}

///|
pub fn AstManager::mk_distinct(
  self : AstManager,
  args : Array[@util.ExprId],
) -> @util.ExprId raise @type_error.TypeError {
  if args.length() < 2 {
    raise @type_error.TypeError("distinct expects at least two arguments", None)
  } else {
    let sort = self.expr_sort(args[0])
    for arg in args {
      if self.expr_sort(arg) != sort {
        raise @type_error.TypeError(
          "distinct arguments have different sorts",
          None,
        )
      }
    }
    self.intern(Distinct(args.copy()), self.bool_sort())
  }
}
