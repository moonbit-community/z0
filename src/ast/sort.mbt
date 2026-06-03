///|
pub(all) enum SortKind {
  BoolSort
  IntSort
  UninterpretedSort(String)
} derive(Eq)

///|
pub(all) struct Sort {
  id : @util.SortId
  name : String
  kind : SortKind
  family : FamilyId
} derive(Eq)
