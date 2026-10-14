///|
pub struct ProofKind {
  priv name : String
} derive(Eq)

///|
pub fn ProofKind::ast() -> ProofKind {
  { name: "ast", }
}

///|
pub fn ProofKind::to_text(self : ProofKind) -> String {
  self.name
}

///|
pub struct ProofRef {
  priv id : Int32
  priv kind : ProofKind
  priv object : ProofObject?
}

///|
pub fn ProofRef::to_text(self : ProofRef) -> String {
  "proof#\{self.id}(\{self.kind.to_text()})"
}

///|
pub fn ProofRef::object(self : ProofRef) -> ProofObject? {
  self.object
}

///|
pub struct ProofHandle {
  priv id : Int32
  priv kind : ProofKind?
  priv object : ProofObject?
  priv disabled : String?
  priv mut stale : Bool
}

///|
pub fn ProofHandle::new(id : Int32, kind : ProofKind) -> ProofHandle {
  { id, kind: Some(kind), object: None, disabled: None, stale: false, }
}

///|
pub fn ProofHandle::from_object(
  id : Int32,
  kind : ProofKind,
  object : ProofObject,
) -> ProofHandle {
  { id, kind: Some(kind), object: Some(object), disabled: None, stale: false, }
}

///|
pub fn ProofHandle::disabled(feature : String) -> ProofHandle {
  { id: -1, kind: None, object: None, disabled: Some(feature), stale: false, }
}

///|
pub fn ProofHandle::no_current_result() -> ProofHandle {
  { id: -1, kind: None, object: None, disabled: None, stale: false, }
}

///|
pub fn ProofHandle::mark_stale(self : ProofHandle) -> Unit {
  self.stale = true
}

///|
pub fn ProofHandle::view(self : ProofHandle) -> @util.Availability[ProofRef] {
  match self.disabled {
    Some(feature) => Unavailable(Disabled(feature))
    None =>
      if self.stale {
        Unavailable(Stale)
      } else {
        match self.kind {
          Some(kind) => Available({ id: self.id, kind, object: self.object, })
          None => Unavailable(NoCurrentResult)
        }
      }
  }
}

///|
pub struct ProofObject {
  priv root_text : String
  priv hints : Array[ProofHint]
} derive(Eq)

///|
pub fn ProofObject::from_ast_expr(
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> ProofObject {
  { root_text: manager.pretty(expr), hints: [], }
}

///|
pub fn ProofObject::from_root_and_hints(
  root_text : String,
  hints : Array[ProofHint],
) -> ProofObject {
  { root_text, hints: hints.copy(), }
}

///|
pub fn ProofObject::root_text(self : ProofObject) -> String {
  self.root_text
}

///|
pub fn ProofObject::hints(self : ProofObject) -> Array[ProofHint] {
  self.hints.copy()
}

///|
pub struct ProofHint {
  priv owner : String
  priv kind : String
} derive(Eq)

///|
pub fn ProofHint::new(kind : String) -> ProofHint {
  { owner: "", kind, }
}

///|
pub fn ProofHint::with_owner(owner : String, kind : String) -> ProofHint {
  { owner, kind, }
}

///|
pub fn ProofHint::owner_text(self : ProofHint) -> String {
  self.owner
}

///|
pub fn ProofHint::kind_text(self : ProofHint) -> String {
  self.kind
}

///|
pub struct ProofHintChecker {
  priv name : String
  priv check_hint_fn : (ProofHint) -> @util.Availability[Unit]
}

///|
pub fn ProofHintChecker::new(
  name : String,
  check_hint : (ProofHint) -> @util.Availability[Unit],
) -> ProofHintChecker {
  { name, check_hint_fn: check_hint, }
}

///|
pub fn ProofHintChecker::name(self : ProofHintChecker) -> String {
  self.name
}

///|
pub fn ProofHintChecker::check_hint(
  self : ProofHintChecker,
  hint : ProofHint,
) -> @util.Availability[Unit] {
  (self.check_hint_fn)(hint)
}

///|
pub struct ProofChecker {
  priv name : String
  priv check_fn : (ProofRef) -> @util.Availability[Unit]
}

///|
pub fn ProofChecker::name(self : ProofChecker) -> String {
  self.name
}

///|
pub fn ProofChecker::check(
  self : ProofChecker,
  proof : ProofRef,
) -> @util.Availability[Unit] {
  (self.check_fn)(proof)
}

///|
pub fn ProofChecker::unsupported(name : String) -> ProofChecker {
  {
    name,
    check_fn: fn(_) {
      Unavailable(
        @util.AvailabilityReason::unsupported(
          @util.ReasonUnknown::unsupported_fragment(name),
        ),
      )
    },
  }
}

///|
pub fn ProofChecker::from_params(params : @params.Params) -> ProofChecker {
  match params.get_bool("produce_proofs") {
    Available(true) => ProofChecker::unsupported("proof-checker-seed")
    Available(false) =>
      {
        name: "proof-disabled",
        check_fn: fn(_) { Unavailable(Disabled("produce-proofs")) },
      }
    Unavailable(reason) =>
      { name: "proof-unavailable", check_fn: fn(_) { Unavailable(reason) }, }
  }
}
