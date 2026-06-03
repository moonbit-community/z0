///|
pub(all) suberror ParseError {
  ParseError(String, @source.SourceSpan?)
} derive(Eq)

///|
pub fn ParseError::prefix(_self : ParseError) -> String {
  "parse"
}

///|
pub fn ParseError::format(self : ParseError) -> String {
  match self {
    ParseError(message, Some(span)) => "\{span}: \{message}"
    ParseError(message, None) => "\{self.prefix()}: \{message}"
  }
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  logger.write_string(self.format())
}
