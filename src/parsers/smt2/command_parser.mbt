///|
fn parse_nonnegative_int(text : String) -> Int? {
  if text.is_empty() {
    None
  } else {
    let mut value = 0
    for c in text {
      if c < '0' || c > '9' {
        return None
      }
      value = value * 10 + (c.to_int() - '0'.to_int())
    }
    Some(value)
  }
}

///|
fn atom_or_error(
  expr : SExpr,
  what : String,
) -> String raise @parse_error.ParseError {
  match sexpr_as_atom(expr) {
    Some(atom) => atom
    None => raise @parse_error.ParseError("\{what} must be a symbol", None)
  }
}

///|
fn reject_unsupported_sort(expr : SExpr) -> Unit raise {
  match expr {
    Atom("String", _) =>
      raise @unsupported_error.UnsupportedError(
        "strings are not supported in Bool+EUF milestone",
        None,
      )
    List([Atom("Array", _), ..], _) =>
      raise @unsupported_error.UnsupportedError(
        "arrays are not supported in Bool+EUF milestone",
        None,
      )
    List([Atom("_", _), Atom("BitVec", _), ..], _) =>
      raise @unsupported_error.UnsupportedError(
        "bit-vectors are not supported in Bool+EUF milestone",
        None,
      )
    List([Atom("Seq", _), ..], _) =>
      raise @unsupported_error.UnsupportedError(
        "strings are not supported in Bool+EUF milestone",
        None,
      )
    _ => ()
  }
}

///|
fn parse_sort(manager : @ast.AstManager, expr : SExpr) -> @util.SortId raise {
  reject_unsupported_sort(expr)
  match sexpr_as_atom(expr) {
    Some("Bool") => manager.bool_sort()
    Some(name) =>
      match manager.lookup_sort(name) {
        Some(sort) => sort
        None => raise @type_error.TypeError("unknown sort: \{name}", None)
      }
    None => raise @parse_error.ParseError("sort must be a symbol", None)
  }
}

///|
fn parse_sort_list(
  manager : @ast.AstManager,
  expr : SExpr,
) -> Array[@util.SortId] raise {
  match sexpr_as_list(expr) {
    None => raise @parse_error.ParseError("domain must be a sort list", None)
    Some(items) => {
      let sorts : Array[@util.SortId] = []
      for item in items {
        sorts.push(parse_sort(manager, item))
      }
      sorts
    }
  }
}

///|
fn parse_count(
  items : Array[SExpr],
  command : String,
) -> Int raise @parse_error.ParseError {
  if items.length() == 1 {
    1
  } else if items.length() == 2 {
    let text = atom_or_error(items[1], "\{command} count")
    match parse_nonnegative_int(text) {
      Some(count) => count
      None =>
        raise @parse_error.ParseError(
          "\{command} count must be non-negative",
          None,
        )
    }
  } else {
    raise @parse_error.ParseError("\{command} expects zero or one count", None)
  }
}

///|
fn parse_option_value(expr : SExpr) -> String raise @parse_error.ParseError {
  match expr {
    Atom(value, _) | StringLit(value, _) => value
    List(_, _) =>
      raise @parse_error.ParseError("option value must be atomic", None)
  }
}

///|
fn parse_define_params(
  manager : @ast.AstManager,
  expr : SExpr,
) -> Array[(String, @util.SortId)] raise {
  match sexpr_as_list(expr) {
    None =>
      raise @parse_error.ParseError("define-fun params must be a list", None)
    Some(items) =>
      if items.is_empty() {
        []
      } else {
        let params : Array[(String, @util.SortId)] = []
        for item in items {
          match sexpr_as_list(item) {
            Some([Atom(name, _), sort_expr]) =>
              params.push((name, parse_sort(manager, sort_expr)))
            _ =>
              raise @parse_error.ParseError(
                "malformed define-fun parameter",
                None,
              )
          }
        }
        params
      }
  }
}

///|
fn parse_assert_command(
  manager : @ast.AstManager,
  expr : SExpr,
) -> @cmd_context.Command raise {
  match sexpr_as_list(expr) {
    Some([Atom("!", _), term, Atom(":named", _), Atom(name, _)]) =>
      @cmd_context.AssertNamed(parse_term(manager, term), name)
    Some([Atom("!", _), ..]) =>
      raise @parse_error.ParseError(
        "assert annotation supports only :named",
        None,
      )
    _ => @cmd_context.Assert(parse_term(manager, expr))
  }
}

///|
fn parse_assumption_list(
  manager : @ast.AstManager,
  expr : SExpr,
) -> Array[@util.ExprId] raise {
  match sexpr_as_list(expr) {
    None =>
      raise @parse_error.ParseError(
        "check-sat-assuming expects an assumption list",
        None,
      )
    Some(items) => parse_term_args(manager, items[:])
  }
}

///|
fn smt2_quote_string(value : String) -> String {
  let builder = StringBuilder::new()
  builder.write_char('"')
  for c in value {
    if c == '"' {
      builder.write_string("\\\"")
    } else if c == '\\' {
      builder.write_string("\\\\")
    } else {
      builder.write_char(c)
    }
  }
  builder.write_char('"')
  builder.to_string()
}

///|
fn sexpr_to_smt2(expr : SExpr) -> String {
  match expr {
    Atom(value, _) => value
    StringLit(value, _) => smt2_quote_string(value)
    List(items, _) => {
      let builder = StringBuilder::new()
      builder.write_char('(')
      for i in 0..<items.length() {
        if i > 0 {
          builder.write_char(' ')
        }
        builder.write_string(sexpr_to_smt2(items[i]))
      }
      builder.write_char(')')
      builder.to_string()
    }
  }
}

///|
fn parse_get_value_terms(
  manager : @ast.AstManager,
  expr : SExpr,
) -> Array[@cmd_context.ModelQueryTerm] raise {
  match sexpr_as_list(expr) {
    None => raise @parse_error.ParseError("get-value expects a term list", None)
    Some(items) => {
      let terms : Array[@cmd_context.ModelQueryTerm] = []
      for item in items {
        terms.push(
          @cmd_context.ModelQueryTerm::new(
            sexpr_to_smt2(item),
            parse_term(manager, item),
          ),
        )
      }
      terms
    }
  }
}

///|
fn parse_model_query_term(
  manager : @ast.AstManager,
  expr : SExpr,
) -> @cmd_context.ModelQueryTerm raise {
  @cmd_context.ModelQueryTerm::new(
    sexpr_to_smt2(expr),
    parse_term(manager, expr),
  )
}

///|
fn parse_bool_keyword_value(
  keyword : String,
  expr : SExpr,
) -> Bool raise @parse_error.ParseError {
  match sexpr_as_atom(expr) {
    Some("true") => true
    Some("false") => false
    Some(_) =>
      raise @parse_error.ParseError("\{keyword} expects true or false", None)
    None =>
      raise @parse_error.ParseError("\{keyword} expects true or false", None)
  }
}

///|
fn parse_eval_command(
  manager : @ast.AstManager,
  items : Array[SExpr],
) -> @cmd_context.Command raise {
  if items.length() == 2 {
    @cmd_context.Eval(parse_model_query_term(manager, items[1]), false)
  } else if items.length() == 4 {
    match sexpr_as_atom(items[2]) {
      Some(":completion") =>
        @cmd_context.Eval(
          parse_model_query_term(manager, items[1]),
          parse_bool_keyword_value(":completion", items[3]),
        )
      _ =>
        raise @parse_error.ParseError(
          "eval supports only :completion option",
          None,
        )
    }
  } else {
    raise @parse_error.ParseError(
      "eval expects one term and optional :completion flag",
      None,
    )
  }
}

///|
pub fn parse_command(
  manager : @ast.AstManager,
  expr : SExpr,
) -> @cmd_context.Command raise {
  match sexpr_as_list(expr) {
    None => raise @parse_error.ParseError("command must be a list", None)
    Some(items) =>
      if items.is_empty() {
        raise @parse_error.ParseError("empty command", None)
      } else {
        let name = atom_or_error(items[0], "command name")
        match name {
          "set-logic" =>
            if items.length() == 2 {
              @cmd_context.SetLogic(atom_or_error(items[1], "logic"))
            } else {
              raise @parse_error.ParseError(
                "set-logic expects one argument",
                None,
              )
            }
          "set-option" =>
            if items.length() == 3 {
              @cmd_context.SetOption(
                atom_or_error(items[1], "option name"),
                parse_option_value(items[2]),
              )
            } else {
              raise @parse_error.ParseError(
                "set-option expects two arguments",
                None,
              )
            }
          "set-info" =>
            if items.length() == 3 {
              @cmd_context.SetInfo(
                atom_or_error(items[1], "info name"),
                parse_option_value(items[2]),
              )
            } else {
              raise @parse_error.ParseError(
                "set-info expects two arguments",
                None,
              )
            }
          "get-option" =>
            if items.length() == 2 {
              @cmd_context.GetOption(atom_or_error(items[1], "option name"))
            } else {
              raise @parse_error.ParseError(
                "get-option expects one argument",
                None,
              )
            }
          "declare-sort" =>
            if items.length() == 3 {
              let sort_name = atom_or_error(items[1], "sort name")
              let arity_text = atom_or_error(items[2], "sort arity")
              match parse_nonnegative_int(arity_text) {
                Some(arity) => @cmd_context.DeclareSort(sort_name, arity)
                None =>
                  raise @parse_error.ParseError(
                    "sort arity must be non-negative",
                    None,
                  )
              }
            } else {
              raise @parse_error.ParseError(
                "declare-sort expects two arguments",
                None,
              )
            }
          "declare-const" =>
            if items.length() == 3 {
              @cmd_context.DeclareConst(
                atom_or_error(items[1], "constant name"),
                parse_sort(manager, items[2]),
              )
            } else {
              raise @parse_error.ParseError(
                "declare-const expects two arguments",
                None,
              )
            }
          "declare-fun" =>
            if items.length() == 4 {
              @cmd_context.DeclareFun(
                atom_or_error(items[1], "function name"),
                parse_sort_list(manager, items[2]),
                parse_sort(manager, items[3]),
              )
            } else {
              raise @parse_error.ParseError(
                "declare-fun expects three arguments",
                None,
              )
            }
          "declare-datatype" | "declare-datatypes" =>
            raise @unsupported_error.UnsupportedError(
              "datatypes are not supported in Bool+EUF milestone",
              None,
            )
          "define-fun" =>
            if items.length() == 5 {
              let fun_name = atom_or_error(items[1], "function name")
              let params = parse_define_params(manager, items[2])
              let range = parse_sort(manager, items[3])
              let body = parse_term(manager, items[4])
              if !params.is_empty() || range != manager.bool_sort() {
                raise @unsupported_error.UnsupportedError(
                  "only nullary Bool define-fun is supported",
                  None,
                )
              } else {
                @cmd_context.DefineFun(fun_name, params, range, body)
              }
            } else {
              raise @parse_error.ParseError(
                "define-fun expects four arguments",
                None,
              )
            }
          "assert" =>
            if items.length() == 2 {
              parse_assert_command(manager, items[1])
            } else {
              raise @parse_error.ParseError("assert expects one argument", None)
            }
          "push" => @cmd_context.Push(parse_count(items, "push"))
          "pop" => @cmd_context.Pop(parse_count(items, "pop"))
          "reset" =>
            if items.length() == 1 {
              @cmd_context.Reset
            } else {
              raise @parse_error.ParseError("reset expects no arguments", None)
            }
          "reset-assertions" =>
            if items.length() == 1 {
              @cmd_context.ResetAssertions
            } else {
              raise @parse_error.ParseError(
                "reset-assertions expects no arguments",
                None,
              )
            }
          "check-sat" =>
            if items.length() == 1 {
              @cmd_context.CheckSat
            } else {
              raise @parse_error.ParseError(
                "check-sat expects no arguments",
                None,
              )
            }
          "check-sat-assuming" =>
            if items.length() == 2 {
              @cmd_context.CheckSatAssuming(
                parse_assumption_list(manager, items[1]),
              )
            } else {
              raise @parse_error.ParseError(
                "check-sat-assuming expects one argument",
                None,
              )
            }
          "get-model" =>
            if items.length() == 1 {
              @cmd_context.GetModel
            } else {
              raise @parse_error.ParseError(
                "get-model expects no arguments",
                None,
              )
            }
          "get-value" =>
            if items.length() == 2 {
              @cmd_context.GetValue(parse_get_value_terms(manager, items[1]))
            } else {
              raise @parse_error.ParseError(
                "get-value expects one argument",
                None,
              )
            }
          "eval" => parse_eval_command(manager, items)
          "get-proof" =>
            if items.length() == 1 {
              @cmd_context.GetProof
            } else {
              raise @parse_error.ParseError(
                "get-proof expects no arguments",
                None,
              )
            }
          "get-unsat-core" =>
            if items.length() == 1 {
              @cmd_context.GetUnsatCore
            } else {
              raise @parse_error.ParseError(
                "get-unsat-core expects no arguments",
                None,
              )
            }
          "get-unsat-assumptions" =>
            if items.length() == 1 {
              @cmd_context.GetUnsatAssumptions
            } else {
              raise @parse_error.ParseError(
                "get-unsat-assumptions expects no arguments",
                None,
              )
            }
          "get-info" =>
            if items.length() == 2 {
              @cmd_context.GetInfo(atom_or_error(items[1], "info name"))
            } else {
              raise @parse_error.ParseError(
                "get-info expects one argument",
                None,
              )
            }
          "echo" =>
            if items.length() == 2 {
              @cmd_context.Echo(parse_option_value(items[1]))
            } else {
              raise @parse_error.ParseError("echo expects one argument", None)
            }
          "exit" =>
            if items.length() == 1 {
              @cmd_context.Exit
            } else {
              raise @parse_error.ParseError("exit expects no arguments", None)
            }
          _ =>
            raise @unsupported_error.UnsupportedError(
              "unsupported command: \{name}",
              None,
            )
        }
      }
  }
}
