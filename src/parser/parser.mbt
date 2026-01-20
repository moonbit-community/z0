///|
priv struct Parser {
  lexer : Lexer
}

///|
fn Parser::new(input : String) -> Parser {
  { lexer: Lexer::new(input) }
}

///|
fn Parser::parse_from_token(
  self : Parser,
  tok : Token,
) -> SExpr raise ParseError {
  match tok.kind {
    TokenKind::Atom(atom) => SExpr::Atom(atom)
    TokenKind::LParen => {
      let items : Array[SExpr] = []
      let mut done = false
      while !done {
        let next_tok = self.lexer.next_token()
        match next_tok.kind {
          TokenKind::RParen => done = true
          TokenKind::EOF => raise ParseError::UnclosedList(pos=tok.pos)
          _ => items.push(self.parse_from_token(next_tok))
        }
      }
      SExpr::List(items)
    }
    TokenKind::RParen =>
      raise ParseError::UnexpectedToken(pos=tok.pos, "unexpected )")
    TokenKind::EOF => raise ParseError::UnexpectedEof(pos=tok.pos)
  }
}

///|
fn Parser::parse_all(self : Parser) -> Array[SExpr] raise ParseError {
  let items : Array[SExpr] = []
  let mut done = false
  while !done {
    let tok = self.lexer.next_token()
    match tok.kind {
      TokenKind::EOF => done = true
      TokenKind::RParen => ()
      _ => items.push(self.parse_from_token(tok))
    }
  }
  items
}

///|
pub fn parse_smtlib(input : String) -> Array[SExpr] raise ParseError {
  let parser = Parser::new(input)
  parser.parse_all()
}
