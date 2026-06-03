///|
pub struct Scanner {
  input : String
  mut index : Int
  mut line : Int
  mut column : Int
}

///|
pub fn Scanner::new(input : String) -> Scanner {
  Scanner::{ input, index: 0, line: 1, column: 1 }
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn is_symbol_delimiter(c : Char) -> Bool {
  is_space(c) || c == '(' || c == ')' || c == '"' || c == ';'
}

///|
fn Scanner::pos(self : Scanner) -> @source.SourcePos {
  @source.SourcePos::new(line=self.line, column=self.column, offset=self.index)
}

///|
fn Scanner::span_from(
  self : Scanner,
  start : @source.SourcePos,
) -> @source.SourceSpan {
  @source.SourceSpan::new(start~, end=self.pos())
}

///|
fn Scanner::peek(self : Scanner) -> Char? {
  self.input.get_char(self.index)
}

///|
fn Scanner::advance(self : Scanner) -> Char? {
  match self.peek() {
    None => None
    Some(c) => {
      self.index += 1
      if c == '\n' {
        self.line += 1
        self.column = 1
      } else {
        self.column += 1
      }
      Some(c)
    }
  }
}

///|
fn Scanner::skip_trivia(self : Scanner) -> Unit {
  while true {
    match self.peek() {
      Some(c) if is_space(c) => {
        ignore(self.advance())
        continue
      }
      Some(';') => {
        while true {
          match self.peek() {
            Some('\n') | None => break
            Some(_) => ignore(self.advance())
          }
        }
        continue
      }
      _ => break
    }
  }
}

///|
fn Scanner::scan_string(
  self : Scanner,
  start : @source.SourcePos,
) -> Token raise @parse_error.ParseError {
  ignore(self.advance())
  let builder = StringBuilder::new()
  while true {
    match self.peek() {
      None =>
        raise @parse_error.ParseError(
          "unclosed string",
          Some(self.span_from(start)),
        )
      Some('"') => {
        ignore(self.advance())
        match self.peek() {
          Some('"') => {
            ignore(self.advance())
            builder.write_char('"')
            continue
          }
          _ =>
            return Token::string_lit(builder.to_string(), self.span_from(start))
        }
      }
      Some(c) => {
        ignore(self.advance())
        builder.write_char(c)
      }
    }
  } nobreak {
    panic()
  }
}

///|
fn Scanner::scan_symbol(self : Scanner, start : @source.SourcePos) -> Token {
  let builder = StringBuilder::new()
  while true {
    match self.peek() {
      Some(c) if !is_symbol_delimiter(c) => {
        ignore(self.advance())
        builder.write_char(c)
      }
      _ => break
    }
  }
  Token::symbol(builder.to_string(), self.span_from(start))
}

///|
pub fn Scanner::next_token(
  self : Scanner,
) -> Token raise @parse_error.ParseError {
  self.skip_trivia()
  let start = self.pos()
  match self.peek() {
    None => Token::eof(self.span_from(start))
    Some('(') => {
      ignore(self.advance())
      Token::lparen(self.span_from(start))
    }
    Some(')') => {
      ignore(self.advance())
      Token::rparen(self.span_from(start))
    }
    Some('"') => self.scan_string(start)
    Some(_) => self.scan_symbol(start)
  }
}
