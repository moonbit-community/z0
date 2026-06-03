///|
fn sexpr_as_atom(expr : SExpr) -> String? {
  match expr {
    Atom(value, _) => Some(value)
    _ => None
  }
}

///|
fn sexpr_as_list(expr : SExpr) -> Array[SExpr]? {
  match expr {
    List(items, _) => Some(items)
    _ => None
  }
}

///|
fn unsupported_operator(
  op : String,
) -> Unit raise @unsupported_error.UnsupportedError {
  if op == "forall" || op == "exists" {
    raise @unsupported_error.UnsupportedError(
      "quantifiers are not supported in Bool+EUF milestone",
      None,
    )
  } else if op == "match" || op == "as" {
    raise @unsupported_error.UnsupportedError(
      "datatypes are not supported in Bool+EUF milestone",
      None,
    )
  } else if op == "!" || op == "par" {
    raise @unsupported_error.UnsupportedError(
      "reserved identifiers are not supported in Bool+EUF milestone",
      None,
    )
  } else if op == "+" || op == "-" || op == "*" || op == "/" {
    raise @unsupported_error.UnsupportedError(
      "arithmetic is not supported in Bool+EUF milestone",
      None,
    )
  } else if op.has_prefix("bv") {
    raise @unsupported_error.UnsupportedError(
      "bit-vectors are not supported in Bool+EUF milestone",
      None,
    )
  } else if op.has_prefix("str.") || op.has_prefix("re.") {
    raise @unsupported_error.UnsupportedError(
      "strings are not supported in Bool+EUF milestone",
      None,
    )
  } else if op == "select" || op == "store" {
    raise @unsupported_error.UnsupportedError(
      "arrays are not supported in Bool+EUF milestone",
      None,
    )
  }
}

///|
fn parse_int_atom(symbol : String) -> Int? {
  if symbol.is_empty() {
    None
  } else {
    let mut value = 0
    for c in symbol {
      if c < '0' || c > '9' {
        return None
      }
      value = value * 10 + (c.to_int() - '0'.to_int())
    }
    Some(value)
  }
}

///|
fn arith_compare_op(op : String) -> @ast.ArithCompareOp? {
  match op {
    "<" => Some(@ast.Lt)
    "<=" => Some(@ast.Le)
    ">" => Some(@ast.Gt)
    ">=" => Some(@ast.Ge)
    _ => None
  }
}

///|
fn indexed_bv_operator(op : String) -> Bool {
  op == "extract" ||
  op == "zero_extend" ||
  op == "sign_extend" ||
  op == "repeat" ||
  op == "rotate_left" ||
  op == "rotate_right" ||
  op.has_prefix("bv")
}

///|
fn reject_unsupported_indexed_term_head(head : SExpr) -> Unit raise {
  match head {
    List([Atom("_", _), Atom(op, _), ..], _) =>
      if indexed_bv_operator(op) {
        raise @unsupported_error.UnsupportedError(
          "bit-vectors are not supported in Bool+EUF milestone",
          None,
        )
      }
    _ => ()
  }
}

///|
fn parse_term_args(
  manager : @ast.AstManager,
  args : ArrayView[SExpr],
) -> Array[@util.ExprId] raise {
  let parsed : Array[@util.ExprId] = []
  for arg in args {
    parsed.push(parse_term(manager, arg))
  }
  parsed
}

///|
fn parse_let_binding(
  manager : @ast.AstManager,
  expr : SExpr,
) -> (String, @util.ExprId) raise {
  match sexpr_as_list(expr) {
    Some([Atom(name, _), body]) => (name, parse_term(manager, body))
    _ => raise @parse_error.ParseError("malformed let binding", None)
  }
}

///|
fn let_binding_name_exists(
  bindings : Array[(String, @util.ExprId)],
  name : String,
) -> Bool {
  for binding in bindings {
    let (existing, _) = binding
    if existing == name {
      return true
    }
  }
  false
}

///|
fn parse_let_bindings(
  manager : @ast.AstManager,
  expr : SExpr,
) -> Array[(String, @util.ExprId)] raise {
  match sexpr_as_list(expr) {
    None => raise @parse_error.ParseError("let bindings must be a list", None)
    Some(items) => {
      let bindings : Array[(String, @util.ExprId)] = []
      for item in items {
        let binding = parse_let_binding(manager, item)
        let (name, _) = binding
        if let_binding_name_exists(bindings, name) {
          raise @parse_error.ParseError("duplicate let binding: \{name}", None)
        } else {
          bindings.push(binding)
        }
      }
      bindings
    }
  }
}

///|
fn parse_scoped_let_body(
  manager : @ast.AstManager,
  bindings : Array[(String, @util.ExprId)],
  body : SExpr,
) -> @util.ExprId raise {
  manager.push_scope()
  try {
    for binding in bindings {
      let (name, expr) = binding
      manager.define_scoped_macro(name, expr)
    }
    let parsed_body = parse_term(manager, body)
    let expanded_body = manager.expand_macros(parsed_body).result()
    manager.pop_scope(1)
    expanded_body
  } catch {
    err => {
      manager.pop_scope(1) catch {
        _ => ()
      }
      raise err
    }
  }
}

///|
fn parse_let_term(
  manager : @ast.AstManager,
  items : Array[SExpr],
) -> @util.ExprId raise {
  if items.length() != 3 {
    raise @parse_error.ParseError("let expects bindings and body", None)
  } else {
    let bindings = parse_let_bindings(manager, items[1])
    parse_scoped_let_body(manager, bindings, items[2])
  }
}

///|
fn parse_symbol_term(
  manager : @ast.AstManager,
  symbol : String,
) -> @util.ExprId raise {
  if symbol.has_prefix("#x") || symbol.has_prefix("#b") {
    raise @unsupported_error.UnsupportedError(
      "bit-vectors are not supported in Bool+EUF milestone",
      None,
    )
  } else {
    match parse_int_atom(symbol) {
      Some(value) => return manager.mk_int(value)
      None => ()
    }
  }
  if symbol == "true" {
    manager.mk_bool(true)
  } else if symbol == "false" {
    manager.mk_bool(false)
  } else {
    match manager.lookup_macro(symbol) {
      Some(_) => manager.mk_macro_ref(symbol)
      None =>
        match manager.lookup_decl(symbol) {
          None =>
            raise @type_error.TypeError("undeclared symbol: \{symbol}", None)
          Some(decl) => manager.mk_app(decl, [])
        }
    }
  }
}

///|
fn parse_list_term(
  manager : @ast.AstManager,
  items : Array[SExpr],
) -> @util.ExprId raise {
  if items.is_empty() {
    raise @parse_error.ParseError("empty term list", None)
  } else {
    reject_unsupported_indexed_term_head(items[0])
    match sexpr_as_atom(items[0]) {
      None => raise @parse_error.ParseError("term head must be a symbol", None)
      Some(op) => {
        unsupported_operator(op)
        match op {
          "<" | "<=" | ">" | ">=" =>
            if items.length() == 3 {
              match arith_compare_op(op) {
                Some(compare_op) =>
                  manager.mk_arith_compare(
                    compare_op,
                    parse_term(manager, items[1]),
                    parse_term(manager, items[2]),
                  )
                None => abort("unreachable arithmetic comparison")
              }
            } else {
              raise @parse_error.ParseError("\{op} expects two arguments", None)
            }
          "let" => parse_let_term(manager, items)
          "not" =>
            if items.length() == 2 {
              manager.mk_not(parse_term(manager, items[1]))
            } else {
              raise @parse_error.ParseError("not expects one argument", None)
            }
          "and" => manager.mk_and(parse_term_args(manager, items[1:]))
          "or" => manager.mk_or(parse_term_args(manager, items[1:]))
          "=>" =>
            if items.length() == 3 {
              manager.mk_implies(
                parse_term(manager, items[1]),
                parse_term(manager, items[2]),
              )
            } else {
              raise @parse_error.ParseError("=> expects two arguments", None)
            }
          "xor" =>
            if items.length() == 3 {
              manager.mk_xor(
                parse_term(manager, items[1]),
                parse_term(manager, items[2]),
              )
            } else {
              raise @parse_error.ParseError("xor expects two arguments", None)
            }
          "=" =>
            if items.length() == 3 {
              manager.mk_eq(
                parse_term(manager, items[1]),
                parse_term(manager, items[2]),
              )
            } else {
              raise @parse_error.ParseError("= expects two arguments", None)
            }
          "distinct" => manager.mk_distinct(parse_term_args(manager, items[1:]))
          _ =>
            match manager.lookup_decl(op) {
              None =>
                raise @type_error.TypeError("unknown function: \{op}", None)
              Some(decl) =>
                manager.mk_app(decl, parse_term_args(manager, items[1:]))
            }
        }
      }
    }
  }
}

///|
pub fn parse_term(
  manager : @ast.AstManager,
  expr : SExpr,
) -> @util.ExprId raise {
  match expr {
    Atom(symbol, _) => parse_symbol_term(manager, symbol)
    StringLit(_, _) =>
      raise @unsupported_error.UnsupportedError(
        "strings are not supported in Bool+EUF milestone",
        None,
      )
    List(items, _) => parse_list_term(manager, items)
  }
}
