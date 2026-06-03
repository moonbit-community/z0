///|
pub(all) suberror IoError {
  IoError(String)
} derive(Eq)

///|
pub fn IoError::prefix(_self : IoError) -> String {
  "io"
}

///|
pub fn IoError::format(self : IoError) -> String {
  match self {
    IoError(message) => "\{self.prefix()}: \{message}"
  }
}

///|
pub impl Show for IoError with fn output(self, logger) {
  logger.write_string(self.format())
}
