///|
pub(all) enum SExpr {
  Atom(String, @source.SourceSpan)
  StringLit(String, @source.SourceSpan)
  List(Array[SExpr], @source.SourceSpan)
} derive(Eq)

///|
pub(all) enum ParseNext {
  Next(SExpr, SExprCursor)
  End(SExprCursor)
}

///|
pub struct SExprCursor {
  scanner : Scanner
}

///|
pub fn SExprCursor::new(input : String) -> SExprCursor {
  SExprCursor::{ scanner: Scanner::new(input) }
}

///|
fn quote_string(value : String) -> String {
  let builder = StringBuilder::new()
  builder.write_char('"')
  for c in value {
    if c == '"' {
      builder.write_string("\\\"")
    } else if c == '\\' {
      builder.write_string("\\\\")
    } else {
      builder.write_char(c)
    }
  }
  builder.write_char('"')
  builder.to_string()
}

///|
pub fn SExpr::span(self : SExpr) -> @source.SourceSpan {
  match self {
    Atom(_, span) | StringLit(_, span) | List(_, span) => span
  }
}

///|
pub fn SExpr::repr(self : SExpr) -> String {
  match self {
    Atom(symbol, _) => "Atom(\{quote_string(symbol)})"
    StringLit(value, _) => "StringLit(\{quote_string(value)})"
    List(items, _) => {
      let builder = StringBuilder::new()
      builder.write_string("List([")
      for i in 0..<items.length() {
        if i > 0 {
          builder.write_string(", ")
        }
        builder.write_string(items[i].repr())
      }
      builder.write_string("])")
      builder.to_string()
    }
  }
}

///|
pub impl Show for SExpr with fn output(self, logger) {
  logger.write_string(self.repr())
}

///|
fn span_join(
  start : @source.SourceSpan,
  end : @source.SourceSpan,
) -> @source.SourceSpan {
  @source.SourceSpan::new(start=start.start, end=end.end)
}

///|
fn parse_expr_from_token(
  cursor : SExprCursor,
  token : Token,
) -> (SExpr, SExprCursor) raise @parse_error.ParseError {
  match token.kind {
    Symbol(symbol) => (Atom(symbol, token.span), cursor)
    StringToken(value) => (StringLit(value, token.span), cursor)
    RParen => raise @parse_error.ParseError("extra ')'", Some(token.span))
    Eof =>
      raise @parse_error.ParseError("unexpected end of input", Some(token.span))
    LParen => parse_list(cursor, token.span)
  }
}

///|
fn parse_list(
  cursor : SExprCursor,
  start_span : @source.SourceSpan,
) -> (SExpr, SExprCursor) raise @parse_error.ParseError {
  let items : Array[SExpr] = []
  let mut current = cursor
  while true {
    let token = current.scanner.next_token()
    match token.kind {
      Eof => raise @parse_error.ParseError("unclosed list", Some(start_span))
      RParen => return (List(items, span_join(start_span, token.span)), current)
      _ => {
        let (expr, next) = parse_expr_from_token(current, token)
        items.push(expr)
        current = next
      }
    }
  } nobreak {
    panic()
  }
}

///|
pub fn parse_next(
  cursor : SExprCursor,
) -> ParseNext raise @parse_error.ParseError {
  let token = cursor.scanner.next_token()
  match token.kind {
    Eof => End(cursor)
    RParen => raise @parse_error.ParseError("extra ')'", Some(token.span))
    _ => {
      let (expr, next) = parse_expr_from_token(cursor, token)
      Next(expr, next)
    }
  }
}

///|
pub fn parse_program(
  input : String,
) -> Array[SExpr] raise @parse_error.ParseError {
  let exprs : Array[SExpr] = []
  let mut cursor = SExprCursor::new(input)
  while true {
    match parse_next(cursor) {
      End(_) => return exprs
      Next(expr, next) => {
        exprs.push(expr)
        cursor = next
      }
    }
  } nobreak {
    panic()
  }
}
