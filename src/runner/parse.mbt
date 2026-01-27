///|
fn atom_symbol(atom : Atom) -> String? {
  match atom {
    Atom::Symbol(name) => Some(name)
    _ => None
  }
}

///|
fn atom_keyword(atom : Atom) -> String? {
  match atom {
    Atom::Keyword(name) => Some(name)
    _ => None
  }
}

///|
fn attr_key(expr : SExpr) -> String? {
  match expr {
    SExpr::Atom(atom) =>
      match atom {
        Atom::Keyword(name) => Some(name)
        Atom::Symbol(name) =>
          if name.has_prefix(":") {
            Some(name)
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn expect_symbol(expr : SExpr) -> String raise Smt2Error {
  match expr {
    SExpr::Atom(atom) =>
      match atom_symbol(atom) {
        Some(name) => name
        None => raise Smt2Error::Malformed("expected symbol")
      }
    _ => raise Smt2Error::Malformed("expected symbol")
  }
}

///|
fn expect_list(expr : SExpr) -> Array[SExpr] raise Smt2Error {
  match expr {
    SExpr::List(items) => items
    _ => raise Smt2Error::Malformed("expected list")
  }
}

///|
fn parse_numeral(expr : SExpr) -> Int raise Smt2Error {
  match expr {
    SExpr::Atom(Atom::Numeral(n)) =>
      @strconv.parse_int(n) catch {
        _ => raise Smt2Error::Malformed("invalid numeral: \{n}")
      }
    _ => raise Smt2Error::Malformed("expected numeral")
  }
}

///|
fn parse_bitvec_atom(atom : Atom) -> BitVecValue raise Smt2Error {
  match atom {
    Atom::BitvectorBinary(text) => {
      let width = text.length() - 2
      { width, repr: text }
    }
    Atom::BitvectorHex(text) => {
      let width = (text.length() - 2) * 4
      { width, repr: text }
    }
    _ => raise Smt2Error::Malformed("expected bitvector literal")
  }
}

///|
fn bitvec_width_of_term(term : Term) -> Int? {
  match term.sort() {
    Sort::BitVec(width) => Some(width)
    _ => None
  }
}

///|
fn parse_sort(expr : SExpr, env : Env) -> Sort raise Smt2Error {
  match expr {
    SExpr::Atom(atom) =>
      match atom_symbol(atom) {
        Some(name) =>
          match env.find_sort(name) {
            Some(sort) => sort
            None => raise Smt2Error::UnknownSort(name)
          }
        None => raise Smt2Error::Malformed("expected sort symbol")
      }
    SExpr::List(items) => {
      if items.length() == 0 {
        raise Smt2Error::Malformed("empty sort list")
      }
      let head = expect_symbol(items[0])
      match head {
        "_" => {
          let tag = expect_symbol(items[1])
          match tag {
            "BitVec" => {
              if items.length() != 3 {
                raise Smt2Error::Malformed("malformed bitvector sort")
              }
              let width = parse_numeral(items[2])
              Sort::BitVec(width)
            }
            "FloatingPoint" => {
              if items.length() != 4 {
                raise Smt2Error::Malformed("malformed floatingpoint sort")
              }
              let eb = parse_numeral(items[2])
              let sb = parse_numeral(items[3])
              Sort::FloatingPoint(eb, sb)
            }
            _ => raise Smt2Error::Unsupported("unknown indexed sort: \{tag}")
          }
        }
        "Array" => {
          if items.length() != 3 {
            raise Smt2Error::Malformed("malformed array sort")
          }
          let dom = parse_sort(items[1], env)
          let rng = parse_sort(items[2], env)
          Sort::Array(dom, rng)
        }
        _ => raise Smt2Error::Unsupported("unknown sort constructor: \{head}")
      }
    }
  }
}

///|
fn parse_bound_var(expr : SExpr, env : Env) -> BoundVar raise Smt2Error {
  let items = expect_list(expr)
  if items.length() != 2 {
    raise Smt2Error::Malformed("expected (name sort)")
  }
  let name = expect_symbol(items[0])
  let sort = parse_sort(items[1], env)
  { name, sort }
}

///|
fn mk_and(args : Array[Term]) -> Term {
  if args.length() == 0 {
    Term::BoolVal(true)
  } else if args.length() == 1 {
    args[0]
  } else {
    Term::Builtin(BuiltinOp::And, args, Sort::Bool)
  }
}

///|
fn mk_or(args : Array[Term]) -> Term {
  if args.length() == 0 {
    Term::BoolVal(false)
  } else if args.length() == 1 {
    args[0]
  } else {
    Term::Builtin(BuiltinOp::Or, args, Sort::Bool)
  }
}

///|
fn mk_not(arg : Term) -> Term {
  Term::Builtin(BuiltinOp::Not, [arg], Sort::Bool)
}

///|
fn ensure_all_bool(args : Array[Term]) -> Unit raise Smt2Error {
  for arg in args {
    guard arg.sort() == Sort::Bool else {
      raise Smt2Error::Malformed("expected Bool argument")
    }
  }
}

///|
fn ensure_same_sort(args : Array[Term]) -> Sort raise Smt2Error {
  if args.length() == 0 {
    raise Smt2Error::Malformed("expected arguments")
  }
  let mut sort = args[0].sort()
  for arg in args {
    let arg_sort = arg.sort()
    if arg_sort == sort {
      continue
    }
    match (sort, arg_sort) {
      (Sort::Int, Sort::Real) => sort = Sort::Real
      (Sort::Real, Sort::Int) => ()
      _ => raise Smt2Error::Malformed("argument sort mismatch")
    }
  }
  sort
}

///|
fn ensure_pattern_binder_free(expr : SExpr) -> Unit raise Smt2Error {
  match expr {
    SExpr::Atom(_) => ()
    SExpr::List(items) => {
      if items.length() == 0 {
        raise Smt2Error::Malformed("empty pattern term")
      }
      match sexpr_symbol(items[0]) {
        Some("forall") | Some("exists") | Some("let") | Some("!") =>
          raise Smt2Error::Malformed("pattern must be binder-free")
        _ => ()
      }
      for item in items {
        ensure_pattern_binder_free(item)
      }
    }
  }
}

///|
fn parse_pattern_term(
  expr : SExpr,
  env : Env,
  locals : Map[String, Sort],
) -> Unit raise Smt2Error {
  ensure_pattern_binder_free(expr)
  ignore(parse_term(expr, env, locals))
}

///|
fn can_parse_pattern_term(
  expr : SExpr,
  env : Env,
  locals : Map[String, Sort],
) -> Bool {
  let res : Result[Unit, Smt2Error] = try? parse_pattern_term(expr, env, locals)
  match res {
    Ok(_) => true
    Err(_) => false
  }
}

///|
fn parse_pattern_value(
  expr : SExpr,
  env : Env,
  locals : Map[String, Sort],
) -> Unit raise Smt2Error {
  match expr {
    SExpr::List(items) => {
      if items.length() == 0 {
        raise Smt2Error::Malformed("pattern expects at least one term")
      }
      let mut all_ok = true
      for item in items {
        if !can_parse_pattern_term(item, env, locals) {
          all_ok = false
          break
        }
      }
      if all_ok {
        return
      }
      // Fallback for non-standard single-term patterns like :pattern (f x)
      parse_pattern_term(expr, env, locals)
    }
    _ => parse_pattern_term(expr, env, locals)
  }
}

///|
fn parse_term(
  expr : SExpr,
  env : Env,
  locals : Map[String, Sort],
) -> Term raise Smt2Error {
  match expr {
    SExpr::Atom(atom) =>
      match atom {
        Atom::Numeral(n) => {
          let value = @strconv.parse_int(n) catch {
            _ => raise Smt2Error::Malformed("invalid numeral: \{n}")
          }
          Term::IntVal(value)
        }
        Atom::Decimal(n) => Term::RealVal(n)
        Atom::Symbol(name) =>
          match name {
            "true" => Term::BoolVal(true)
            "false" => Term::BoolVal(false)
            _ =>
              match locals.get(name) {
                Some(sort) => Term::Var(name, sort)
                None =>
                  match env.find_const(name) {
                    Some(sort) => Term::Var(name, sort)
                    None =>
                      match env.find_fun(name) {
                        Some(decl) =>
                          if decl.arity() == 0 {
                            Term::App(decl, [])
                          } else {
                            raise Smt2Error::UnknownSymbol(name)
                          }
                        None => raise Smt2Error::UnknownSymbol(name)
                      }
                  }
              }
          }
        Atom::BitvectorBinary(_) => Term::BitVecVal(parse_bitvec_atom(atom))
        Atom::BitvectorHex(_) => Term::BitVecVal(parse_bitvec_atom(atom))
        Atom::String(_) =>
          raise Smt2Error::Unsupported("string literals are not supported")
        Atom::Keyword(_) => raise Smt2Error::Malformed("unexpected keyword")
      }
    SExpr::List(items) => {
      if items.length() == 0 {
        raise Smt2Error::Malformed("empty term list")
      }
      let head = expect_symbol(items[0])
      match head {
        "let" => {
          if items.length() != 3 {
            raise Smt2Error::Malformed("malformed let")
          }
          let bindings_exprs = expect_list(items[1])
          let bindings : Array[(String, Term)] = []
          for bind_expr in bindings_exprs {
            let pair = expect_list(bind_expr)
            if pair.length() != 2 {
              raise Smt2Error::Malformed("malformed let binding")
            }
            let name = expect_symbol(pair[0])
            let value = parse_term(pair[1], env, locals)
            bindings.push((name, value))
          }
          let locals2 = locals.copy()
          for binding in bindings {
            let (name, value) = binding
            locals2[name] = value.sort()
          }
          let body = parse_term(items[2], env, locals2)
          Term::Let(bindings, body)
        }
        "forall" | "exists" => {
          if items.length() != 3 {
            raise Smt2Error::Malformed("malformed quantifier")
          }
          let vars_exprs = expect_list(items[1])
          let vars : Array[BoundVar] = []
          let locals2 = locals.copy()
          for var_expr in vars_exprs {
            let bound = parse_bound_var(var_expr, env)
            locals2[bound.name] = bound.sort
            vars.push(bound)
          }
          let body = parse_term(items[2], env, locals2)
          let kind = if head == "forall" {
            QuantifierKind::Forall
          } else {
            QuantifierKind::Exists
          }
          Term::Quantifier(kind, vars, body)
        }
        "!" => {
          if items.length() < 2 {
            raise Smt2Error::Malformed("! expects a term and attributes")
          }
          let term = parse_term(items[1], env, locals)
          let mut i = 2
          while i < items.length() {
            let key = match attr_key(items[i]) {
              Some(name) => name
              None => raise Smt2Error::Malformed("expected attribute keyword")
            }
            let value = if i + 1 < items.length() &&
              attr_key(items[i + 1]) is None {
              Some(items[i + 1])
            } else {
              None
            }
            match key {
              ":pattern" =>
                match value {
                  Some(val) => parse_pattern_value(val, env, locals)
                  None => raise Smt2Error::Malformed("pattern expects a value")
                }
              ":named" =>
                match value {
                  Some(val) => ignore(expect_symbol(val))
                  None => raise Smt2Error::Malformed("named expects a value")
                }
              _ => ()
            }
            i = i + (if value is Some(_) { 2 } else { 1 })
          }
          term
        }
        "and" => {
          let args = parse_terms(items, 1, env, locals)
          ensure_all_bool(args)
          mk_and(args)
        }
        "or" => {
          let args = parse_terms(items, 1, env, locals)
          ensure_all_bool(args)
          mk_or(args)
        }
        "not" => {
          if items.length() != 2 {
            raise Smt2Error::Malformed("not expects 1 argument")
          }
          let arg = parse_term(items[1], env, locals)
          guard arg.sort() == Sort::Bool else {
            raise Smt2Error::Malformed("not expects Bool")
          }
          mk_not(arg)
        }
        "=>" | "implies" => {
          let args = parse_terms(items, 1, env, locals)
          ensure_all_bool(args)
          if args.length() < 2 {
            raise Smt2Error::Malformed("=> expects at least 2 arguments")
          }
          let mut acc = args[args.length() - 1]
          for i in 0..<(args.length() - 1) {
            let lhs = args[args.length() - 2 - i]
            acc = Term::Builtin(BuiltinOp::Implies, [lhs, acc], Sort::Bool)
          }
          acc
        }
        "xor" => {
          let args = parse_terms(items, 1, env, locals)
          ensure_all_bool(args)
          if args.length() < 2 {
            raise Smt2Error::Malformed("xor expects at least 2 arguments")
          }
          let mut acc = args[0]
          for i in 1..<args.length() {
            acc = Term::Builtin(BuiltinOp::Xor, [acc, args[i]], Sort::Bool)
          }
          acc
        }
        "iff" => {
          if items.length() != 3 {
            raise Smt2Error::Malformed("iff expects 2 arguments")
          }
          let lhs = parse_term(items[1], env, locals)
          let rhs = parse_term(items[2], env, locals)
          guard lhs.sort() == Sort::Bool && rhs.sort() == Sort::Bool else {
            raise Smt2Error::Malformed("iff expects Bool")
          }
          Term::Builtin(BuiltinOp::Iff, [lhs, rhs], Sort::Bool)
        }
        "=" => {
          let args = parse_terms(items, 1, env, locals)
          if args.length() <= 1 {
            Term::BoolVal(true)
          } else if args.length() == 2 {
            let _ = ensure_same_sort(args)
            Term::Builtin(BuiltinOp::Eq, args, Sort::Bool)
          } else {
            let _ = ensure_same_sort(args)
            let pairs : Array[Term] = []
            for i in 0..<(args.length() - 1) {
              pairs.push(
                Term::Builtin(BuiltinOp::Eq, [args[i], args[i + 1]], Sort::Bool),
              )
            }
            mk_and(pairs)
          }
        }
        "distinct" => {
          let args = parse_terms(items, 1, env, locals)
          if args.length() <= 1 {
            Term::BoolVal(true)
          } else {
            let _ = ensure_same_sort(args)
            let disj : Array[Term] = []
            for i in 0..<args.length() {
              for j in (i + 1)..<args.length() {
                let eq = Term::Builtin(
                  BuiltinOp::Eq,
                  [args[i], args[j]],
                  Sort::Bool,
                )
                disj.push(mk_not(eq))
              }
            }
            mk_and(disj)
          }
        }
        "ite" => {
          if items.length() != 4 {
            raise Smt2Error::Malformed("ite expects 3 arguments")
          }
          let cond = parse_term(items[1], env, locals)
          let t_branch = parse_term(items[2], env, locals)
          let e_branch = parse_term(items[3], env, locals)
          guard cond.sort() == Sort::Bool else {
            raise Smt2Error::Malformed("ite condition must be Bool")
          }
          guard t_branch.sort() == e_branch.sort() else {
            raise Smt2Error::Malformed("ite branches must have same sort")
          }
          Term::Builtin(
            BuiltinOp::Ite,
            [cond, t_branch, e_branch],
            t_branch.sort(),
          )
        }
        "+" | "-" | "*" | "div" | "mod" | "<" | "<=" | ">" | ">=" => {
          let args = parse_terms(items, 1, env, locals)
          if args.length() == 0 {
            raise Smt2Error::Malformed("empty arithmetic")
          }
          let sort = ensure_same_sort(args)
          guard sort == Sort::Int || sort == Sort::Real else {
            raise Smt2Error::Malformed("expected Int/Real arguments")
          }
          match head {
            "+" => Term::Builtin(BuiltinOp::Add, args, sort)
            "-" =>
              if args.length() == 1 {
                Term::Builtin(BuiltinOp::Neg, args, sort)
              } else {
                Term::Builtin(BuiltinOp::Sub, args, sort)
              }
            "*" => Term::Builtin(BuiltinOp::Mul, args, sort)
            "div" => Term::Builtin(BuiltinOp::Div, args, sort)
            "mod" => Term::Builtin(BuiltinOp::Mod, args, sort)
            "<" => Term::Builtin(BuiltinOp::Lt, args, Sort::Bool)
            "<=" => Term::Builtin(BuiltinOp::Le, args, Sort::Bool)
            ">" => Term::Builtin(BuiltinOp::Gt, args, Sort::Bool)
            ">=" => Term::Builtin(BuiltinOp::Ge, args, Sort::Bool)
            _ => raise Smt2Error::Unsupported("unknown arithmetic op: \{head}")
          }
        }
        "fp" => {
          if items.length() != 4 {
            raise Smt2Error::Malformed("fp expects 3 arguments")
          }
          let args = parse_terms(items, 1, env, locals)
          let sign = args[0]
          let exponent = args[1]
          let significand = args[2]
          match (sign, exponent, significand) {
            (
              Term::BitVecVal(sign_v),
              Term::BitVecVal(exp_v),
              Term::BitVecVal(sig_v),
            ) =>
              Term::FpVal({ sign: sign_v, exponent: exp_v, significand: sig_v })
            _ => {
              let sign_w = match bitvec_width_of_term(sign) {
                Some(width) => width
                None => raise Smt2Error::Malformed("fp sign expects BitVec")
              }
              let exp_w = match bitvec_width_of_term(exponent) {
                Some(width) => width
                None => raise Smt2Error::Malformed("fp exponent expects BitVec")
              }
              let sig_w = match bitvec_width_of_term(significand) {
                Some(width) => width
                None =>
                  raise Smt2Error::Malformed("fp significand expects BitVec")
              }
              let decl : FuncDecl = {
                name: "fp",
                domain: [
                  Sort::BitVec(sign_w),
                  Sort::BitVec(exp_w),
                  Sort::BitVec(sig_w),
                ],
                range: Sort::FloatingPoint(exp_w, sig_w + 1),
              }
              Term::App(decl, [sign, exponent, significand])
            }
          }
        }
        "fp.rem" => {
          let args = parse_terms(items, 1, env, locals)
          if args.length() != 2 {
            raise Smt2Error::Malformed("fp.rem expects 2 arguments")
          }
          guard args[0].sort() == args[1].sort() else {
            raise Smt2Error::Malformed("fp.rem expects same sorts")
          }
          let sort = args[0].sort()
          let decl : FuncDecl = {
            name: "fp.rem",
            domain: [sort, sort],
            range: sort,
          }
          Term::App(decl, args)
        }
        _ => {
          let name = head
          let args = parse_terms(items, 1, env, locals)
          match env.find_def(name) {
            Some(def) => {
              if args.length() != def.params.length() {
                raise Smt2Error::ArityMismatch(
                  name~,
                  expected=def.params.length(),
                  found=args.length(),
                )
              }
              let subst : Map[String, Term] = Map::new()
              for i in 0..<args.length() {
                subst[def.params[i].name] = args[i]
              }
              subst_term(def.body, subst, Map::new())
            }
            None =>
              match env.find_fun(name) {
                Some(decl) => {
                  if args.length() != decl.arity() {
                    raise Smt2Error::ArityMismatch(
                      name~,
                      expected=decl.arity(),
                      found=args.length(),
                    )
                  }
                  for i in 0..<args.length() {
                    guard args[i].sort() == decl.domain[i] else {
                      raise Smt2Error::Malformed("argument sort mismatch")
                    }
                  }
                  Term::App(decl, args)
                }
                None => raise Smt2Error::UnknownSymbol(name)
              }
          }
        }
      }
    }
  }
}

///|
fn parse_terms(
  items : Array[SExpr],
  start : Int,
  env : Env,
  locals : Map[String, Sort],
) -> Array[Term] raise Smt2Error {
  let args : Array[Term] = []
  for i in start..<items.length() {
    args.push(parse_term(items[i], env, locals))
  }
  args
}

///|
fn subst_term(
  term : Term,
  subst : Map[String, Term],
  bound : Map[String, Bool],
) -> Term {
  match term {
    Term::Var(name, sort) =>
      if bound.contains(name) {
        Term::Var(name, sort)
      } else {
        match subst.get(name) {
          Some(value) => value
          None => Term::Var(name, sort)
        }
      }
    Term::App(decl, args) => {
      let new_args = args.map(arg => subst_term(arg, subst, bound))
      Term::App(decl, new_args)
    }
    Term::Builtin(op, args, sort) => {
      let new_args = args.map(arg => subst_term(arg, subst, bound))
      Term::Builtin(op, new_args, sort)
    }
    Term::Let(bindings, body) => {
      let new_bindings : Array[(String, Term)] = []
      for binding in bindings {
        let (name, value) = binding
        new_bindings.push((name, subst_term(value, subst, bound)))
      }
      let bound2 = bound.copy()
      for binding in bindings {
        let (name, _) = binding
        bound2[name] = true
      }
      let new_body = subst_term(body, subst, bound2)
      Term::Let(new_bindings, new_body)
    }
    Term::Quantifier(kind, vars, body) => {
      let bound2 = bound.copy()
      for bound in vars {
        bound2[bound.name] = true
      }
      let new_body = subst_term(body, subst, bound2)
      Term::Quantifier(kind, vars, new_body)
    }
    _ => term
  }
}

///|
pub fn parse_command(expr : SExpr, env : Env) -> Command raise Smt2Error {
  let items = expect_list(expr)
  if items.length() == 0 {
    raise Smt2Error::Malformed("empty command")
  }
  let head = expect_symbol(items[0])
  match head {
    "set-logic" => {
      if items.length() != 2 {
        raise Smt2Error::Malformed("set-logic expects 1 argument")
      }
      let logic = expect_symbol(items[1])
      Command::SetLogic(logic)
    }
    "set-option" => {
      if items.length() != 3 {
        raise Smt2Error::Malformed("set-option expects 2 arguments")
      }
      let key = match items[1] {
        SExpr::Atom(atom) =>
          match atom_keyword(atom) {
            Some(name) => name
            None => expect_symbol(items[1])
          }
        _ => expect_symbol(items[1])
      }
      Command::SetOption(key, items[2])
    }
    "set-info" => {
      if items.length() != 3 {
        raise Smt2Error::Malformed("set-info expects 2 arguments")
      }
      let key = match items[1] {
        SExpr::Atom(atom) =>
          match atom_keyword(atom) {
            Some(name) => name
            None => expect_symbol(items[1])
          }
        _ => expect_symbol(items[1])
      }
      Command::SetInfo(key, items[2])
    }
    "declare-sort" => {
      if items.length() != 3 {
        raise Smt2Error::Malformed("declare-sort expects 2 arguments")
      }
      let name = expect_symbol(items[1])
      let arity = parse_numeral(items[2])
      env.declare_sort(name, arity)
      Command::DeclareSort(name, arity)
    }
    "define-sort" => {
      if items.length() != 4 {
        raise Smt2Error::Malformed("define-sort expects 3 arguments")
      }
      let name = expect_symbol(items[1])
      let params_exprs = expect_list(items[2])
      let params : Array[String] = []
      for param_expr in params_exprs {
        params.push(expect_symbol(param_expr))
      }
      let body = parse_sort(items[3], env)
      env.define_sort(name, params, body)
      Command::DefineSort(name, params, body)
    }
    "declare-const" => {
      if items.length() != 3 {
        raise Smt2Error::Malformed("declare-const expects 2 arguments")
      }
      let name = expect_symbol(items[1])
      let sort = parse_sort(items[2], env)
      env.declare_const(name, sort)
      Command::DeclareConst(name, sort)
    }
    "declare-fun" => {
      if items.length() != 4 {
        raise Smt2Error::Malformed("declare-fun expects 3 arguments")
      }
      let name = expect_symbol(items[1])
      let domain_exprs = expect_list(items[2])
      let domain : Array[Sort] = []
      for e in domain_exprs {
        domain.push(parse_sort(e, env))
      }
      let range = parse_sort(items[3], env)
      env.declare_fun(name, domain, range)
      Command::DeclareFun(name, domain, range)
    }
    "define-fun" => {
      if items.length() != 5 {
        raise Smt2Error::Malformed("define-fun expects 4 arguments")
      }
      let name = expect_symbol(items[1])
      let params_exprs = expect_list(items[2])
      let params : Array[BoundVar] = []
      let locals : Map[String, Sort] = Map::new()
      for param_expr in params_exprs {
        let param = parse_bound_var(param_expr, env)
        locals[param.name] = param.sort
        params.push(param)
      }
      let range = parse_sort(items[3], env)
      let body = parse_term(items[4], env, locals)
      env.define_fun(name, params, range, body)
      Command::DefineFun(name, params, range, body)
    }
    "assert" => {
      if items.length() != 2 {
        raise Smt2Error::Malformed("assert expects 1 argument")
      }
      let term = parse_term(items[1], env, Map::new())
      Command::Assert(term)
    }
    "simplify" => {
      if items.length() < 2 {
        raise Smt2Error::Malformed("simplify expects 1 argument")
      }
      let opts : Array[SExpr] = []
      for i in 2..<items.length() {
        opts.push(items[i])
      }
      Command::Simplify(items[1], opts)
    }
    "push" => {
      let n = if items.length() == 1 {
        1
      } else if items.length() == 2 {
        parse_numeral(items[1])
      } else {
        raise Smt2Error::Malformed("push expects 0 or 1 argument")
      }
      if n > 0 {
        for _ in 0..<n {
          env.push()
        }
      }
      Command::Push(n)
    }
    "pop" => {
      let n = if items.length() == 1 {
        1
      } else if items.length() == 2 {
        parse_numeral(items[1])
      } else {
        raise Smt2Error::Malformed("pop expects 0 or 1 argument")
      }
      if n > 0 {
        env.pop(n)
      }
      Command::Pop(n)
    }
    "check-sat" => Command::CheckSat
    "check-sat-using" => {
      if items.length() != 2 {
        raise Smt2Error::Malformed("check-sat-using expects 1 argument")
      }
      let tactic = match items[1] {
        SExpr::Atom(_) => expect_symbol(items[1])
        _ => sexpr_to_smt2(items[1])
      }
      Command::CheckSatUsing(tactic)
    }
    "get-value" => {
      if items.length() != 2 {
        raise Smt2Error::Malformed("get-value expects 1 argument")
      }
      let terms_exprs = expect_list(items[1])
      let terms : Array[Term] = []
      for term_expr in terms_exprs {
        terms.push(parse_term(term_expr, env, Map::new()))
      }
      Command::GetValue(terms)
    }
    "get-model" => Command::GetModel
    "exit" => Command::Exit
    _ => Command::Unsupported(expr)
  }
}

///|
pub fn parse_script(exprs : Array[SExpr]) -> Script raise Smt2Error {
  let env = Env::new()
  let commands : Array[Command] = []
  for expr in exprs {
    let cmd = parse_command(expr, env)
    commands.push(cmd)
  }
  { commands, }
}
