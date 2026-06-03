///|
pub(all) struct Line(Int) derive(Eq, Compare, Hash)

///|
pub fn Line::new(value : Int) -> Line {
  Line(value)
}

///|
pub fn Line::to_int(self : Line) -> Int {
  self.0
}

///|
pub(all) struct Column(Int) derive(Eq, Compare, Hash)

///|
pub fn Column::new(value : Int) -> Column {
  Column(value)
}

///|
pub fn Column::to_int(self : Column) -> Int {
  self.0
}

///|
pub(all) struct ByteOffset(Int) derive(Eq, Compare, Hash)

///|
pub fn ByteOffset::new(value : Int) -> ByteOffset {
  ByteOffset(value)
}

///|
pub fn ByteOffset::to_int(self : ByteOffset) -> Int {
  self.0
}

///|
pub(all) struct SourcePos {
  line : Line
  column : Column
  offset : ByteOffset
} derive(Eq)

///|
pub fn SourcePos::new(line~ : Int, column~ : Int, offset~ : Int) -> SourcePos {
  {
    line: Line::new(line),
    column: Column::new(column),
    offset: ByteOffset::new(offset),
  }
}

///|
pub fn SourcePos::line(self : SourcePos) -> Int {
  self.line.to_int()
}

///|
pub fn SourcePos::column(self : SourcePos) -> Int {
  self.column.to_int()
}

///|
pub fn SourcePos::offset(self : SourcePos) -> Int {
  self.offset.to_int()
}

///|
pub(all) struct SourceSpan {
  start : SourcePos
  end : SourcePos
} derive(Eq)

///|
pub fn SourceSpan::new(start~ : SourcePos, end~ : SourcePos) -> SourceSpan {
  { start, end }
}

///|
pub fn SourceSpan::format(self : SourceSpan) -> String {
  "line \{self.start.line()}, col \{self.start.column()}"
}

///|
pub impl Show for SourceSpan with fn output(self, logger) {
  logger.write_string(self.format())
}
