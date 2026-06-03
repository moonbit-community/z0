///|
pub(all) enum TokenKind {
  LParen
  RParen
  Symbol(String)
  StringToken(String)
  Eof
} derive(Eq)

///|
pub(all) struct Token {
  kind : TokenKind
  span : @source.SourceSpan
} derive(Eq)

///|
pub fn Token::lparen(span : @source.SourceSpan) -> Token {
  Token::{ kind: LParen, span }
}

///|
pub fn Token::rparen(span : @source.SourceSpan) -> Token {
  Token::{ kind: RParen, span }
}

///|
pub fn Token::symbol(value : String, span : @source.SourceSpan) -> Token {
  Token::{ kind: Symbol(value), span }
}

///|
pub fn Token::string_lit(value : String, span : @source.SourceSpan) -> Token {
  Token::{ kind: StringToken(value), span }
}

///|
pub fn Token::eof(span : @source.SourceSpan) -> Token {
  Token::{ kind: Eof, span }
}
