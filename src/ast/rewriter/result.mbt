///|
pub(all) struct RewriteResult {
  result : @util.ExprId
  proof : String?
  dependency : String?
  unsupported : @util.ReasonUnknown?
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend RewriteResult with Eq::{not_equal, equal}

///|
pub fn RewriteResult::result(self : RewriteResult) -> @util.ExprId {
  self.result
}

///|
pub fn RewriteResult::proof_text(self : RewriteResult) -> String {
  match self.proof {
    Some(value) => value
    None => "none"
  }
}

///|
pub fn RewriteResult::dependency_text(self : RewriteResult) -> String {
  match self.dependency {
    Some(value) => value
    None => "none"
  }
}

///|
pub fn RewriteResult::unsupported_text(self : RewriteResult) -> String {
  match self.unsupported {
    Some(reason) => reason.to_text()
    None => "none"
  }
}
