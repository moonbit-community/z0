///|
fn sexpr_symbol(expr : SExpr) -> String? {
  match expr {
    SExpr::Atom(Atom::Symbol(name)) => Some(name)
    _ => None
  }
}

///|
fn escape_string(value : String) -> String {
  let sb = StringBuilder::new()
  for ch in value {
    match ch {
      '\\' => sb..write_string("\\\\")
      '"' => sb..write_string("\\\"")
      '\n' => sb..write_string("\\n")
      '\r' => sb..write_string("\\r")
      '\t' => sb..write_string("\\t")
      _ => sb..write_char(ch)
    }
  }
  sb.to_string()
}

///|
fn atom_to_smt2(atom : Atom) -> String {
  match atom {
    Atom::Symbol(name) => name
    Atom::Keyword(name) => name
    Atom::Numeral(n) => n
    Atom::Decimal(n) => n
    Atom::String(value) => "\"\{escape_string(value)}\""
    Atom::BitvectorBinary(value) => value
    Atom::BitvectorHex(value) => value
  }
}

///|
fn sexpr_to_smt2(expr : SExpr) -> String {
  match expr {
    SExpr::Atom(atom) => atom_to_smt2(atom)
    SExpr::List(items) =>
      if items.length() == 0 {
        "()"
      } else {
        let parts = items.map(sexpr_to_smt2).join(" ")
        "(\{parts})"
      }
  }
}

///|
fn sexpr_to_smt2_pretty(expr : SExpr) -> String {
  let flat = sexpr_to_smt2(expr)
  if flat.length() <= 80 {
    return flat
  }
  match expr {
    SExpr::List(items) =>
      if items.length() >= 2 {
        match sexpr_symbol(items[0]) {
          Some(head) =>
            if head == "and" || head == "or" {
              let indent = head.length() + 2
              let first = sexpr_to_smt2(items[1])
              let pad = " ".repeat(indent)
              let sb = StringBuilder::new()
              sb..write_string("(\{head} \{first}")
              for i in 2..<items.length() {
                sb..write_string("\n\{pad}\{sexpr_to_smt2(items[i])}")
              }
              sb..write_char(')')
              return sb.to_string()
            }
          _ => ()
        }
      }
    _ => ()
  }
  flat
}

///|
fn bound_var_entry(expr : SExpr) -> (SExpr, String?) {
  match expr {
    SExpr::List(items) =>
      if items.length() == 2 {
        match sexpr_symbol(items[0]) {
          Some(name) => (expr, Some(name))
          None => (expr, None)
        }
      } else {
        (expr, None)
      }
    _ => (expr, None)
  }
}

///|
fn bound_var_entries(expr : SExpr) -> Array[(SExpr, String?)] {
  match expr {
    SExpr::List(items) => {
      let entries : Array[(SExpr, String?)] = []
      for item in items {
        entries.push(bound_var_entry(item))
      }
      entries
    }
    _ => []
  }
}

///|
fn bound_var_names(entries : Array[(SExpr, String?)]) -> Array[String]? {
  let names : Array[String] = []
  for entry in entries {
    let (_, name_opt) = entry
    match name_opt {
      Some(name) => names.push(name)
      None => return None
    }
  }
  Some(names)
}

///|
fn has_collision(a : Array[String], b : Array[String]) -> Bool {
  let seen : Map[String, Bool] = Map::new()
  for name in a {
    seen[name] = true
  }
  for name in b {
    if seen.contains(name) {
      return true
    }
  }
  false
}

///|
fn contains_sexpr(items : Array[SExpr], value : SExpr) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
fn is_pattern_key(expr : SExpr) -> Bool {
  match expr {
    SExpr::Atom(Atom::Keyword(name)) => name == ":pattern"
    SExpr::Atom(Atom::Symbol(name)) => name == ":pattern"
    _ => false
  }
}

///|
fn is_bang(expr : SExpr) -> Bool {
  match expr {
    SExpr::List(items) =>
      if items.length() > 0 {
        match sexpr_symbol(items[0]) {
          Some("!") => true
          _ => false
        }
      } else {
        false
      }
    _ => false
  }
}

///|
fn collect_free_symbols(
  expr : SExpr,
  bound : Map[String, Bool],
  out : Map[String, Bool],
) -> Unit {
  match expr {
    SExpr::Atom(atom) =>
      match atom {
        Atom::Symbol(name) => if !bound.contains(name) { out[name] = true }
        _ => ()
      }
    SExpr::List(items) => {
      if items.length() == 0 {
        return
      }
      match sexpr_symbol(items[0]) {
        Some("forall") =>
          if items.length() >= 3 {
            let bound2 = bound.copy()
            match items[1] {
              SExpr::List(vars) =>
                for var_expr in vars {
                  let (_, name_opt) = bound_var_entry(var_expr)
                  match name_opt {
                    Some(name) => bound2[name] = true
                    None => ()
                  }
                }
              _ => ()
            }
            collect_free_symbols(items[2], bound2, out)
          } else {
            for item in items {
              collect_free_symbols(item, bound, out)
            }
          }
        Some("exists") =>
          if items.length() >= 3 {
            let bound2 = bound.copy()
            match items[1] {
              SExpr::List(vars) =>
                for var_expr in vars {
                  let (_, name_opt) = bound_var_entry(var_expr)
                  match name_opt {
                    Some(name) => bound2[name] = true
                    None => ()
                  }
                }
              _ => ()
            }
            collect_free_symbols(items[2], bound2, out)
          } else {
            for item in items {
              collect_free_symbols(item, bound, out)
            }
          }
        Some("let") =>
          if items.length() >= 3 {
            let bound2 = bound.copy()
            match items[1] {
              SExpr::List(bindings) =>
                for binding in bindings {
                  match binding {
                    SExpr::List(pair) =>
                      if pair.length() >= 2 {
                        collect_free_symbols(pair[1], bound, out)
                        match sexpr_symbol(pair[0]) {
                          Some(name) => bound2[name] = true
                          None => ()
                        }
                      } else {
                        collect_free_symbols(binding, bound, out)
                      }
                    _ => collect_free_symbols(binding, bound, out)
                  }
                }
              _ => collect_free_symbols(items[1], bound, out)
            }
            collect_free_symbols(items[2], bound2, out)
          } else {
            for item in items {
              collect_free_symbols(item, bound, out)
            }
          }
        Some("!") =>
          if items.length() >= 2 {
            collect_free_symbols(items[1], bound, out)
            let mut i = 2
            while i < items.length() {
              if i + 1 < items.length() {
                collect_free_symbols(items[i + 1], bound, out)
                i += 2
              } else {
                collect_free_symbols(items[i], bound, out)
                i += 1
              }
            }
          } else {
            for item in items {
              collect_free_symbols(item, bound, out)
            }
          }
        Some(_) =>
          for i in 1..<items.length() {
            collect_free_symbols(items[i], bound, out)
          }
        None =>
          for item in items {
            collect_free_symbols(item, bound, out)
          }
      }
    }
  }
}

///|
fn free_symbols(expr : SExpr) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map::new()
  collect_free_symbols(expr, Map::new(), out)
  out
}

///|
fn simplify_bang(items : Array[SExpr]) -> SExpr {
  if items.length() < 2 {
    let new_items : Array[SExpr] = []
    for item in items {
      new_items.push(simplify_sexpr(item))
    }
    return SExpr::List(new_items)
  }
  let term = simplify_sexpr(items[1])
  let attrs : Array[SExpr] = []
  let seen_patterns : Array[SExpr] = []
  let mut i = 2
  while i < items.length() {
    if i + 1 >= items.length() {
      attrs.push(simplify_sexpr(items[i]))
      break
    }
    let key = items[i]
    let value = simplify_sexpr(items[i + 1])
    if is_pattern_key(key) {
      if !contains_sexpr(seen_patterns, value) {
        seen_patterns.push(value)
        attrs.push(key)
        attrs.push(value)
      }
    } else {
      attrs.push(key)
      attrs.push(value)
    }
    i += 2
  }
  if attrs.length() == 0 {
    term
  } else {
    let new_items : Array[SExpr] = [items[0], term]
    for attr in attrs {
      new_items.push(attr)
    }
    SExpr::List(new_items)
  }
}

///|
fn simplify_let(items : Array[SExpr]) -> SExpr {
  if items.length() != 3 {
    let new_items : Array[SExpr] = []
    for item in items {
      new_items.push(simplify_sexpr(item))
    }
    return SExpr::List(new_items)
  }
  let bindings = match items[1] {
    SExpr::List(bindings_items) => {
      let new_bindings : Array[SExpr] = []
      for binding in bindings_items {
        match binding {
          SExpr::List(pair) =>
            if pair.length() == 2 {
              let name = pair[0]
              let value = simplify_sexpr(pair[1])
              new_bindings.push(SExpr::List([name, value]))
            } else {
              let new_pair : Array[SExpr] = []
              for item in pair {
                new_pair.push(simplify_sexpr(item))
              }
              new_bindings.push(SExpr::List(new_pair))
            }
          _ => new_bindings.push(simplify_sexpr(binding))
        }
      }
      SExpr::List(new_bindings)
    }
    _ => simplify_sexpr(items[1])
  }
  let body = simplify_sexpr(items[2])
  SExpr::List([items[0], bindings, body])
}

///|
fn simplify_quantifier(kind : String, items : Array[SExpr]) -> SExpr {
  if items.length() != 3 {
    let new_items : Array[SExpr] = []
    for item in items {
      new_items.push(simplify_sexpr(item))
    }
    return SExpr::List(new_items)
  }
  let vars_expr = items[1]
  let body0 = simplify_sexpr(items[2])
  match vars_expr {
    SExpr::List(_) => {
      let mut vars_entries = bound_var_entries(vars_expr)
      let mut body = body0
      let mut changed = true
      while changed {
        changed = false
        match body {
          SExpr::List(inner_items) =>
            if inner_items.length() == 3 {
              match sexpr_symbol(inner_items[0]) {
                Some(inner_kind) =>
                  if inner_kind == kind {
                    let inner_vars_expr = inner_items[1]
                    let inner_body = inner_items[2]
                    if !is_bang(inner_body) {
                      match inner_vars_expr {
                        SExpr::List(_) => {
                          let inner_entries = bound_var_entries(inner_vars_expr)
                          match
                            (
                              bound_var_names(vars_entries),
                              bound_var_names(inner_entries),
                            ) {
                            (Some(outer_names), Some(inner_names)) =>
                              if !has_collision(outer_names, inner_names) {
                                let merged : Array[(SExpr, String?)] = []
                                for entry in vars_entries {
                                  merged.push(entry)
                                }
                                for entry in inner_entries {
                                  merged.push(entry)
                                }
                                vars_entries = merged
                                body = inner_body
                                changed = true
                              }
                            _ => ()
                          }
                        }
                        _ => ()
                      }
                    }
                  }
                _ => ()
              }
            }
          _ => ()
        }
      }
      let used = free_symbols(body)
      let new_vars : Array[SExpr] = []
      for entry in vars_entries {
        let (var_expr, name_opt) = entry
        match name_opt {
          Some(name) => if used.contains(name) { new_vars.push(var_expr) }
          None => new_vars.push(var_expr)
        }
      }
      if new_vars.length() == 0 {
        body
      } else {
        SExpr::List([items[0], SExpr::List(new_vars), body])
      }
    }
    _ => SExpr::List([items[0], simplify_sexpr(vars_expr), body0])
  }
}

///|
fn simplify_sexpr(expr : SExpr) -> SExpr {
  match expr {
    SExpr::Atom(_) => expr
    SExpr::List(items) =>
      if items.length() == 0 {
        expr
      } else {
        match sexpr_symbol(items[0]) {
          Some("forall") => simplify_quantifier("forall", items)
          Some("exists") => simplify_quantifier("exists", items)
          Some("let") => simplify_let(items)
          Some("!") => simplify_bang(items)
          Some(_) => {
            let new_items : Array[SExpr] = [items[0]]
            for i in 1..<items.length() {
              new_items.push(simplify_sexpr(items[i]))
            }
            SExpr::List(new_items)
          }
          None => {
            let new_items : Array[SExpr] = []
            for item in items {
              new_items.push(simplify_sexpr(item))
            }
            SExpr::List(new_items)
          }
        }
      }
  }
}

///|
fn symbol_expr(name : String) -> SExpr {
  SExpr::Atom(Atom::Symbol(name))
}

///|
fn sexpr_is_symbol(expr : SExpr, name : String) -> Bool {
  match sexpr_symbol(expr) {
    Some(value) => value == name
    None => false
  }
}

///|
fn sexpr_true() -> SExpr {
  symbol_expr("true")
}

///|
fn sexpr_false() -> SExpr {
  symbol_expr("false")
}

///|
fn sexpr_is_true(expr : SExpr) -> Bool {
  sexpr_is_symbol(expr, "true")
}

///|
fn sexpr_is_false(expr : SExpr) -> Bool {
  sexpr_is_symbol(expr, "false")
}

///|
fn parse_bool_literal(expr : SExpr) -> Bool? {
  match sexpr_symbol(expr) {
    Some("true") => Some(true)
    Some("false") => Some(false)
    _ => None
  }
}

///|
fn parse_int_literal(expr : SExpr) -> Int? {
  match expr {
    SExpr::Atom(Atom::Numeral(n)) =>
      Some(@strconv.parse_int(n)) catch {
        _ => None
      }
    SExpr::List(items) =>
      if items.length() == 2 && sexpr_is_symbol(items[0], "-") {
        match items[1] {
          SExpr::Atom(Atom::Numeral(n)) =>
            Some(-@strconv.parse_int(n)) catch {
              _ => None
            }
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn int_literal_expr(value : Int) -> SExpr {
  if value >= 0 {
    SExpr::Atom(Atom::Numeral(value.to_string()))
  } else {
    let abs_value = (-value).to_string()
    SExpr::List([symbol_expr("-"), SExpr::Atom(Atom::Numeral(abs_value))])
  }
}

///|
fn parse_add_symbol_const(expr : SExpr) -> (String, Int)? {
  match expr {
    SExpr::List(items) =>
      if items.length() == 3 && sexpr_is_symbol(items[0], "+") {
        match (sexpr_symbol(items[1]), parse_int_literal(items[2])) {
          (Some(sym), Some(k)) => Some((sym, k))
          _ =>
            match (sexpr_symbol(items[2]), parse_int_literal(items[1])) {
              (Some(sym), Some(k)) => Some((sym, k))
              _ => None
            }
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn add_const_to_symbol(offset : Int, sym : String) -> SExpr {
  if offset == 0 {
    symbol_expr(sym)
  } else {
    let offset_expr = int_literal_expr(offset)
    SExpr::List([symbol_expr("+"), offset_expr, symbol_expr(sym)])
  }
}

///|
fn simplify_eq(lhs : SExpr, rhs : SExpr) -> SExpr {
  if lhs == rhs {
    return sexpr_true()
  }
  match (parse_add_symbol_const(lhs), sexpr_symbol(rhs)) {
    (Some((sym, k)), Some(name)) =>
      if sym == name {
        if k == 0 {
          sexpr_true()
        } else {
          sexpr_false()
        }
      } else {
        let shifted = add_const_to_symbol(-k, name)
        SExpr::List([symbol_expr("="), symbol_expr(sym), shifted])
      }
    _ =>
      match (parse_add_symbol_const(rhs), sexpr_symbol(lhs)) {
        (Some((sym, k)), Some(name)) =>
          if sym == name {
            if k == 0 {
              sexpr_true()
            } else {
              sexpr_false()
            }
          } else {
            let shifted = add_const_to_symbol(-k, name)
            SExpr::List([symbol_expr("="), symbol_expr(sym), shifted])
          }
        _ => SExpr::List([symbol_expr("="), lhs, rhs])
      }
  }
}

///|
fn simplify_bool_expr_impl(expr : SExpr, rewrite_eq : Bool) -> SExpr {
  match expr {
    SExpr::Atom(_) => expr
    SExpr::List(items) =>
      if items.length() == 0 {
        expr
      } else {
        match sexpr_symbol(items[0]) {
          Some("not") =>
            if items.length() == 2 {
              let inner = simplify_bool_expr_impl(items[1], rewrite_eq)
              if sexpr_is_true(inner) {
                sexpr_false()
              } else if sexpr_is_false(inner) {
                sexpr_true()
              } else {
                match inner {
                  SExpr::List(inner_items) =>
                    if inner_items.length() == 2 &&
                      sexpr_is_symbol(inner_items[0], "not") {
                      inner_items[1]
                    } else {
                      SExpr::List([symbol_expr("not"), inner])
                    }
                  _ => SExpr::List([symbol_expr("not"), inner])
                }
              }
            } else {
              let new_items : Array[SExpr] = [items[0]]
              for i in 1..<items.length() {
                new_items.push(simplify_bool_expr_impl(items[i], rewrite_eq))
              }
              SExpr::List(new_items)
            }
          Some("and") => {
            let args : Array[SExpr] = []
            for i in 1..<items.length() {
              let arg = simplify_bool_expr_impl(items[i], rewrite_eq)
              if sexpr_is_false(arg) {
                return sexpr_false()
              }
              if !sexpr_is_true(arg) {
                args.push(arg)
              }
            }
            if args.length() == 0 {
              sexpr_true()
            } else if args.length() == 1 {
              args[0]
            } else {
              let new_items : Array[SExpr] = [symbol_expr("and")]
              for arg in args {
                new_items.push(arg)
              }
              SExpr::List(new_items)
            }
          }
          Some("or") => {
            let args : Array[SExpr] = []
            for i in 1..<items.length() {
              let arg = simplify_bool_expr_impl(items[i], rewrite_eq)
              if sexpr_is_true(arg) {
                return sexpr_true()
              }
              if !sexpr_is_false(arg) {
                args.push(arg)
              }
            }
            if args.length() == 0 {
              sexpr_false()
            } else if args.length() == 1 {
              args[0]
            } else {
              let new_items : Array[SExpr] = [symbol_expr("or")]
              for arg in args {
                new_items.push(arg)
              }
              SExpr::List(new_items)
            }
          }
          Some("=") =>
            if items.length() == 3 {
              let lhs = simplify_bool_expr_impl(items[1], rewrite_eq)
              let rhs = simplify_bool_expr_impl(items[2], rewrite_eq)
              if rewrite_eq {
                simplify_eq(lhs, rhs)
              } else {
                SExpr::List([symbol_expr("="), lhs, rhs])
              }
            } else {
              let new_items : Array[SExpr] = [items[0]]
              for i in 1..<items.length() {
                new_items.push(simplify_bool_expr_impl(items[i], rewrite_eq))
              }
              SExpr::List(new_items)
            }
          Some(_) => {
            let new_items : Array[SExpr] = [items[0]]
            for i in 1..<items.length() {
              new_items.push(simplify_bool_expr_impl(items[i], rewrite_eq))
            }
            SExpr::List(new_items)
          }
          None => {
            let new_items : Array[SExpr] = []
            for item in items {
              new_items.push(simplify_bool_expr_impl(item, rewrite_eq))
            }
            SExpr::List(new_items)
          }
        }
      }
  }
}

///|
fn simplify_bool_expr(expr : SExpr) -> SExpr {
  simplify_bool_expr_impl(expr, true)
}

///|
fn simplify_bool_shape(expr : SExpr) -> SExpr {
  simplify_bool_expr_impl(expr, false)
}

///|
fn blast_distinct(expr : SExpr) -> SExpr {
  match expr {
    SExpr::Atom(_) => expr
    SExpr::List(items) =>
      if items.length() == 0 {
        expr
      } else {
        match sexpr_symbol(items[0]) {
          Some("distinct") =>
            if items.length() <= 2 {
              sexpr_true()
            } else {
              let args : Array[SExpr] = []
              for i in 1..<items.length() {
                args.push(blast_distinct(items[i]))
              }
              let clauses : Array[SExpr] = []
              for i in 0..<args.length() {
                for j in (i + 1)..<args.length() {
                  let eq_expr = SExpr::List([symbol_expr("="), args[i], args[j]])
                  clauses.push(SExpr::List([symbol_expr("not"), eq_expr]))
                }
              }
              let new_items : Array[SExpr] = [symbol_expr("and")]
              for clause in clauses {
                new_items.push(clause)
              }
              SExpr::List(new_items)
            }
          Some(_) => {
            let new_items : Array[SExpr] = [items[0]]
            for i in 1..<items.length() {
              new_items.push(blast_distinct(items[i]))
            }
            SExpr::List(new_items)
          }
          None => {
            let new_items : Array[SExpr] = []
            for item in items {
              new_items.push(blast_distinct(item))
            }
            SExpr::List(new_items)
          }
        }
      }
  }
}

///|
fn elim_and(expr : SExpr) -> SExpr {
  match expr {
    SExpr::Atom(_) => expr
    SExpr::List(items) =>
      if items.length() == 0 {
        expr
      } else {
        match sexpr_symbol(items[0]) {
          Some("and") =>
            if items.length() > 1 {
              let args : Array[SExpr] = []
              for i in 1..<items.length() {
                args.push(elim_and(items[i]))
              }
              let negs : Array[SExpr] = []
              for arg in args {
                negs.push(SExpr::List([symbol_expr("not"), arg]))
              }
              let or_items : Array[SExpr] = [symbol_expr("or")]
              for item in negs {
                or_items.push(item)
              }
              SExpr::List([symbol_expr("not"), SExpr::List(or_items)])
            } else {
              SExpr::List(items)
            }
          Some(_) => {
            let new_items : Array[SExpr] = [items[0]]
            for i in 1..<items.length() {
              new_items.push(elim_and(items[i]))
            }
            SExpr::List(new_items)
          }
          None => {
            let new_items : Array[SExpr] = []
            for item in items {
              new_items.push(elim_and(item))
            }
            SExpr::List(new_items)
          }
        }
      }
  }
}

///|
fn option_bool(opts : Array[SExpr], key : String) -> Bool {
  let mut result = false
  let mut i = 0
  while i < opts.length() {
    match opts[i] {
      SExpr::Atom(Atom::Keyword(name)) =>
        if name == key {
          if i + 1 < opts.length() {
            match parse_bool_literal(opts[i + 1]) {
              Some(value) => result = value
              None => ()
            }
            i += 2
          } else {
            i += 1
          }
        } else {
          i += 1
        }
      _ => i += 1
    }
  }
  result
}

///|
fn simplify_with_options(expr : SExpr, opts : Array[SExpr]) -> SExpr {
  let mut out = simplify_sexpr(expr)
  if option_bool(opts, ":blast-distinct") {
    out = blast_distinct(out)
  }
  out = simplify_bool_expr(out)
  if option_bool(opts, ":elim-and") {
    out = elim_and(out)
    out = simplify_bool_shape(out)
  }
  out
}
