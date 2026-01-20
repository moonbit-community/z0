///|
pub suberror ParseError {
  UnexpectedToken(pos~ : Position, String)
  UnexpectedEof(pos~ : Position)
  UnclosedString(pos~ : Position)
  UnclosedQuotedSymbol(pos~ : Position)
  UnclosedList(pos~ : Position)
  InvalidToken(pos~ : Position, String)
} derive(Show, ToJson, Eq)
