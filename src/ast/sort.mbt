///|
pub(all) enum SortKind {
  BoolSort
  IntSort
  UninterpretedSort(String)
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend SortKind with Eq::{not_equal, equal}

///|
pub(all) struct Sort {
  id : @util.SortId
  name : String
  kind : SortKind
  family : FamilyId
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend Sort with Eq::{not_equal, equal}
