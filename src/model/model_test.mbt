///|
test "pure_model_prints_bool_consts_in_decl_order" {
  let model = Model::new()
  model.add_bool_const(@util.FuncDeclId::new(2), "q", false)
  model.add_bool_const(@util.FuncDeclId::new(1), "p", true)
  inspect(
    model.format(),
    content="(\n  (define-fun p () Bool\n    true)\n  (define-fun q () Bool\n    false)\n)",
  )
}

///|
fn bool_value_text(value : Bool?) -> String {
  match value {
    Some(true) => "true"
    Some(false) => "false"
    None => "missing"
  }
}

///|
fn model_value_sort_text(sort : @util.SortId?) -> String {
  match sort {
    Some(sort) => "sort#\{sort.to_int()}"
    None => "none"
  }
}

///|
test "pure_model_evaluates_bool_const_interpretations" {
  let model = Model::new()
  let p = @util.FuncDeclId::new(1)
  let q = @util.FuncDeclId::new(2)
  model.add_bool_const(p, "p", true)
  inspect(bool_value_text(model.bool_const_value(p)), content="true")
  inspect(bool_value_text(model.bool_const_value(q)), content="missing")
}

///|
test "pure_func_interp_formats_finite_entries_and_else_value" {
  let interp = FuncInterp::new("f", ["U"], "U")
  interp.add_entry(["@u2"], "@u3")
  interp.add_entry(["@u0"], "@u1")
  interp.set_else("@default")
  inspect(
    interp.format(),
    content=(
      #|(define-fun f ((x0 U)) U
      #|  (ite (= x0 @u0)
      #|    @u1
      #|    (ite (= x0 @u2)
      #|      @u3
      #|      @default)))
    ),
  )
}

///|
test "pure_func_interp_replaces_duplicate_entry_args" {
  let interp = FuncInterp::new("f", ["U"], "U")
  interp.add_entry(["@u0"], "@old")
  interp.add_entry(["@u0"], "@new")
  interp.set_else("@fallback")
  inspect(
    interp.format(),
    content=(
      #|(define-fun f ((x0 U)) U
      #|  (ite (= x0 @u0)
      #|    @new
      #|    @fallback))
    ),
  )
}

///|
test "pure_model_prints_function_interps_after_bool_consts" {
  let model = Model::new()
  model.add_bool_const(@util.FuncDeclId::new(1), "p", true)
  let interp = FuncInterp::new("f", ["U"], "U")
  interp.add_entry(["@u0"], "@u1")
  interp.set_else("@default")
  model.add_func_interp(@util.FuncDeclId::new(2), interp)
  inspect(
    model.format(),
    content=(
      #|(
      #|  (define-fun p () Bool
      #|    true)
      #|  (define-fun f ((x0 U)) U
      #|    (ite (= x0 @u0)
      #|      @u1
      #|      @default))
      #|)
    ),
  )
}

///|
test "pure_value_factory_creates_bool_and_uf_values_deterministically" {
  let factory = ValueFactory::new()
  let sort_u = @util.SortId::new(3)
  let sort_v = @util.SortId::new(4)
  inspect(ModelValue::bool(true).to_text(), content="true")
  inspect(model_value_sort_text(ModelValue::bool(true).sort()), content="none")
  inspect(ModelValue::bool(false).to_text(), content="false")
  let u0 = factory.fresh_uninterpreted(sort_u, "U")
  inspect(u0.to_text(), content="@U0")
  inspect(model_value_sort_text(u0.sort()), content="sort#3")
  inspect(factory.fresh_uninterpreted(sort_u, "U").to_text(), content="@U1")
  inspect(factory.fresh_uninterpreted(sort_v, "V").to_text(), content="@V0")
}

///|
test "pure_model_value_printer_formats_smt2_values" {
  let factory = ValueFactory::new()
  let sort_u = @util.SortId::new(3)
  inspect(ModelValue::bool(true).format_smt2(), content="true")
  inspect(ModelValue::bool(false).format_smt2(), content="false")
  inspect(ModelValue::int(42).format_smt2(), content="42")
  inspect(factory.fresh_uninterpreted(sort_u, "U").format_smt2(), content="@U0")
}

///|
test "pure_model_prints_int_consts_without_universe" {
  let model = Model::new()
  let int_sort = @util.SortId::new(7)
  model.add_value_const(
    @util.FuncDeclId::new(1),
    int_sort,
    "Int",
    ModelValue::int(42),
    name="n",
  )
  inspect(
    model.format(),
    content=(
      #|(
      #|  (define-fun n () Int
      #|    42)
      #|)
    ),
  )
}

///|
test "pure_model_tracks_uninterpreted_sort_universes_in_stable_order" {
  let model = Model::new()
  let factory = ValueFactory::new()
  let sort_u = @util.SortId::new(3)
  let sort_v = @util.SortId::new(4)
  model.add_universe_value(
    sort_v,
    "V",
    factory.fresh_uninterpreted(sort_v, "V"),
  )
  model.add_universe_value(
    sort_u,
    "U",
    factory.fresh_uninterpreted(sort_u, "U"),
  )
  model.add_universe_value(
    sort_u,
    "U",
    factory.fresh_uninterpreted(sort_u, "U"),
  )
  let u_values = model.universe_values(sort_u)
  inspect(u_values[0].to_text(), content="@U0")
  inspect(u_values[1].to_text(), content="@U1")
  inspect(
    model.format(),
    content=(
      #|(
      #|  ;; universe U: @U0 @U1
      #|  (declare-fun @U0 () U)
      #|  (declare-fun @U1 () U)
      #|  ;; cardinality constraint for U
      #|  (forall ((x U)) (or (= x @U0) (= x @U1)))
      #|  ;; universe V: @V0
      #|  (declare-fun @V0 () V)
      #|  ;; cardinality constraint for V
      #|  (forall ((x V)) (= x @V0))
      #|)
    ),
  )
}

///|
test "pure_model_prints_universe_declarations_and_cardinality" {
  let model = Model::new()
  let factory = ValueFactory::new()
  let sort_u = @util.SortId::new(3)
  model.add_universe_value(
    sort_u,
    "U",
    factory.fresh_uninterpreted(sort_u, "U"),
  )
  model.add_universe_value(
    sort_u,
    "U",
    factory.fresh_uninterpreted(sort_u, "U"),
  )
  inspect(
    model.format(),
    content=(
      #|(
      #|  ;; universe U: @U0 @U1
      #|  (declare-fun @U0 () U)
      #|  (declare-fun @U1 () U)
      #|  ;; cardinality constraint for U
      #|  (forall ((x U)) (or (= x @U0) (= x @U1)))
      #|)
    ),
  )
}

///|
test "pure_model_prints_uninterpreted_const_interps" {
  let model = Model::new()
  let factory = ValueFactory::new()
  let sort_u = @util.SortId::new(3)
  let value = factory.fresh_uninterpreted(sort_u, "U")
  model.add_value_const(@util.FuncDeclId::new(1), sort_u, "U", value, name="a")
  inspect(
    model.format(),
    content=(
      #|(
      #|  ;; universe U: @U0
      #|  (declare-fun @U0 () U)
      #|  ;; cardinality constraint for U
      #|  (forall ((x U)) (= x @U0))
      #|  (define-fun a () U
      #|    @U0)
      #|)
    ),
  )
}

///|
test "pure_model_updates_uninterpreted_const_interpretation" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = manager.declare_const("a", sort_u)
  let a_expr = manager.mk_app(a, [])
  let first = model.fresh_uninterpreted_value(sort_u, "U")
  let second = model.fresh_uninterpreted_value(sort_u, "U")
  model.add_value_const(a, sort_u, "U", first, name="a")
  model.add_value_const(a, sort_u, "U", second, name="a")
  inspect(
    model_value_text(model.eval(manager, a_expr, completion=false)),
    content="@U1",
  )
}

///|
test "pure_model_skips_hidden_aux_interpretations" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let sort_u = manager.declare_sort("U", 0)
  let x = manager.declare_const("x", sort_u)
  let aux = manager.declare_const("aux", sort_u)
  let aux_f = manager.declare_fun("aux_f", [sort_u], sort_u)
  let x_expr = manager.mk_app(x, [])
  let aux_expr = manager.mk_app(aux, [])
  let x_value = model.fresh_uninterpreted_value(sort_u, "U")
  let aux_value = model.fresh_uninterpreted_value(sort_u, "U")
  model.add_value_const(x, sort_u, "U", x_value, name="x")
  model.add_value_const(aux, sort_u, "U", aux_value)
  let interp = FuncInterp::new("", ["U"], "U")
  interp.add_entry([x_value.to_text()], aux_value.to_text())
  model.add_func_interp(aux_f, interp)
  let aux_f_x = manager.mk_app(aux_f, [x_expr])
  inspect(
    model_value_text(model.eval(manager, aux_expr, completion=false)),
    content="missing",
  )
  inspect(
    model_value_text(model.eval(manager, aux_f_x, completion=false)),
    content="missing",
  )
  inspect(
    model.format(),
    content=(
      #|(
      #|  ;; universe U: @U0 @U1
      #|  (declare-fun @U0 () U)
      #|  (declare-fun @U1 () U)
      #|  ;; cardinality constraint for U
      #|  (forall ((x U)) (or (= x @U0) (= x @U1)))
      #|  (define-fun x () U
      #|    @U0)
      #|)
    ),
  )
}

///|
fn model_value_text(value : ModelValue?) -> String {
  match value {
    Some(value) => value.to_text()
    None => "missing"
  }
}

///|
fn test_int_sort(manager : @ast.AstManager) -> @util.SortId raise {
  match manager.lookup_sort("Int") {
    Some(sort) => sort
    None => manager.declare_sort("Int", 0)
  }
}

///|
test "pure_model_eval_computes_ground_bool_exprs" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let p = manager.declare_const("p", manager.bool_sort())
  let q = manager.declare_const("q", manager.bool_sort())
  model.add_bool_const(p, "p", true)
  model.add_bool_const(q, "q", false)
  let expr = manager.mk_and([
    manager.mk_app(p, []),
    manager.mk_not(manager.mk_app(q, [])),
  ])
  inspect(
    model_value_text(model.eval(manager, expr, completion=false)),
    content="true",
  )
}

///|
test "pure_model_eval_expands_bool_macros" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let p = manager.declare_const("p", manager.bool_sort())
  let p_expr = manager.mk_app(p, [])
  model.add_bool_const(p, "p", true)
  ignore(manager.define_bool_macro("m", manager.mk_not(p_expr)))
  inspect(
    model_value_text(
      model.eval(manager, manager.mk_macro_ref("m"), completion=false),
    ),
    content="false",
  )
}

///|
test "pure_model_eval_completion_assigns_fresh_uf_const_value" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = manager.declare_const("a", sort_u)
  let a_expr = manager.mk_app(a, [])
  inspect(
    model_value_text(model.eval(manager, a_expr, completion=false)),
    content="missing",
  )
  inspect(
    model_value_text(model.eval(manager, a_expr, completion=true)),
    content="@U0",
  )
  inspect(
    model_value_text(model.eval(manager, a_expr, completion=true)),
    content="@U0",
  )
  let values = model.universe_values(sort_u)
  inspect(values.length().to_string(), content="1")
  inspect(values[0].to_text(), content="@U0")
}

///|
test "pure_model_eval_int_constants_equalities_and_distinct" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let int_sort = test_int_sort(manager)
  let x = manager.declare_const("x", int_sort)
  let y = manager.declare_const("y", int_sort)
  let x_expr = manager.mk_app(x, [])
  let y_expr = manager.mk_app(y, [])
  model.add_value_const(x, int_sort, "Int", ModelValue::int(2), name="x")
  model.add_value_const(y, int_sort, "Int", ModelValue::int(3), name="y")
  inspect(
    model_value_text(model.eval(manager, x_expr, completion=false)),
    content="2",
  )
  inspect(
    model_value_text(
      model.eval(manager, manager.mk_eq(x_expr, x_expr), completion=false),
    ),
    content="true",
  )
  inspect(
    model_value_text(
      model.eval(manager, manager.mk_eq(x_expr, y_expr), completion=false),
    ),
    content="false",
  )
  inspect(
    model_value_text(
      model.eval(
        manager,
        manager.mk_distinct([x_expr, y_expr]),
        completion=false,
      ),
    ),
    content="true",
  )
}

///|
test "pure_model_eval_int_comparison_function_interpretation" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let int_sort = test_int_sort(manager)
  let x = manager.declare_const("x", int_sort)
  let y = manager.declare_const("y", int_sort)
  let lt = manager.declare_fun("<", [int_sort, int_sort], manager.bool_sort())
  let x_expr = manager.mk_app(x, [])
  let y_expr = manager.mk_app(y, [])
  model.add_value_const(x, int_sort, "Int", ModelValue::int(2), name="x")
  model.add_value_const(y, int_sort, "Int", ModelValue::int(3), name="y")
  let interp = FuncInterp::new("<", ["Int", "Int"], "Bool")
  interp.add_entry(["2", "3"], "true")
  interp.set_else("false")
  model.add_func_interp(lt, interp)
  inspect(
    model_value_text(
      model.eval(
        manager,
        manager.mk_app(lt, [x_expr, y_expr]),
        completion=false,
      ),
    ),
    content="true",
  )
  inspect(
    model_value_text(
      model.eval(
        manager,
        manager.mk_app(lt, [y_expr, x_expr]),
        completion=false,
      ),
    ),
    content="false",
  )
}

///|
test "pure_model_eval_ast_int_literals_and_comparisons" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let int_sort = test_int_sort(manager)
  let x = manager.declare_const("x", int_sort)
  let y = manager.declare_const("y", int_sort)
  let x_expr = manager.mk_app(x, [])
  let y_expr = manager.mk_app(y, [])
  model.add_value_const(x, int_sort, "Int", ModelValue::int(2), name="x")
  model.add_value_const(y, int_sort, "Int", ModelValue::int(3), name="y")
  inspect(
    model_value_text(
      model.eval(manager, manager.mk_lt(x_expr, y_expr), completion=false),
    ),
    content="true",
  )
  inspect(
    model_value_text(
      model.eval(manager, manager.mk_gt(x_expr, y_expr), completion=false),
    ),
    content="false",
  )
  inspect(
    model_value_text(
      model.eval(
        manager,
        manager.mk_le(manager.mk_int(4), manager.mk_int(4)),
        completion=false,
      ),
    ),
    content="true",
  )
}

///|
test "pure_model_eval_int_function_results_inside_ast_comparison" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let int_sort = test_int_sort(manager)
  let x = manager.declare_const("x", int_sort)
  let f = manager.declare_fun("f", [int_sort], int_sort)
  let x_expr = manager.mk_app(x, [])
  model.add_value_const(x, int_sort, "Int", ModelValue::int(2), name="x")
  let interp = FuncInterp::new("f", ["Int"], "Int")
  interp.add_entry(["2"], "3")
  model.add_func_interp(f, interp)
  inspect(
    model_value_text(
      model.eval(
        manager,
        manager.mk_lt(manager.mk_app(f, [x_expr]), manager.mk_int(4)),
        completion=false,
      ),
    ),
    content="true",
  )
}

///|
test "pure_model_eval_uses_function_interpretations_and_else" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = manager.declare_const("a", sort_u)
  let b = manager.declare_const("b", sort_u)
  let f = manager.declare_fun("f", [sort_u], sort_u)
  let interp = FuncInterp::new("f", ["U"], "U")
  interp.add_entry(["@U0"], "@hit")
  interp.set_else("@fallback")
  model.add_func_interp(f, interp)
  let f_a = manager.mk_app(f, [manager.mk_app(a, [])])
  let f_b = manager.mk_app(f, [manager.mk_app(b, [])])
  inspect(
    model_value_text(model.eval(manager, f_a, completion=true)),
    content="@hit",
  )
  inspect(
    model_value_text(model.eval(manager, f_b, completion=true)),
    content="@fallback",
  )
}

///|
test "pure_model_eval_function_interp_preserves_range_sort" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = manager.declare_const("a", sort_u)
  let f = manager.declare_fun("f", [sort_u], sort_u)
  let a_expr = manager.mk_app(a, [])
  ignore(model.eval(manager, a_expr, completion=true))
  let result = model.fresh_uninterpreted_value(sort_u, "U")
  let interp = FuncInterp::new("f", ["U"], "U")
  interp.add_entry(["@U0"], result.to_text())
  model.add_func_interp(f, interp)
  let f_a = manager.mk_app(f, [a_expr])
  match model.eval(manager, f_a, completion=false) {
    Some(value) => {
      inspect(value.to_text(), content="@U1")
      inspect(value.sort() == Some(sort_u), content="true")
    }
    None => inspect("missing", content="@U1")
  }
}

///|
test "pure_model_eval_completion_extends_partial_uf_function_interp" {
  let manager = @ast.AstManager::new()
  let model = Model::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = manager.declare_const("a", sort_u)
  let b = manager.declare_const("b", sort_u)
  let c = manager.declare_const("c", sort_u)
  let f = manager.declare_fun("f", [sort_u], sort_u)
  let a_expr = manager.mk_app(a, [])
  let b_expr = manager.mk_app(b, [])
  let c_expr = manager.mk_app(c, [])
  inspect(
    model_value_text(model.eval(manager, a_expr, completion=true)),
    content="@U0",
  )
  inspect(
    model_value_text(model.eval(manager, b_expr, completion=true)),
    content="@U1",
  )
  let interp = FuncInterp::new("f", ["U"], "U")
  interp.add_entry(["@U0"], "@U1")
  model.add_func_interp(f, interp)
  let f_c = manager.mk_app(f, [c_expr])
  inspect(
    model_value_text(model.eval(manager, f_c, completion=false)),
    content="missing",
  )
  inspect(
    model_value_text(model.eval(manager, f_c, completion=true)),
    content="@U3",
  )
  inspect(
    model_value_text(model.eval(manager, f_c, completion=false)),
    content="@U3",
  )
  let values = model.universe_values(sort_u)
  inspect(values.length().to_string(), content="4")
  inspect(values[2].to_text(), content="@U2")
  inspect(values[3].to_text(), content="@U3")
}
