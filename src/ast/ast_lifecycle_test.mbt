///|
fn bool_const_expr(manager : AstManager, name : String) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
fn uf_const_expr(
  manager : AstManager,
  name : String,
  sort : @util.SortId,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, sort)
  manager.mk_app(decl, [])
}

///|
test "family_registry_has_bool_uf_and_reserved_families" {
  let manager = AstManager::new()
  let bool_family = manager.bool_family()
  let uf_family = manager.uf_family()
  let arith_family = manager.arith_family()
  inspect(manager.family_name(bool_family), content="Bool")
  inspect(manager.family_name(uf_family), content="UF")
  inspect(manager.family_name(arith_family), content="arith")
  inspect(
    manager.family_descriptor(arith_family).support_text(),
    content="supported:arith",
  )
  inspect(
    manager.family_descriptor(bool_family).hook_manifest_text(),
    content="clone,inherit,parameter_translation,mk_fresh,is_value,is_model_value,are_equal,are_distinct,get_some_value,is_considered_uninterpreted,translate",
  )
  match manager.family_descriptor(bool_family).hook_status(IsValue) {
    @util.Available(_) => inspect("available", content="available")
    @util.Unavailable(reason) => inspect(reason.to_text(), content="available")
  }
  match manager.lookup_family("array") {
    Some(array_family) =>
      inspect(
        manager.family_descriptor(array_family).support_text(),
        content="unsupported:array",
      )
    None => inspect("missing reserved family", content="array")
  }
}

///|
test "ast_manager_has_builtin_int_sort_and_arith_family" {
  let manager = AstManager::new()
  inspect(manager.int_sort(), content="sort#1")
  inspect(
    manager.lookup_sort("Int") == Some(manager.int_sort()),
    content="true",
  )
  inspect(manager.sort_name(manager.int_sort()), content="Int")
  inspect(
    manager.family_name(manager.sort_family(manager.int_sort())),
    content="arith",
  )
  match manager.ensure_family_supported(manager.arith_family()) {
    @util.Available(_) => inspect("available", content="available")
    @util.Unavailable(reason) => inspect(reason.to_text(), content="available")
  }
}

///|
test "ast_integer_literals_and_comparisons_are_typed_and_pretty" {
  let manager = AstManager::new()
  let one = manager.mk_int(1)
  let two = manager.mk_int(2)
  inspect(manager.expr_sort(one), content="sort#1")
  inspect(manager.pretty(one), content="1")
  inspect(manager.family_name(manager.expr_family(one)), content="arith")
  let less = manager.mk_lt(one, two)
  inspect(manager.expr_sort(less), content="sort#0")
  inspect(manager.pretty(less), content="(< 1 2)")
  inspect(manager.family_name(manager.expr_family(less)), content="arith")
  let equal = manager.mk_eq(one, one)
  inspect(manager.pretty(equal), content="(= 1 1)")
  inspect(manager.family_name(manager.expr_family(equal)), content="arith")
  try {
    ignore(manager.mk_lt(manager.mk_bool(true), one))
    inspect("missing diagnostic", content="type")
  } catch {
    @type_error.TypeError(_, _) as error =>
      inspect(error, content="type: expected Int argument")
    _ => inspect("wrong diagnostic", content="type")
  }
}

///|
test "sorts_declarations_and_exprs_carry_owner_family" {
  let manager = AstManager::new()
  let u = manager.declare_sort("U", 0)
  let p = bool_const_expr(manager, "p")
  let a = uf_const_expr(manager, "a", u)
  let eq = manager.mk_eq(a, a)
  let bool_term = manager.mk_and([p])
  inspect(
    manager.family_name(manager.sort_family(manager.bool_sort())),
    content="Bool",
  )
  inspect(manager.family_name(manager.sort_family(u)), content="UF")
  inspect(
    manager.family_name(manager.decl_family(manager.lookup_decl("a").unwrap())),
    content="UF",
  )
  inspect(manager.family_name(manager.expr_family(eq)), content="UF")
  inspect(manager.family_name(manager.expr_family(bool_term)), content="Bool")
}

///|
test "reserved_family_declaration_path_reports_typed_unsupported" {
  let manager = AstManager::new()
  match manager.lookup_family("bv") {
    Some(family) =>
      match manager.ensure_family_supported(family) {
        @util.Unavailable(reason) =>
          inspect(reason.to_text(), content="unsupported(bv)")
        @util.Available(_) =>
          inspect("unexpected supported family", content="unsupported")
      }
    None => inspect("missing bv family", content="unsupported")
  }
  match manager.lookup_family("array") {
    Some(family) =>
      match manager.family_descriptor(family).hook_status(Translate) {
        @util.Unavailable(reason) =>
          inspect(reason.to_text(), content="unsupported(array.translate)")
        @util.Available(_) =>
          inspect("unexpected supported hook", content="unsupported")
      }
    None => inspect("missing array family", content="unsupported")
  }
}

///|
test "ast_manager_full_reset_rebuilds_builtin_state" {
  let manager = AstManager::new()
  let u = manager.declare_sort("U", 0)
  ignore(uf_const_expr(manager, "a", u))
  ignore(manager.mk_bool(true))
  manager.full_reset()
  inspect(manager.lookup_sort("U") is None, content="true")
  inspect(manager.lookup_decl("a") is None, content="true")
  inspect(manager.bool_sort(), content="sort#0")
  inspect(manager.int_sort(), content="sort#1")
  inspect(manager.declare_sort("U", 0), content="sort#2")
  inspect(manager.mk_bool(true), content="expr#0")
}

///|
test "ast_translator_copies_uninterpreted_sort_decl_and_expr" {
  let source = AstManager::new()
  let u = source.declare_sort("U", 0)
  let a_decl = source.declare_const("a", u)
  let f_decl = source.declare_fun("f", [u], u)
  let a = source.mk_app(a_decl, [])
  let term = source.mk_app(f_decl, [a])
  let target = AstManager::new()
  ignore(target.declare_sort("Preexisting", 0))
  let translator = AstTranslator::new(source, target)
  let translated = translator.translate_expr(term)
  inspect(target.pretty(translated), content="(f a)")
  inspect(target.sort_name(target.expr_sort(translated)), content="U")
}

///|
test "family_sort_checks_reject_bool_and_uf_mismatches" {
  let manager = AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = uf_const_expr(manager, "a", u)
  let p = bool_const_expr(manager, "p")
  try {
    ignore(manager.mk_and([p, a]))
    inspect("missing diagnostic", content="type")
  } catch {
    @type_error.TypeError(_, _) as error =>
      inspect(error, content="type: expected Bool argument")
    _ => inspect("wrong diagnostic", content="type")
  }
  try {
    ignore(manager.mk_eq(p, a))
    inspect("missing diagnostic", content="type")
  } catch {
    @type_error.TypeError(_, _) as error =>
      inspect(error, content="type: equality arguments have different sorts")
    _ => inspect("wrong diagnostic", content="type")
  }
  let f = manager.declare_fun("f", [manager.bool_sort()], manager.bool_sort())
  try {
    ignore(manager.mk_app(f, [a]))
    inspect("missing diagnostic", content="type")
  } catch {
    @type_error.TypeError(_, _) as error =>
      inspect(error, content="type: argument sort mismatch")
    _ => inspect("wrong diagnostic", content="type")
  }
  try {
    ignore(manager.mk_distinct([p]))
    inspect("missing diagnostic", content="type")
  } catch {
    @type_error.TypeError(_, _) as error =>
      inspect(error, content="type: distinct expects at least two arguments")
    _ => inspect("wrong diagnostic", content="type")
  }
}

///|
test "macro_manager_scopes_copy_and_expand_bool_macros" {
  let manager = AstManager::new()
  let p = bool_const_expr(manager, "p")
  let macros = MacroManager::new()
  macros.insert("m", p)
  let copied = MacroManager::new()
  macros.copy_to(copied)
  inspect(copied.lookup("m") == Some(p), content="true")
  manager.install_macros(copied)
  let macro_ref = manager.mk_macro_ref("m")
  let expanded = manager.expand_macros(macro_ref)
  inspect(manager.pretty(expanded.result()), content="p")
  macros.push()
  macros.insert("local", p)
  macros.pop(1)
  inspect(macros.lookup("local") is None, content="true")
}

///|
test "defined_names_scope_and_nnf_identity_result" {
  let manager = AstManager::new()
  let p = bool_const_expr(manager, "p")
  let names = DefinedNames::new()
  names.insert("p_def", p)
  names.push()
  names.insert("local", p)
  names.pop(1)
  inspect(names.lookup("p_def") == Some(p), content="true")
  inspect(names.lookup("local") is None, content="true")
  let result = NnfResult::identity(p)
  inspect(result.result(), content="expr#0")
  inspect(result.new_defs_count(), content="0")
}
