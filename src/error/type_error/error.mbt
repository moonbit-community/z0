///|
pub(all) suberror TypeError {
  TypeError(String, @source.SourceSpan?)
} derive(Eq)

///|
pub fn TypeError::prefix(_self : TypeError) -> String {
  "type"
}

///|
pub fn TypeError::format(self : TypeError) -> String {
  match self {
    TypeError(message, Some(span)) => "\{span}: \{message}"
    TypeError(message, None) => "\{self.prefix()}: \{message}"
  }
}

///|
pub impl Show for TypeError with fn output(self, logger) {
  logger.write_string(self.format())
}
