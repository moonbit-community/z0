///|
pub(all) suberror UnsupportedError {
  UnsupportedError(String, @source.SourceSpan?)
} derive(Eq)

///|
pub fn UnsupportedError::prefix(_self : UnsupportedError) -> String {
  "unsupported"
}

///|
pub fn UnsupportedError::format(self : UnsupportedError) -> String {
  match self {
    UnsupportedError(message, Some(span)) => "\{span}: \{message}"
    UnsupportedError(message, None) => "\{self.prefix()}: \{message}"
  }
}

///|
pub impl Show for UnsupportedError with fn output(self, logger) {
  logger.write_string(self.format())
}
