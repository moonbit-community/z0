///|
priv struct Cursor {
  input : String
  mut offset : Int
  mut line : Int
  mut column : Int
}

///|
fn Cursor::new(input : String) -> Cursor {
  { input, offset: 0, line: 1, column: 1 }
}

///|
fn Cursor::position(self : Cursor) -> Position {
  { line: self.line, column: self.column, offset: self.offset }
}

///|
fn Cursor::peek(self : Cursor) -> Char? {
  self.input.get_char(self.offset)
}

///|
fn Cursor::bump(self : Cursor) -> Char? {
  match self.input.get_char(self.offset) {
    None => None
    Some(ch) => {
      self.offset += ch.utf16_len()
      if ch == '\n' || ch == '\r' {
        self.line += 1
        self.column = 1
      } else {
        self.column += 1
      }
      Some(ch)
    }
  }
}

///|
priv enum TokenKind {
  LParen
  RParen
  Atom(Atom)
  EOF
}

///|
priv struct Token {
  kind : TokenKind
  pos : Position
}

///|
priv struct Lexer {
  cursor : Cursor
}

///|
fn Lexer::new(input : String) -> Lexer {
  { cursor: Cursor::new(input) }
}

///|
fn is_delim(ch : Char) -> Bool {
  ch.is_whitespace() ||
  ch == '(' ||
  ch == ')' ||
  ch == ';' ||
  ch == '"' ||
  ch == '|'
}

///|
fn Lexer::skip_spaces_and_comments(self : Lexer) -> Unit {
  let mut done = false
  while !done {
    match self.cursor.peek() {
      Some(ch) if ch.is_whitespace() => ignore(self.cursor.bump())
      Some(';') => {
        ignore(self.cursor.bump())
        self.consume_comment()
      }
      _ => done = true
    }
  }
}

///|
fn Lexer::consume_comment(self : Lexer) -> Unit {
  let mut done = false
  while !done {
    match self.cursor.peek() {
      None => done = true
      Some(ch) => {
        ignore(self.cursor.bump())
        if ch == '\n' || ch == '\r' {
          done = true
        }
      }
    }
  }
}

///|
fn Lexer::read_string(
  self : Lexer,
  start_pos : Position,
) -> String raise ParseError {
  ignore(self.cursor.bump()) // opening quote
  let sb = StringBuilder::new()
  let mut done = false
  while !done {
    match self.cursor.peek() {
      None => raise ParseError::UnclosedString(pos=start_pos)
      Some(ch) => {
        ignore(self.cursor.bump())
        if ch == '"' {
          match self.cursor.peek() {
            Some('"') => {
              ignore(self.cursor.bump())
              sb.write_char('"')
            }
            _ => done = true
          }
        } else {
          sb.write_char(ch)
        }
      }
    }
  }
  sb.to_string()
}

///|
fn Lexer::read_quoted_symbol(
  self : Lexer,
  start_pos : Position,
) -> String raise ParseError {
  ignore(self.cursor.bump()) // opening |
  let sb = StringBuilder::new()
  let mut done = false
  while !done {
    match self.cursor.peek() {
      None => raise ParseError::UnclosedQuotedSymbol(pos=start_pos)
      Some(ch) => {
        ignore(self.cursor.bump())
        if ch == '|' {
          done = true
        } else {
          sb.write_char(ch)
        }
      }
    }
  }
  sb.to_string()
}

///|
fn Lexer::read_bare_token(self : Lexer) -> String {
  let sb = StringBuilder::new()
  let mut done = false
  while !done {
    match self.cursor.peek() {
      Some(ch) if !is_delim(ch) => {
        ignore(self.cursor.bump())
        sb.write_char(ch)
      }
      _ => done = true
    }
  }
  sb.to_string()
}

///|
fn all_chars_from_offset(
  s : String,
  start_offset : Int,
  pred : (Char) -> Bool,
) -> Bool {
  let mut seen = false
  for offset, ch in s.iter2() {
    if offset < start_offset {
      continue
    }
    seen = true
    if !pred(ch) {
      return false
    }
  }
  seen
}

///|
fn is_numeral_token(s : String) -> Bool {
  let mut seen = false
  for offset, ch in s.iter2() {
    if offset == 0 && (ch == '+' || ch == '-') {
      continue
    }
    if ch.is_ascii_digit() {
      seen = true
    } else {
      return false
    }
  }
  seen
}

///|
fn is_decimal_token(s : String) -> Bool {
  let mut seen_dot = false
  let mut before = 0
  let mut after = 0
  for offset, ch in s.iter2() {
    if offset == 0 && (ch == '+' || ch == '-') {
      continue
    }
    if ch == '.' {
      if seen_dot {
        return false
      }
      seen_dot = true
    } else if ch.is_ascii_digit() {
      if seen_dot {
        after += 1
      } else {
        before += 1
      }
    } else {
      return false
    }
  }
  seen_dot && before > 0 && after > 0
}

///|
fn classify_atom(lexeme : String, pos : Position) -> Atom raise ParseError {
  if lexeme.is_empty() {
    raise ParseError::InvalidToken(pos~, lexeme)
  }
  if lexeme.has_prefix(":") {
    Keyword(lexeme)
  } else if lexeme.has_prefix("#b") {
    if all_chars_from_offset(lexeme, 2, ch => ch == '0' || ch == '1') {
      BitvectorBinary(lexeme)
    } else {
      raise ParseError::InvalidToken(pos~, lexeme)
    }
  } else if lexeme.has_prefix("#x") {
    if all_chars_from_offset(lexeme, 2, ch => ch.is_ascii_hexdigit()) {
      BitvectorHex(lexeme)
    } else {
      raise ParseError::InvalidToken(pos~, lexeme)
    }
  } else if is_decimal_token(lexeme) {
    Decimal(lexeme)
  } else if is_numeral_token(lexeme) {
    Numeral(lexeme)
  } else {
    Symbol(lexeme)
  }
}

///|
fn Lexer::next_token(self : Lexer) -> Token raise ParseError {
  self.skip_spaces_and_comments()
  let pos = self.cursor.position()
  match self.cursor.peek() {
    None => { kind: TokenKind::EOF, pos }
    Some('(') => {
      ignore(self.cursor.bump())
      { kind: TokenKind::LParen, pos }
    }
    Some(')') => {
      ignore(self.cursor.bump())
      { kind: TokenKind::RParen, pos }
    }
    Some('"') => {
      let value = self.read_string(pos)
      { kind: TokenKind::Atom(Atom::String(value)), pos }
    }
    Some('|') => {
      let value = self.read_quoted_symbol(pos)
      { kind: TokenKind::Atom(Atom::Symbol(value)), pos }
    }
    Some(_) => {
      let lexeme = self.read_bare_token()
      let atom = classify_atom(lexeme, pos)
      { kind: TokenKind::Atom(atom), pos }
    }
  }
}
