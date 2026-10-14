///|
pub(all) struct AssumptionCore {
  literals : Array[Literal]
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend AssumptionCore with Eq::{not_equal, equal}

///|
pub fn AssumptionCore::text(self : AssumptionCore) -> String {
  "\{Clause::new(self.literals)}"
}

///|
pub fn AssumptionCore::literals(self : AssumptionCore) -> Array[Literal] {
  self.literals.copy()
}

///|
pub(all) enum AssumptionCheckResult {
  AssumptionSat(SatCoreModel)
  AssumptionUnsat(AssumptionCore)
  AssumptionUnknown(String)
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend AssumptionCheckResult with Eq::{not_equal, equal}
