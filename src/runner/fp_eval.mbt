///|
priv struct BinRat {
  num : Int
  exp2 : Int
}

///|
fn eval_term(term : Term, model : @solver.Model) -> Term {
  eval_term_with(term, model, Map::new())
}

///|
fn eval_term_with(
  term : Term,
  model : @solver.Model,
  visiting : Map[String, Bool],
) -> Term {
  match term {
    Term::Var(name, _) =>
      if visiting.contains(name) {
        term
      } else {
        match model.get(name) {
          Some((_, value)) =>
            match value {
              Term::Var(other, _) if other == name => term
              _ => {
                let visiting2 = visiting.copy()
                visiting2[name] = true
                eval_term_with(value, model, visiting2)
              }
            }
          None => term
        }
      }
    Term::App(decl, args) => {
      let eval_args = args.map(arg => eval_term_with(arg, model, visiting))
      if decl.name == "fp.rem" {
        match eval_fp_rem(eval_args) {
          Some(value) => Term::FpVal(value)
          None => Term::App(decl, eval_args)
        }
      } else {
        Term::App(decl, eval_args)
      }
    }
    _ => term
  }
}

///|
fn eval_fp_rem(args : Array[Term]) -> FpValue? {
  if args.length() != 2 {
    return None
  }
  match (args[0], args[1]) {
    (Term::FpVal(lhs), Term::FpVal(rhs)) => fp_rem(lhs, rhs)
    _ => None
  }
}

///|
fn fp_rem(lhs : FpValue, rhs : FpValue) -> FpValue? {
  let left = match fp_to_binrat(lhs) {
    Some(value) => value
    None => return None
  }
  let right = match fp_to_binrat(rhs) {
    Some(value) => value
    None => return None
  }
  let rem = match binrat_rem(left, right) {
    Some(value) => value
    None => return None
  }
  let eb = lhs.exponent.width
  let sb = lhs.significand.width + 1
  binrat_to_fp(rem, eb, sb)
}

///|
fn fp_to_binrat(fp : FpValue) -> BinRat? {
  let sign = match bitvec_value(fp.sign) {
    Some(value) => value
    None => return None
  }
  let exp = match bitvec_value(fp.exponent) {
    Some(value) => value
    None => return None
  }
  let sig = match bitvec_value(fp.significand) {
    Some(value) => value
    None => return None
  }
  let eb = fp.exponent.width
  let sb = fp.significand.width + 1
  if eb <= 0 || sb <= 1 {
    return None
  }
  let max_exp = pow2(eb) - 1
  if exp == max_exp {
    return None
  }
  let bias = pow2(eb - 1) - 1
  let mut exponent = 0
  let mut significand = 0
  if exp == 0 {
    if sig == 0 {
      return Some({ num: 0, exp2: 0 })
    }
    exponent = 1 - bias
    significand = sig
  } else {
    exponent = exp - bias
    significand = pow2(sb - 1) + sig
  }
  let mut num = significand
  let exp2 = if exponent >= sb - 1 {
    let shift = exponent - (sb - 1)
    num = num * pow2(shift)
    0
  } else {
    sb - 1 - exponent
  }
  if sign != 0 {
    num = -num
  }
  Some({ num, exp2 })
}

///|
fn binrat_rem(x : BinRat, y : BinRat) -> BinRat? {
  if y.num == 0 {
    return None
  }
  let q_num = x.num * pow2(y.exp2)
  let q_den = y.num * pow2(x.exp2)
  if q_den == 0 {
    return None
  }
  let sign = if (q_num < 0) == (q_den < 0) { 1 } else { -1 }
  let a = abs_int(q_num)
  let b = abs_int(q_den)
  let q = a / b
  let r = a % b
  let mut n = if r * 2 < b {
    q
  } else if r * 2 > b {
    q + 1
  } else if q % 2 == 0 {
    q
  } else {
    q + 1
  }
  if sign < 0 {
    n = -n
  }
  let k = if x.exp2 > y.exp2 { x.exp2 } else { y.exp2 }
  let nx = x.num * pow2(k - x.exp2)
  let ny = y.num * pow2(k - y.exp2)
  let r_num = nx - n * ny
  Some({ num: r_num, exp2: k })
}

///|
fn binrat_to_fp(value : BinRat, eb : Int, sb : Int) -> FpValue? {
  if eb <= 0 || sb <= 1 {
    return None
  }
  let mut num = value.num
  let sign = if num < 0 { 1 } else { 0 }
  if num < 0 {
    num = -num
  }
  if num == 0 {
    let sign_bv = match bitvec_from_int(1, sign) {
      Some(value) => value
      None => return None
    }
    let exp_bv = match bitvec_from_int(eb, 0) {
      Some(value) => value
      None => return None
    }
    let sig_bv = match bitvec_from_int(sb - 1, 0) {
      Some(value) => value
      None => return None
    }
    return Some({ sign: sign_bv, exponent: exp_bv, significand: sig_bv })
  }
  let bn = bit_length(num)
  let exponent = bn - 1 - value.exp2
  let bias = pow2(eb - 1) - 1
  let max_exp = pow2(eb) - 1
  let mut exp_bits = exponent + bias
  if exp_bits <= 0 || exp_bits >= max_exp {
    return None
  }
  let shift = sb - bn
  let mut sig_full = 0
  if shift >= 0 {
    sig_full = num * pow2(shift)
  } else {
    let right = -shift
    let divisor = pow2(right)
    sig_full = num / divisor
    let rem = num % divisor
    if rem * 2 > divisor {
      sig_full = sig_full + 1
    } else if rem * 2 == divisor && sig_full % 2 == 1 {
      sig_full = sig_full + 1
    }
  }
  let top = pow2(sb - 1)
  if sig_full >= pow2(sb) {
    sig_full = top
    exp_bits = exp_bits + 1
    if exp_bits >= max_exp {
      return None
    }
  }
  let sig_bits = sig_full - top
  let sign_bv = match bitvec_from_int(1, sign) {
    Some(value) => value
    None => return None
  }
  let exp_bv = match bitvec_from_int(eb, exp_bits) {
    Some(value) => value
    None => return None
  }
  let sig_bv = match bitvec_from_int(sb - 1, sig_bits) {
    Some(value) => value
    None => return None
  }
  Some({ sign: sign_bv, exponent: exp_bv, significand: sig_bv })
}

///|
fn bitvec_value(value : BitVecValue) -> Int? {
  let text = value.repr
  if text.length() < 2 {
    return None
  }
  if text.has_prefix("#b") {
    let width = text.length() - 2
    if width > 60 {
      return None
    }
    parse_digits_from(text, 2, 2)
  } else if text.has_prefix("#x") {
    let width = text.length() - 2
    if width * 4 > 60 {
      return None
    }
    parse_digits_from(text, 2, 16)
  } else {
    None
  }
}

///|
fn parse_digits_from(text : String, offset : Int, base : Int) -> Int? {
  let mut value = 0
  for idx, ch in text.iter2() {
    if idx < offset {
      continue
    }
    let digit = match digit_value(ch) {
      Some(val) => val
      None => return None
    }
    if digit >= base {
      return None
    }
    value = value * base + digit
  }
  Some(value)
}

///|
fn digit_value(ch : Char) -> Int? {
  match ch {
    '0' => Some(0)
    '1' => Some(1)
    '2' => Some(2)
    '3' => Some(3)
    '4' => Some(4)
    '5' => Some(5)
    '6' => Some(6)
    '7' => Some(7)
    '8' => Some(8)
    '9' => Some(9)
    'a' => Some(10)
    'b' => Some(11)
    'c' => Some(12)
    'd' => Some(13)
    'e' => Some(14)
    'f' => Some(15)
    'A' => Some(10)
    'B' => Some(11)
    'C' => Some(12)
    'D' => Some(13)
    'E' => Some(14)
    'F' => Some(15)
    _ => None
  }
}

///|
fn pow2(exp : Int) -> Int {
  if exp <= 0 {
    return 1
  }
  let mut value = 1
  for _ in 0..<exp {
    value = value * 2
  }
  value
}

///|
fn bitvec_from_int(width : Int, value : Int) -> BitVecValue? {
  if width < 0 || value < 0 {
    return None
  }
  let max = pow2(width)
  if value >= max {
    return None
  }
  let sb = StringBuilder::new()
  sb..write_string("#b")
  let mut v = value
  let bits : Array[Char] = []
  for _ in 0..<width {
    let bit = if v % 2 == 1 { '1' } else { '0' }
    bits.push(bit)
    v = v / 2
  }
  for i in 0..<bits.length() {
    sb..write_char(bits[bits.length() - 1 - i])
  }
  Some({ width, repr: sb.to_string() })
}

///|
fn bit_length(value : Int) -> Int {
  if value <= 0 {
    return 0
  }
  let mut v = value
  let mut len = 0
  while v > 0 {
    v = v / 2
    len = len + 1
  }
  len
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}
