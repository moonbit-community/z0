///|
fn model_builder_bool_const(
  manager : @ast.AstManager,
  name : String,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
fn model_builder_value_const(
  manager : @ast.AstManager,
  name : String,
  sort : @util.SortId,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, sort)
  manager.mk_app(decl, [])
}

///|
test "smt_model_builder_returns_pure_model_for_bool_assignment" {
  let manager = @ast.AstManager::new()
  let p = model_builder_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  match context.check_sat() {
    SmtContextSat(model) =>
      inspect(
        match model.eval(manager, p, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="true",
      )
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_collects_euf_value_dependencies_from_egraph_terms" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let context = SmtContext::new(manager)
  context.assert_expr(manager.mk_eq(a, a))
  match context.check_sat() {
    SmtContextSat(model) => {
      inspect(
        match model.eval(manager, a, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U0",
      )
      inspect(model.universe_values(sort_u).length(), content="1")
    }
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_reuses_euf_values_for_equal_egraph_terms" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let equality = manager.mk_eq(a, b)
  let context = SmtContext::new(manager)
  context.assert_expr(equality)
  match context.check_sat() {
    SmtContextSat(model) => {
      inspect(
        match model.eval(manager, a, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U0",
      )
      inspect(
        match model.eval(manager, b, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U0",
      )
      inspect(
        match model.eval(manager, equality, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="true",
      )
      inspect(model.universe_values(sort_u).length(), content="1")
    }
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_adds_unary_euf_function_entries_from_egraph_terms" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let f = manager.declare_fun("f", [sort_u], sort_u)
  let fa = manager.mk_app(f, [a])
  let equality = manager.mk_eq(fa, b)
  let context = SmtContext::new(manager)
  context.assert_expr(equality)
  match context.check_sat() {
    SmtContextSat(model) => {
      inspect(
        match model.eval(manager, b, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U1",
      )
      inspect(
        match model.eval(manager, fa, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U1",
      )
      inspect(
        match model.eval(manager, equality, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="true",
      )
      inspect(model.universe_values(sort_u).length(), content="2")
    }
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_orders_nested_function_interps_by_argument_dependencies" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let c = model_builder_value_const(manager, "c", sort_u)
  let f = manager.declare_fun("f", [sort_u], sort_u)
  let g = manager.declare_fun("g", [sort_u], sort_u)
  let fa = manager.mk_app(f, [a])
  let gfa = manager.mk_app(g, [fa])
  let context = SmtContext::new(manager)
  context.assert_expr(manager.mk_eq(fa, b))
  context.assert_expr(manager.mk_eq(gfa, c))
  match context.check_sat() {
    SmtContextSat(model) => {
      inspect(
        match model.eval(manager, gfa, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U2",
      )
      inspect(
        model.format(),
        content=(
          #|(
          #|  ;; universe U: @U0 @U1 @U2
          #|  (declare-fun @U0 () U)
          #|  (declare-fun @U1 () U)
          #|  (declare-fun @U2 () U)
          #|  ;; cardinality constraint for U
          #|  (forall ((x U)) (or (= x @U0) (= x @U1) (= x @U2)))
          #|  (define-fun a () U
          #|    @U0)
          #|  (define-fun b () U
          #|    @U1)
          #|  (define-fun c () U
          #|    @U2)
          #|  (define-fun f ((x0 U)) U
          #|    (ite (= x0 @U0)
          #|      @U1
          #|      #unspecified))
          #|  (define-fun g ((x0 U)) U
          #|    (ite (= x0 @U1)
          #|      @U2
          #|      #unspecified))
          #|)
        ),
      )
    }
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_assigns_values_to_partial_euf_function_apps" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let f = manager.declare_fun("f", [sort_u], sort_u)
  let fa = manager.mk_app(f, [a])
  let reflexive = manager.mk_eq(fa, fa)
  let context = SmtContext::new(manager)
  context.assert_expr(reflexive)
  match context.check_sat() {
    SmtContextSat(model) => {
      inspect(
        match model.eval(manager, a, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U0",
      )
      inspect(
        match model.eval(manager, fa, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U1",
      )
      inspect(
        match model.eval(manager, reflexive, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="true",
      )
      inspect(model.universe_values(sort_u).length(), content="2")
    }
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_leaves_partial_euf_function_interp_unspecified" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let c = model_builder_value_const(manager, "c", sort_u)
  let f = manager.declare_fun("f", [sort_u], sort_u)
  let fa = manager.mk_app(f, [a])
  let fc = manager.mk_app(f, [c])
  let context = SmtContext::new(manager)
  context.assert_expr(manager.mk_eq(fa, b))
  context.assert_expr(manager.mk_eq(c, c))
  match context.check_sat() {
    SmtContextSat(model) => {
      inspect(
        match model.eval(manager, fa, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U1",
      )
      inspect(
        match model.eval(manager, fc, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="missing",
      )
      inspect(model.universe_values(sort_u).length(), content="3")
    }
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_filters_function_interps_with_theory_hook" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let f = manager.declare_fun("f", [sort_u], sort_u)
  let fa = manager.mk_app(f, [a])
  let context = SmtContext::new(manager)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(41),
    "model-filter",
    [manager.uf_family()],
  )
  plugin.set_include_func_interp(fn(decl) { decl != f })
  context.register_theory(plugin)
  context.assert_expr(manager.mk_eq(fa, b))
  match context.check_sat() {
    SmtContextSat(model) => {
      inspect(
        match model.eval(manager, b, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="@U1",
      )
      inspect(
        match model.eval(manager, fa, completion=false) {
          Some(value) => value.to_text()
          None => "missing"
        },
        content="missing",
      )
    }
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_runs_theory_value_hooks_for_attached_euf_terms" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let context = SmtContext::new(manager)
  let theory_id = @theory_ids.TheoryId::new(42)
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    theory_id,
    "model-value-hooks",
    [manager.uf_family()],
  )
  plugin.set_model_add_dep(fn(_, _, term, dep) {
    log.push("dep:\{term}:\{dep.to_int()}")
  })
  plugin.set_mk_value(fn(_, _, term) {
    log.push("mk:\{term}")
    Some(a)
  })
  plugin.set_model_add_value(fn(_, _, term, value) {
    log.push("value:\{term}:\{value.to_int()}")
  })
  context.register_theory(plugin)
  context.attach_theory_var(a, theory_id, @theory_ids.TheoryVar::new(7))
  context.assert_expr(manager.mk_eq(a, a))
  match context.check_sat() {
    SmtContextSat(_) =>
      inspect(
        log.join(">"),
        content="dep:th#42:7:\{a.to_int()}>mk:th#42:7>value:th#42:7:\{a.to_int()}",
      )
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_uses_theory_mk_value_result_for_attached_euf_term" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let equality = manager.mk_eq(a, b)
  let context = SmtContext::new(manager)
  let theory_id = @theory_ids.TheoryId::new(44)
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    theory_id,
    "model-value-result",
    [manager.uf_family()],
  )
  plugin.set_model_add_dep(fn(_, _, term, dep) {
    log.push("dep:\{term}:\{dep.to_int()}")
  })
  plugin.set_mk_value(fn(_, _, term) {
    log.push("mk:\{term}")
    Some(b)
  })
  context.register_theory(plugin)
  context.attach_theory_var(a, theory_id, @theory_ids.TheoryVar::new(9))
  context.assert_expr(manager.mk_eq(a, a))
  context.assert_expr(manager.mk_eq(b, b))
  match context.check_sat() {
    SmtContextSat(model) => {
      let a_text = match model.eval(manager, a, completion=false) {
        Some(value) => value.to_text()
        None => "missing"
      }
      let b_text = match model.eval(manager, b, completion=false) {
        Some(value) => value.to_text()
        None => "missing"
      }
      let eq_text = match model.eval(manager, equality, completion=false) {
        Some(value) => value.to_text()
        None => "missing"
      }
      inspect("\{a_text}|\{b_text}|\{eq_text}", content="@U0|@U0|true")
      inspect(log.join(">"), content="dep:th#44:9:\{a.to_int()}>mk:th#44:9")
    }
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_rejects_conflicting_theory_mk_value_results" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let context = SmtContext::new(manager)
  let theory_a = @theory_ids.TheoryId::new(49)
  let theory_b = @theory_ids.TheoryId::new(50)
  let plugin_a = @theory_core.TheoryPlugin::default_unimplemented(
    theory_a,
    "model-value-conflict-a",
    [manager.uf_family()],
  )
  let plugin_b = @theory_core.TheoryPlugin::default_unimplemented(
    theory_b,
    "model-value-conflict-b",
    [manager.uf_family()],
  )
  plugin_a.set_mk_value(fn(_, _, _) { Some(a) })
  plugin_b.set_mk_value(fn(_, _, _) { Some(b) })
  context.register_theory(plugin_a)
  context.register_theory(plugin_b)
  context.attach_theory_var(a, theory_a, @theory_ids.TheoryVar::new(15))
  context.attach_theory_var(a, theory_b, @theory_ids.TheoryVar::new(16))
  context.assert_expr(manager.mk_eq(a, a))
  context.assert_expr(manager.mk_eq(b, b))
  match context.check_sat() {
    SmtContextSat(_) => inspect("sat", content="unknown:invalid-model")
    SmtContextUnsat => inspect("unsat", content="unknown:invalid-model")
    SmtContextUnknown(reason) =>
      inspect("unknown:\{reason}", content="unknown:invalid-model")
  }
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_model_builder_rejects_conflicting_theory_values_for_congruent_terms" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let c = model_builder_value_const(manager, "c", sort_u)
  let d = model_builder_value_const(manager, "d", sort_u)
  let context = SmtContext::new(manager)
  let theory_id = @theory_ids.TheoryId::new(52)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    theory_id,
    "model-value-class-conflict",
    [manager.uf_family()],
  )
  plugin.set_mk_value(fn(_, _, term) {
    if term.to_int() == 21 {
      Some(c)
    } else {
      Some(d)
    }
  })
  context.register_theory(plugin)
  context.attach_theory_var(a, theory_id, @theory_ids.TheoryVar::new(21))
  context.attach_theory_var(b, theory_id, @theory_ids.TheoryVar::new(22))
  context.assert_expr(manager.mk_eq(a, b))
  context.assert_expr(manager.mk_eq(c, c))
  context.assert_expr(manager.mk_eq(d, d))
  match context.check_sat() {
    SmtContextSat(_) => inspect("sat", content="unknown:invalid-model")
    SmtContextUnsat => inspect("unsat", content="unknown:invalid-model")
    SmtContextUnknown(reason) =>
      inspect("unknown:\{reason}", content="unknown:invalid-model")
  }
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_model_builder_orders_theory_value_construction_by_dependencies" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let context = SmtContext::new(manager)
  let theory_id = @theory_ids.TheoryId::new(48)
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    theory_id,
    "model-value-order",
    [manager.uf_family()],
  )
  plugin.set_model_add_dep(fn(_, _, term, dep) {
    log.push("dep:\{term}:\{dep.to_int()}")
  })
  plugin.set_mk_value(fn(_, _, term) {
    log.push("mk:\{term}")
    Some(b)
  })
  plugin.set_model_add_value(fn(_, _, term, value) {
    log.push("value:\{term}:\{value.to_int()}")
  })
  context.register_theory(plugin)
  context.attach_theory_var(a, theory_id, @theory_ids.TheoryVar::new(13))
  context.attach_theory_var(b, theory_id, @theory_ids.TheoryVar::new(14))
  context.assert_expr(manager.mk_eq(a, a))
  context.assert_expr(manager.mk_eq(b, b))
  match context.check_sat() {
    SmtContextSat(model) => {
      let a_text = match model.eval(manager, a, completion=false) {
        Some(value) => value.to_text()
        None => "missing"
      }
      let b_text = match model.eval(manager, b, completion=false) {
        Some(value) => value.to_text()
        None => "missing"
      }
      inspect("\{a_text}|\{b_text}", content="@U0|@U0")
      inspect(
        log.join(">"),
        content="dep:th#48:13:\{a.to_int()}>mk:th#48:13>dep:th#48:14:\{b.to_int()}>mk:th#48:14>value:th#48:14:\{b.to_int()}>value:th#48:13:\{b.to_int()}",
      )
    }
    SmtContextUnsat => inspect("unsat", content="sat")
    SmtContextUnknown(reason) => inspect("unknown:\{reason}", content="sat")
  }
}

///|
test "smt_model_builder_rejects_cyclic_theory_mk_value_dependencies" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let b = model_builder_value_const(manager, "b", sort_u)
  let context = SmtContext::new(manager)
  let theory_id = @theory_ids.TheoryId::new(51)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    theory_id,
    "model-value-cycle",
    [manager.uf_family()],
  )
  plugin.set_mk_value(fn(_, _, term) {
    if term.to_int() == 17 {
      Some(b)
    } else {
      Some(a)
    }
  })
  context.register_theory(plugin)
  context.attach_theory_var(a, theory_id, @theory_ids.TheoryVar::new(17))
  context.attach_theory_var(b, theory_id, @theory_ids.TheoryVar::new(18))
  context.assert_expr(manager.mk_eq(a, a))
  context.assert_expr(manager.mk_eq(b, b))
  match context.check_sat() {
    SmtContextSat(_) => inspect("sat", content="unknown:invalid-model")
    SmtContextUnsat => inspect("unsat", content="unknown:invalid-model")
    SmtContextUnknown(reason) =>
      inspect("unknown:\{reason}", content="unknown:invalid-model")
  }
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_model_builder_rejects_theory_mk_value_wrong_sort" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let p = model_builder_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  let theory_id = @theory_ids.TheoryId::new(45)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    theory_id,
    "model-value-wrong-sort",
    [manager.uf_family()],
  )
  plugin.set_mk_value(fn(_, _, _) { Some(p) })
  context.register_theory(plugin)
  context.attach_theory_var(a, theory_id, @theory_ids.TheoryVar::new(10))
  context.assert_expr(manager.mk_eq(a, a))
  context.assert_expr(p)
  match context.check_sat() {
    SmtContextSat(_) => inspect("sat", content="unknown:invalid-model")
    SmtContextUnsat => inspect("unsat", content="unknown:invalid-model")
    SmtContextUnknown(reason) =>
      inspect("unknown:\{reason}", content="unknown:invalid-model")
  }
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_model_builder_rejects_theory_value_construction_failure" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let context = SmtContext::new(manager)
  let theory_id = @theory_ids.TheoryId::new(43)
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    theory_id,
    "model-value-failure",
    [manager.uf_family()],
  )
  plugin.set_model_add_dep(fn(_, _, term, dep) {
    log.push("dep:\{term}:\{dep.to_int()}")
  })
  plugin.set_mk_value(fn(_, _, term) {
    log.push("mk:\{term}")
    None
  })
  context.register_theory(plugin)
  context.attach_theory_var(a, theory_id, @theory_ids.TheoryVar::new(8))
  context.assert_expr(manager.mk_eq(a, a))
  match context.check_sat() {
    SmtContextSat(_) => inspect("sat", content="unknown:invalid-model")
    SmtContextUnsat => inspect("unsat", content="unknown:invalid-model")
    SmtContextUnknown(reason) =>
      inspect("unknown:\{reason}", content="unknown:invalid-model")
  }
  inspect(log.join(">"), content="dep:th#43:8:\{a.to_int()}>mk:th#43:8")
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_model_builder_rejects_unowned_theory_value_attachment" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let context = SmtContext::new(manager)
  context.attach_theory_var(
    a,
    @theory_ids.TheoryId::new(46),
    @theory_ids.TheoryVar::new(11),
  )
  context.assert_expr(manager.mk_eq(a, a))
  match context.check_sat() {
    SmtContextSat(_) => inspect("sat", content="unknown:invalid-model")
    SmtContextUnsat => inspect("unsat", content="unknown:invalid-model")
    SmtContextUnknown(reason) =>
      inspect("unknown:\{reason}", content="unknown:invalid-model")
  }
  inspect(context.cache_state_text(), content="model=none")
}

///|
test "smt_model_builder_rejects_unevaluable_theory_mk_value_result" {
  let manager = @ast.AstManager::new()
  let sort_u = manager.declare_sort("U", 0)
  let a = model_builder_value_const(manager, "a", sort_u)
  let p = model_builder_bool_const(manager, "p")
  let f = manager.declare_fun("f", [manager.bool_sort()], sort_u)
  let fp = manager.mk_app(f, [p])
  let context = SmtContext::new(manager)
  let theory_id = @theory_ids.TheoryId::new(47)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    theory_id,
    "model-value-unevaluable",
    [manager.uf_family()],
  )
  plugin.set_mk_value(fn(_, _, _) { Some(fp) })
  context.register_theory(plugin)
  context.attach_theory_var(a, theory_id, @theory_ids.TheoryVar::new(12))
  context.assert_expr(manager.mk_eq(a, a))
  match context.check_sat() {
    SmtContextSat(_) => inspect("sat", content="unknown:invalid-model")
    SmtContextUnsat => inspect("unsat", content="unknown:invalid-model")
    SmtContextUnknown(reason) =>
      inspect("unknown:\{reason}", content="unknown:invalid-model")
  }
  inspect(context.cache_state_text(), content="model=none")
}
