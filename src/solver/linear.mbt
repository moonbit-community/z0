///|
priv struct Rat {
  num : Int
  den : Int
}

///|
fn abs_int(n : Int) -> Int {
  if n < 0 {
    -n
  } else {
    n
  }
}

///|
fn gcd(a : Int, b : Int) -> Int {
  let mut x = abs_int(a)
  let mut y = abs_int(b)
  while y != 0 {
    let r = x % y
    x = y
    y = r
  }
  if x == 0 {
    1
  } else {
    x
  }
}

///|
fn rat_new(num : Int, den : Int) -> Rat {
  if den == 0 {
    return { num: 0, den: 1 }
  }
  let mut n = num
  let mut d = den
  if d < 0 {
    n = -n
    d = -d
  }
  let g = gcd(n, d)
  { num: n / g, den: d / g }
}

///|
fn rat_zero() -> Rat {
  { num: 0, den: 1 }
}

///|
fn rat_one() -> Rat {
  { num: 1, den: 1 }
}

///|
fn rat_from_int(value : Int) -> Rat {
  { num: value, den: 1 }
}

///|
fn rat_is_zero(r : Rat) -> Bool {
  r.num == 0
}

///|
fn rat_sign(r : Rat) -> Int {
  if r.num < 0 {
    -1
  } else if r.num > 0 {
    1
  } else {
    0
  }
}

///|
fn rat_neg(r : Rat) -> Rat {
  { num: -r.num, den: r.den }
}

///|
fn rat_add(a : Rat, b : Rat) -> Rat {
  rat_new(a.num * b.den + b.num * a.den, a.den * b.den)
}

///|
fn rat_mul(a : Rat, b : Rat) -> Rat {
  rat_new(a.num * b.num, a.den * b.den)
}

///|
fn rat_div(a : Rat, b : Rat) -> Rat {
  rat_new(a.num * b.den, a.den * b.num)
}

///|
fn rat_le_zero(r : Rat) -> Bool {
  r.num <= 0
}

///|
fn pow10(n : Int) -> Int {
  let mut value = 1
  for _ in 0..<n {
    value = value * 10
  }
  value
}

///|
fn rat_from_decimal(value : String) -> Rat {
  let mut sign = 1
  let mut body = value
  if body.has_prefix("-") {
    sign = -1
    body = match body.strip_prefix("-") {
      Some(rest) => rest.to_string()
      None => body
    }
  } else if body.has_prefix("+") {
    body = match body.strip_prefix("+") {
      Some(rest) => rest.to_string()
      None => body
    }
  }
  let parts = body.split(".")
  let whole = match parts.next() {
    Some(v) => v
    None => ""
  }
  let frac = match parts.next() {
    Some(v) => v
    None => ""
  }
  let whole_i = if whole.length() == 0 {
    0
  } else {
    @strconv.parse_int(whole) catch {
      _ => 0
    }
  }
  let frac_i = if frac.length() == 0 {
    0
  } else {
    @strconv.parse_int(frac) catch {
      _ => 0
    }
  }
  let denom = pow10(frac.length())
  let num = whole_i * denom + frac_i
  rat_new(sign * num, denom)
}

///|
priv struct LinExpr {
  coeffs : Map[String, Rat]
  constant : Rat
}

///|
fn lin_zero() -> LinExpr {
  { coeffs: Map::new(), constant: rat_zero() }
}

///|
fn lin_from_const(value : Rat) -> LinExpr {
  { coeffs: Map::new(), constant: value }
}

///|
fn lin_from_var(name : String) -> LinExpr {
  let coeffs = Map::new()
  coeffs[name] = rat_one()
  { coeffs, constant: rat_zero() }
}

///|
fn lin_is_const(expr : LinExpr) -> Bool {
  expr.coeffs.length() == 0
}

///|
fn lin_coeff(expr : LinExpr, name : String) -> Rat {
  match expr.coeffs.get(name) {
    Some(value) => value
    None => rat_zero()
  }
}

///|
fn lin_remove_var(expr : LinExpr, name : String) -> LinExpr {
  let coeffs = expr.coeffs.copy()
  coeffs.remove(name)
  { coeffs, constant: expr.constant }
}

///|
fn lin_add(a : LinExpr, b : LinExpr) -> LinExpr {
  let coeffs = a.coeffs.copy()
  for name, coeff in b.coeffs {
    let sum = match coeffs.get(name) {
      Some(existing) => rat_add(existing, coeff)
      None => coeff
    }
    if rat_is_zero(sum) {
      coeffs.remove(name)
    } else {
      coeffs[name] = sum
    }
  }
  { coeffs, constant: rat_add(a.constant, b.constant) }
}

///|
fn lin_scale(expr : LinExpr, factor : Rat) -> LinExpr {
  let coeffs = Map::new()
  for name, coeff in expr.coeffs {
    let prod = rat_mul(coeff, factor)
    if !rat_is_zero(prod) {
      coeffs[name] = prod
    }
  }
  { coeffs, constant: rat_mul(expr.constant, factor) }
}

///|
fn lin_sub(a : LinExpr, b : LinExpr) -> LinExpr {
  lin_add(a, lin_scale(b, rat_neg(rat_one())))
}

///|
fn lin_of_term(term : Term) -> LinExpr? {
  match term {
    Term::IntVal(value) => Some(lin_from_const(rat_from_int(value)))
    Term::RealVal(value) => Some(lin_from_const(rat_from_decimal(value)))
    Term::Var(name, _) => Some(lin_from_var(name))
    Term::Builtin(op, args, _) =>
      match op {
        BuiltinOp::Add => {
          let mut acc = lin_zero()
          for arg in args {
            match lin_of_term(arg) {
              Some(expr) => acc = lin_add(acc, expr)
              None => return None
            }
          }
          Some(acc)
        }
        BuiltinOp::Sub =>
          if args.length() == 0 {
            None
          } else {
            let mut acc = match lin_of_term(args[0]) {
              Some(expr) => expr
              None => return None
            }
            for i in 1..<args.length() {
              match lin_of_term(args[i]) {
                Some(expr) => acc = lin_sub(acc, expr)
                None => return None
              }
            }
            Some(acc)
          }
        BuiltinOp::Neg =>
          if args.length() != 1 {
            None
          } else {
            match lin_of_term(args[0]) {
              Some(expr) => Some(lin_scale(expr, rat_neg(rat_one())))
              None => None
            }
          }
        BuiltinOp::Mul =>
          if args.length() != 2 {
            None
          } else {
            let left = lin_of_term(args[0])
            let right = lin_of_term(args[1])
            match (left, right) {
              (Some(lhs), Some(rhs)) =>
                if lin_is_const(lhs) {
                  Some(lin_scale(rhs, lhs.constant))
                } else if lin_is_const(rhs) {
                  Some(lin_scale(lhs, rhs.constant))
                } else {
                  None
                }
              _ => None
            }
          }
        _ => None
      }
    _ => None
  }
}
