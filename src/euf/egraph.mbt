///|
pub enum EufResult {
  Sat
  Unsat
} derive(Show, Eq)

///|
priv struct Node {
  sym : String
  args : Array[Int]
}

///|
struct Sig {
  sym : String
  args : Array[Int]
} derive(Show, Eq, Hash)

///|
fn symbol_of_term(term : Term) -> String {
  match term {
    Term::Var(name, _) => "var:\{name}"
    Term::BoolVal(value) => if value { "bool:true" } else { "bool:false" }
    Term::IntVal(value) => "int:\{value}"
    Term::RealVal(value) => "real:\{value}"
    Term::BitVecVal(value) => "bv:\{value.repr}"
    Term::FpVal(value) =>
      "fp:\{value.sign.repr}|\{value.exponent.repr}|\{value.significand.repr}"
    Term::App(decl, _) => "app:\{decl.name}"
    Term::Builtin(op, _, _) => "builtin:\{builtin_name(op)}"
    _ => "other"
  }
}

///|
fn builtin_name(op : BuiltinOp) -> String {
  match op {
    BuiltinOp::Not => "not"
    BuiltinOp::And => "and"
    BuiltinOp::Or => "or"
    BuiltinOp::Implies => "implies"
    BuiltinOp::Iff => "iff"
    BuiltinOp::Xor => "xor"
    BuiltinOp::Eq => "="
    BuiltinOp::Distinct => "distinct"
    BuiltinOp::Ite => "ite"
    BuiltinOp::Add => "+"
    BuiltinOp::Sub => "-"
    BuiltinOp::Mul => "*"
    BuiltinOp::Div => "div"
    BuiltinOp::Mod => "mod"
    BuiltinOp::Neg => "neg"
    BuiltinOp::Lt => "<"
    BuiltinOp::Le => "<="
    BuiltinOp::Gt => ">"
    BuiltinOp::Ge => ">="
  }
}

///|
fn uf_find(parent : Array[Int], x : Int) -> Int {
  if parent[x] == x {
    x
  } else {
    let root = uf_find(parent, parent[x])
    parent[x] = root
    root
  }
}

///|
fn uf_union(parent : Array[Int], rank : Array[Int], a : Int, b : Int) -> Bool {
  let ra = uf_find(parent, a)
  let rb = uf_find(parent, b)
  if ra == rb {
    return false
  }
  if rank[ra] < rank[rb] {
    parent[ra] = rb
  } else if rank[ra] > rank[rb] {
    parent[rb] = ra
  } else {
    parent[rb] = ra
    rank[ra] = rank[ra] + 1
  }
  true
}

///|
fn intern_term(
  term : Term,
  nodes : Array[Node],
  parent : Array[Int],
  rank : Array[Int],
  ids : Map[Term, Int],
) -> Int {
  match ids.get(term) {
    Some(id) => id
    None => {
      let args : Array[Int] = []
      match term {
        Term::App(_, term_args) =>
          for arg in term_args {
            args.push(intern_term(arg, nodes, parent, rank, ids))
          }
        Term::Builtin(_, term_args, _) =>
          for arg in term_args {
            args.push(intern_term(arg, nodes, parent, rank, ids))
          }
        Term::Let(_, _) => ()
        Term::Quantifier(_, _, _) => ()
        _ => ()
      }
      let id = nodes.length()
      nodes.push({ sym: symbol_of_term(term), args })
      parent.push(id)
      rank.push(0)
      ids[term] = id
      id
    }
  }
}

///|
fn congruence_closure(
  nodes : Array[Node],
  parent : Array[Int],
  rank : Array[Int],
) -> Unit {
  let mut changed = true
  while changed {
    changed = false
    let sigs : Map[Sig, Int] = Map::new()
    for i in 0..<nodes.length() {
      let node = nodes[i]
      let rep_args : Array[Int] = []
      for arg in node.args {
        rep_args.push(uf_find(parent, arg))
      }
      let sig : Sig = { sym: node.sym, args: rep_args }
      match sigs.get(sig) {
        Some(j) => if uf_union(parent, rank, i, j) { changed = true }
        None => sigs[sig] = i
      }
    }
  }
}

///|
fn collect_terms_from_eq(
  a : Term,
  b : Term,
  nodes : Array[Node],
  parent : Array[Int],
  rank : Array[Int],
  ids : Map[Term, Int],
) -> (Int, Int) {
  let id_a = intern_term(a, nodes, parent, rank, ids)
  let id_b = intern_term(b, nodes, parent, rank, ids)
  (id_a, id_b)
}

///|
pub fn check_euf(
  equalities : Array[(Term, Term)],
  disequalities : Array[(Term, Term)],
) -> EufResult {
  let nodes : Array[Node] = []
  let parent : Array[Int] = []
  let rank : Array[Int] = []
  let ids : Map[Term, Int] = Map::new()
  let pairs : Array[(Int, Int)] = []
  for pair in equalities {
    let (a, b) = pair
    let (id_a, id_b) = collect_terms_from_eq(a, b, nodes, parent, rank, ids)
    pairs.push((id_a, id_b))
  }
  for pair in disequalities {
    let (a, b) = pair
    ignore(collect_terms_from_eq(a, b, nodes, parent, rank, ids))
  }
  for pair in pairs {
    let (id_a, id_b) = pair
    ignore(uf_union(parent, rank, id_a, id_b))
  }
  congruence_closure(nodes, parent, rank)
  for pair in disequalities {
    let (a, b) = pair
    let id_a = ids[a]
    let id_b = ids[b]
    if uf_find(parent, id_a) == uf_find(parent, id_b) {
      return EufResult::Unsat
    }
  }
  EufResult::Sat
}

///|
pub fn build_classes(
  equalities : Array[(Term, Term)],
  disequalities : Array[(Term, Term)],
) -> (Map[Term, Int], Array[Int]) {
  let nodes : Array[Node] = []
  let parent : Array[Int] = []
  let rank : Array[Int] = []
  let ids : Map[Term, Int] = Map::new()
  let pairs : Array[(Int, Int)] = []
  for pair in equalities {
    let (a, b) = pair
    let (id_a, id_b) = collect_terms_from_eq(a, b, nodes, parent, rank, ids)
    pairs.push((id_a, id_b))
  }
  for pair in disequalities {
    let (a, b) = pair
    ignore(collect_terms_from_eq(a, b, nodes, parent, rank, ids))
  }
  for pair in pairs {
    let (id_a, id_b) = pair
    ignore(uf_union(parent, rank, id_a, id_b))
  }
  congruence_closure(nodes, parent, rank)
  (ids, parent)
}
